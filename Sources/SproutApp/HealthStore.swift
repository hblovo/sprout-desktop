import AppKit
import Combine
import CoreGraphics
import Foundation
import SproutCore
import UserNotifications

@MainActor final class HealthStore: ObservableObject {
    @Published private(set) var data = HealthData()
    @Published private(set) var engine = ReminderEngine()
    @Published private(set) var now = Date()
    @Published private(set) var systemSuspended = false
    @Published var selectedPage: Page = .today
    @Published var toast: String?
    @Published private var historyStorageIssue: String?
    @Published private var sessionStorageIssue: String?
    @Published var waterNudge = false
    @Published var notificationStatus = "关闭"
    @Published private(set) var idleAway = false
    @Published private(set) var pendingBreak: BreakCandidate?

    enum Page: String, CaseIterable {
        case today = "今日状态", history = "习惯记录", settings = "偏好设置"
        var symbol: String {
            switch self { case .today: return "square.grid.2x2"; case .history: return "chart.bar.xaxis"; case .settings: return "slider.horizontal.3" }
        }
    }

    let isDemo: Bool
    let repository: HealthRepository
    let sessionRepository: SessionRepository
    private let systemIntegration: Bool
    var showWindow: (() -> Void)?
    var petVisibilityChanged: (() -> Void)?
    private var canPersist = true
    private var canPersistSession = true
    private var lastSessionSaveUptime = ProcessInfo.processInfo.systemUptime
    private var lastSavedSession: SessionSnapshot?
    private var timer: Timer?
    private var lastUptime = ProcessInfo.processInfo.systemUptime
    private var waterElapsed: TimeInterval = 0
    private var suspensionReasons: Set<String> = []
    private var idleMonitor = IdleMonitor()
    private var engineBeforeBreak: ReminderEngine?
    private var monitorStartedUptime = ProcessInfo.processInfo.systemUptime
    private var pendingReviewElapsed: TimeInterval = 0
    private var toastTask: Task<Void, Never>?

    init(demo: Bool = false, dataURL: URL? = nil, systemIntegration: Bool = true) {
        isDemo = demo
        self.systemIntegration = systemIntegration && !demo
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        repository = HealthRepository(fileURL: dataURL ?? base.appendingPathComponent("Sprout/health.json"))
        sessionRepository = SessionRepository(fileURL: repository.fileURL.deletingPathExtension().appendingPathExtension("session.json"))
        if demo {
            data = Self.demoData()
        } else {
            do { data = try repository.load() }
            catch {
                canPersist = false
                historyStorageIssue = "原有记录暂时无法读取，已保护原文件。本次记录仅临时保存。"
            }
        }
        engine = ReminderEngine(focusMinutes: preferences.focusMinutes, breakMinutes: preferences.breakMinutes)
        if demo { _ = engine.tick(elapsed: 1268) }
        else if canPersist {
            do {
                if let saved = try sessionRepository.load() {
                    engine = saved.engine
                    engine.configure(focusMinutes: preferences.focusMinutes, breakMinutes: preferences.breakMinutes)
                    engineBeforeBreak = saved.engineBeforeBreak
                    pendingBreak = saved.pendingBreak
                    pendingReviewElapsed = saved.reviewElapsed
                    waterElapsed = saved.waterElapsed
                    // A crash between saving the activity and clearing its pending review cannot duplicate it.
                    if let candidate = pendingBreak, data.breaks.contains(where: { $0.id == candidate.id }) {
                        pendingBreak = nil
                        pendingReviewElapsed = 0
                        engine.resetFocus()
                    }
                    lastSavedSession = saved
                }
            } catch {
                canPersistSession = false
                sessionStorageIssue = "上次计时状态无法读取，已保留原文件；本次重新计时，健康记录不受影响。"
            }
        }
    }

    var storageIssue: String? { historyStorageIssue ?? sessionStorageIssue }

