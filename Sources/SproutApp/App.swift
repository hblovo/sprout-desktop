import AppKit
import SwiftUI
import UserNotifications

@main enum SproutApplication {
    @MainActor static func main() {
        let application = NSApplication.shared
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--render-preview"), arguments.indices.contains(index + 1) {
            do { try PreviewRenderer.render(to: URL(fileURLWithPath: arguments[index + 1])) }
            catch { fputs("Preview rendering failed: \(error)\n", stderr); exit(1) }
            return
        }
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    private var store: HealthStore!
    private var mainWindow: NSWindow!
    private var pet: DesktopPetController!
    private var statusItem: NSStatusItem!
    private var workspaceObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        let isDemo = arguments.contains("--demo")
        let dataURL: URL? = arguments.firstIndex(of: "--data-file").flatMap { index in
            arguments.indices.contains(index + 1) ? URL(fileURLWithPath: arguments[index + 1]) : nil
        }
        store = HealthStore(demo: isDemo, dataURL: dataURL)
        configureApplicationMenu()
        configureWindow()
        configureStatusItem()
        pet = DesktopPetController(store: store, menu: { [weak self] in self?.makeStatusMenu() ?? NSMenu() })
        store.showWindow = { [weak self] in self?.showDashboard() }
        store.petVisibilityChanged = { [weak self] in self?.pet.updateVisibility() }
        configureNotifications()
        observeWorkspace()
        if arguments.contains("--preview-due") { store.enginePreviewDue() }
        store.start()
        showDashboard()
    }

    private func configureWindow() {
        mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        mainWindow.title = "芽伴 · Sprout"
        mainWindow.titleVisibility = .hidden
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.backgroundColor = NSColor(Palette.background)
        mainWindow.isReleasedWhenClosed = false
        mainWindow.minSize = NSSize(width: 1020, height: 760)
        mainWindow.contentView = NSHostingView(rootView: RootView(store: store))
        mainWindow.delegate = self
        mainWindow.center()
        mainWindow.setFrameAutosaveName(store.isDemo ? "SproutPreviewWindow" : "SproutMainWindow")
    }

    @objc private func showDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)
        Task { await store.refreshNotificationStatus() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard()
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func configureApplicationMenu() {
        let menu = NSMenu()
        let appRoot = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(item("关于芽伴", action: #selector(showAbout)))
        appMenu.addItem(.separator())
        appMenu.addItem(item("偏好设置…", action: #selector(showSettings), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(item("隐藏芽伴", action: #selector(NSApplication.hide(_:)), key: "h", target: NSApp))
        appMenu.addItem(item("退出芽伴", action: #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
        appRoot.submenu = appMenu
        menu.addItem(appRoot)
        let windowRoot = NSMenuItem(title: "窗口", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(item("显示芽伴", action: #selector(showDashboard), key: "1"))
        windowMenu.addItem(item("关闭窗口", action: #selector(NSWindow.performClose(_:)), key: "w", target: nil))
        windowMenu.addItem(item("最小化", action: #selector(NSWindow.performMiniaturize(_:)), key: "m", target: nil))
        windowRoot.submenu = windowMenu
        menu.addItem(windowRoot)
        NSApp.mainMenu = menu
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "leaf", accessibilityDescription: "芽伴")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "芽伴 · 让健康在日常里发芽"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let source = makeStatusMenu()
        for entry in source.items { source.removeItem(entry); menu.addItem(entry) }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        let state = NSMenuItem(title: "小芽 · \(store.statusText)  \(store.engine.displayTime)", action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        let water = NSMenuItem(title: "今日饮水 \(store.today.waterML) / \(store.preferences.waterGoalML) mL", action: nil, keyEquivalent: "")
        water.isEnabled = false
        menu.addItem(water)
        menu.addItem(.separator())
        menu.addItem(item("打开芽伴", action: #selector(showDashboard)))
        menu.addItem(item("喝一杯  +\(store.preferences.cupML) mL", action: #selector(addWater)))
        if store.pendingBreak != nil {
            menu.addItem(item("刚才活动过了，记一次", action: #selector(confirmBreak)))
            menu.addItem(item("刚才没有活动，继续专注", action: #selector(dismissBreak)))
        } else if store.engine.phase == .resting {
            menu.addItem(item("结束休息，继续工作", action: #selector(endBreak)))
        } else {
            menu.addItem(item("现在休息一下", action: #selector(startBreak)))
        }
        if store.engine.phase == .due { menu.addItem(item("5 分钟后提醒", action: #selector(snooze))) }
        menu.addItem(item(store.engine.isPaused ? "继续计时与提醒" : "暂停计时与提醒", action: #selector(togglePause)))
        menu.addItem(.separator())
        menu.addItem(item(store.preferences.petVisible ? "隐藏桌宠" : "显示桌宠", action: #selector(togglePet)))
        menu.addItem(item("偏好设置…", action: #selector(showSettings)))
        menu.addItem(.separator())
        menu.addItem(item("退出芽伴", action: #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
        return menu
    }

    private func item(_ title: String, action: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? (action == #selector(NSWindow.performClose(_:)) || action == #selector(NSWindow.performMiniaturize(_:)) ? nil : self)
        return item
    }

    @objc private func addWater() { store.addWater() }
    @objc private func startBreak() { store.startBreak() }
    @objc private func endBreak() { store.endBreak() }
    @objc private func confirmBreak() { store.confirmBreak() }
    @objc private func dismissBreak() { store.dismissBreak() }
    @objc private func snooze() { store.snooze() }
    @objc private func togglePause() { store.togglePause() }
    @objc private func togglePet() { store.updatePreferences { $0.petVisible.toggle() } }
    @objc private func showSettings() { store.selectedPage = .settings; showDashboard() }
    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "芽伴 · Sprout",
            .applicationVersion: "1.0.0",
            .credits: NSAttributedString(string: "让健康在日常里发芽。\n为长时间坐在屏幕前的你而做。"),
            .version: "1"
        ])
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        let suspensionPairs: [(Notification.Name, Notification.Name, String)] = [
            (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, "sleep"),
            (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification, "session"),
            (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, "display")
        ]
        for (suspend, resume, reason) in suspensionPairs {
            workspaceObservers.append(center.addObserver(forName: suspend, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.store.suspend(true, reason: reason) }
            })
            workspaceObservers.append(center.addObserver(forName: resume, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.store.suspend(false, reason: reason) }
            })
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    @objc private func screenChanged() { pet.keepOnScreen() }

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        let start = UNNotificationAction(identifier: "START_BREAK", title: "开始休息", options: [])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "5 分钟后", options: [])
        let water = UNNotificationAction(identifier: "ADD_WATER", title: "记一杯水", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "BREAK", actions: [start, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: "WATER", actions: [water], intentIdentifiers: [])
        ])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            switch response.actionIdentifier {
            case "START_BREAK": if store.engine.phase == .due { store.startBreak() }
            case "SNOOZE": store.snooze()
            case "ADD_WATER": store.addWater()
            case UNNotificationDefaultActionIdentifier: showDashboard()
            default: break
            }
            completionHandler()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.shutdown()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    func windowWillClose(_ notification: Notification) { store.checkpointSession(force: true) }
}