    var preferences: Preferences { data.preferences }
    var today: DailySummary { data.summary(on: now) }
    var week: [DailySummary] { data.week(ending: now) }
    var waterProgress: Double { min(1, Double(today.waterML) / Double(preferences.waterGoalML)) }
    var todayWater: [WaterEntry] { data.water.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }.sorted { $0.date > $1.date } }
    var quiet: Bool { preferences.isQuiet(at: now) }
    var remindersMuted: Bool { engine.isPaused || quiet || systemSuspended || idleAway }
    var statusText: String {
        if systemSuspended { return "离开中" }
        if idleAway { return "暂离电脑" }
        if pendingBreak != nil { return "欢迎回来" }
        if engine.isPaused { return "已暂停" }
        if quiet && engine.phase != .resting { return "安静时段" }
        switch engine.phase {
        case .focus: return engine.isSnoozed ? "稍后提醒" : "陪伴中"
        case .due: return "该活动啦"
        case .resting: return "休息中"
        }
    }

    func start() {
        lastUptime = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer?.tolerance = 0.15
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        Task { await refreshNotificationStatus() }
    }

    func enginePreviewDue() {
        guard isDemo else { return }
        _ = engine.tick(elapsed: engine.remaining)
    }

    func tick(currentDate: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime, idleSeconds: TimeInterval? = nil) {
        let priorDate = now
        now = currentDate
        if !Calendar.current.isDate(priorDate, inSameDayAs: now) {
            waterElapsed = 0
            waterNudge = false
        }
        let delta = uptime - lastUptime
        lastUptime = uptime
        let previousPhase = engine.phase
        let previousPending = pendingBreak?.id
        defer {
            let transitioned = engine.phase != previousPhase || pendingBreak?.id != previousPending
            checkpointSession(force: transitioned, uptime: uptime)
        }
        if preferences.detectIdle && (!isDemo || idleSeconds != nil) && !systemSuspended {
            let rawIdle = idleSeconds ?? CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
            let idle = min(rawIdle, max(0, uptime - monitorStartedUptime))
            let activityEvent = idleMonitor.sample(idleSeconds: idle)
            idleAway = idleMonitor.isAway
            if case .returned(let seconds) = activityEvent,
               engine.phase != .resting, pendingBreak == nil, !engine.isPaused, !quiet {
                if (120...1800).contains(seconds) {
                    pendingBreak = BreakCandidate(date: now, seconds: seconds, fromIdle: true)
                    pendingReviewElapsed = 0
                    clearNotifications()
                } else if seconds > 1800 {
                    flash("欢迎回来，继续离开前的计时；未自动增加起身记录。")
                }
            }
        }
        // Wake, lock and long scheduling gaps never produce catch-up reminders.
        guard !systemSuspended, delta > 0, delta < 10 else { return }
        if pendingBreak != nil {
            if !remindersMuted { pendingReviewElapsed += delta }
            if pendingReviewElapsed >= 60 {
                dismissBreak()
                flash("这次未确认，暂不记入活动；已继续原来的计时。")
            }
            return
        }
        let event = engine.tick(elapsed: delta, quiet: (quiet || idleAway) && engine.phase != .resting)
        switch event {
        case .breakDue:
            waterNudge = false
            notify(title: "起来走走，让身体换个姿势", body: "小芽等你一起休息 \(preferences.breakMinutes) 分钟。", identifier: "break")
        case .breakCompleted(let seconds):
            if let previous = engineBeforeBreak { engine = previous }
            engine.configure(focusMinutes: preferences.focusMinutes, breakMinutes: preferences.breakMinutes)
            engineBeforeBreak = nil
            pendingBreak = BreakCandidate(date: now, seconds: seconds, fromIdle: false)
            pendingReviewElapsed = 0
            notify(title: "休息时间到了", body: "刚才有起身活动吗？点一下小芽确认，就会记入今天。", identifier: "complete")
        case nil:
            break
        }
        if !remindersMuted && engine.phase == .focus && preferences.waterRemindersEnabled && today.waterML < preferences.waterGoalML {
            waterElapsed += delta
            if waterElapsed >= 3600 {
                waterElapsed = 0
                waterNudge = true
                notify(title: "忙碌间隙，喝口水吧", body: "喝完可以点一下小芽，记录这一杯。", identifier: "water")
            }
        }
    }

    func suspend(_ suspended: Bool, reason: String) {
        if suspended { suspensionReasons.insert(reason) } else { suspensionReasons.remove(reason) }
        systemSuspended = !suspensionReasons.isEmpty
        lastUptime = ProcessInfo.processInfo.systemUptime
        if suspended { clearNotifications() }
        checkpointSession(force: true)
    }

    func addWater(_ amount: Int? = nil) {
        now = Date()
        guard data.addWater(amount ?? preferences.cupML, at: now) != nil else { return }
        waterElapsed = 0
        waterNudge = false
        persist()
        if systemIntegration { UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["water"]) }
        flash(today.waterML >= preferences.waterGoalML ? "今天的饮水目标完成啦，按需补水就好。" : "记下这一杯，小芽也精神了一点。")
    }

    func undoWater() {
        now = Date()
        guard let entry = todayWater.first else { return }
        removeWater(entry.id)
    }

    func removeWater(_ id: UUID) {
        data.removeWater(id: id)
        persist()
        flash("已撤销这条饮水记录。")
    }

    func startBreak() {
        pendingBreak = nil
        pendingReviewElapsed = 0
        engineBeforeBreak = engine
        engineBeforeBreak?.setPaused(false)
        engine.startBreak()
        lastUptime = ProcessInfo.processInfo.systemUptime
        clearNotifications()
        checkpointSession(force: true)
    }

    func cancelBreak() {
        if let previous = engineBeforeBreak { engine = previous } else { engine.resetFocus() }
        engine.configure(focusMinutes: preferences.focusMinutes, breakMinutes: preferences.breakMinutes)
        engineBeforeBreak = nil
        lastUptime = ProcessInfo.processInfo.systemUptime
        flash("已回到专注；未完成的休息不会计入记录。")
        clearNotifications()
        checkpointSession(force: true)
    }

    func confirmBreak() {
        guard let candidate = pendingBreak else { return }
        pendingBreak = nil
        pendingReviewElapsed = 0
        idleMonitor.reset()
        idleAway = false
        if !data.breaks.contains(where: { $0.id == candidate.id }) {
            data.breaks.append(BreakEntry(id: candidate.id, date: candidate.date, seconds: candidate.seconds))
        }
        engine.resetFocus()
        engine.setPaused(false)
        lastUptime = ProcessInfo.processInfo.systemUptime
        persist()
        clearNotifications()
        flash("记下一次起身活动，新一轮专注开始啦。")
    }

    func dismissBreak() {
        pendingBreak = nil
        pendingReviewElapsed = 0
        idleMonitor.reset()
        idleAway = false
        lastUptime = ProcessInfo.processInfo.systemUptime
        clearNotifications()
        flash("没关系，继续原来的计时；这次不计入活动。")
        checkpointSession(force: true)
    }

    func snooze() {
        engine.snooze()
        lastUptime = ProcessInfo.processInfo.systemUptime
        clearNotifications()
        flash("好，5 分钟后再轻轻提醒你。")
        checkpointSession(force: true)
    }

    func togglePause() {
        engine.setPaused(!engine.isPaused)
        lastUptime = ProcessInfo.processInfo.systemUptime
        if engine.isPaused { clearNotifications() }
        checkpointSession(force: true)
    }

    func updatePreferences(_ mutate: (inout Preferences) -> Void) {
        var updated = preferences
        mutate(&updated)
        updated.sanitize()
        let focusChanged = updated.focusMinutes != preferences.focusMinutes
        if updated.detectIdle != preferences.detectIdle { monitorStartedUptime = ProcessInfo.processInfo.systemUptime }
        data.preferences = updated
        engine.configure(focusMinutes: updated.focusMinutes, breakMinutes: updated.breakMinutes)
        if focusChanged { lastUptime = ProcessInfo.processInfo.systemUptime; clearNotifications() }
        if !updated.waterRemindersEnabled { waterNudge = false; waterElapsed = 0 }
        if !updated.detectIdle { idleMonitor.reset(); idleAway = false }
        if updated.isQuiet(at: Date()) { clearNotifications() }
        persist()
        petVisibilityChanged?()
    }

    func setNotifications(_ enabled: Bool) {
        if !enabled {
            updatePreferences { $0.notificationsEnabled = false }
            clearNotifications()
            notificationStatus = "关闭"
            return
        }
        guard systemIntegration else { flash("预览模式不会申请系统权限。"); return }
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
                updatePreferences { $0.notificationsEnabled = granted }
                await refreshNotificationStatus()
                if !granted { flash("系统通知未获允许；桌宠提醒仍然可用。") }
            } catch { flash("暂时无法启用系统通知，桌宠仍会按时提醒。") }
        }
    }

    func refreshNotificationStatus() async {
        guard systemIntegration else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .denied {
            notificationStatus = "系统未允许"
            if preferences.notificationsEnabled { updatePreferences { $0.notificationsEnabled = false } }
        } else {
            notificationStatus = preferences.notificationsEnabled ? "已开启" : "关闭"
        }
    }

    private func notify(title: String, body: String, identifier: String) {
        guard preferences.notificationsEnabled, !remindersMuted, systemIntegration else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = identifier == "break" ? "BREAK" : (identifier == "water" ? "WATER" : "")
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        Task {
            do { try await UNUserNotificationCenter.current().add(request) }
            catch { flash("系统通知未能送达，请查看桌宠提示。") }
        }
    }

    private func clearNotifications() {
        guard systemIntegration else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }

    private func persist() {
        guard !isDemo, canPersist else { return }
        do {
            try repository.save(data)
            historyStorageIssue = nil
            checkpointSession(force: true)
        }
        catch { historyStorageIssue = "记录暂时无法写入磁盘，请检查存储空间；当前记录仍保留在应用中。" }
    }

    func checkpointSession(force: Bool = false, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard !isDemo, canPersist, canPersistSession else { return }
        guard force || uptime - lastSessionSaveUptime >= 5 else { return }
        let snapshot = SessionSnapshot(engine: engine, engineBeforeBreak: engineBeforeBreak,
                                       pendingBreak: pendingBreak, reviewElapsed: min(60, pendingReviewElapsed), waterElapsed: waterElapsed)
        guard snapshot != lastSavedSession else { lastSessionSaveUptime = uptime; return }
        do {
            try sessionRepository.save(snapshot)
            lastSavedSession = snapshot
            lastSessionSaveUptime = uptime
            sessionStorageIssue = nil
        } catch {
            sessionStorageIssue = "计时进度暂时无法保存，退出前请检查存储空间。"
        }
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        checkpointSession(force: true)
    }

    func flash(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "芽伴记录-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))).json"
        panel.title = "导出你的健康记录"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try HealthRepository(fileURL: url).save(data); flash("记录已导出。") }
        catch { flash("导出失败，请确认目标文件夹可以写入。") }
    }

    func revealData() {
        NSWorkspace.shared.activateFileViewerSelecting([repository.fileURL])
    }

    private static func demoData() -> HealthData {
        var result = HealthData()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in -6...0 {
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let cups = [5, 7, 6, 8, 5, 7, 3][offset + 6]
            for cup in 0..<cups {
                result.water.append(WaterEntry(date: date.addingTimeInterval(Double(9 * 3600 + cup * 1800)), milliliters: 250))
            }
            for item in 0..<(offset == 0 ? 2 : 3 + (offset + 6) % 4) {
                result.breaks.append(BreakEntry(date: date.addingTimeInterval(Double(10 * 3600 + item * 2700)), seconds: 120))
            }
        }
        return result
    }
}
