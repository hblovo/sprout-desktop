import Foundation
import Testing
import SproutCore
@testable import SproutApp

@MainActor @Test func restartingAppKeepsRemainingFocusTime() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("health.json")
    let original = HealthStore(dataURL: url, systemIntegration: false)
    let clock = ProcessInfo.processInfo.systemUptime
    let date = Date()
    for second in 1...123 {
        original.tick(currentDate: date.addingTimeInterval(Double(second)), uptime: clock + Double(second), idleSeconds: 0)
    }
    original.updatePreferences { $0.cupML = 300 }
    let remainingBeforeRestart = original.engine.remaining
    let restored = HealthStore(dataURL: url, systemIntegration: false)
    #expect(restored.engine.remaining == remainingBeforeRestart)
    #expect(restored.engine.remaining < 2600)
    #expect(restored.preferences.cupML == 300)
}

@MainActor @Test func pausedStateSurvivesWithoutCountingClosedTime() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("health.json")
    let store = HealthStore(dataURL: url, systemIntegration: false)
    store.tick(uptime: ProcessInfo.processInfo.systemUptime + 8, idleSeconds: 0)
    store.togglePause()
    let remaining = store.engine.remaining
    store.shutdown()
    let reopened = HealthStore(dataURL: url, systemIntegration: false)
    #expect(reopened.engine.isPaused)
    #expect(reopened.engine.remaining == remaining)
    reopened.tick(currentDate: Date().addingTimeInterval(86400), uptime: ProcessInfo.processInfo.systemUptime + 1, idleSeconds: 0)
    #expect(reopened.engine.remaining == remaining)
}

@MainActor @Test func snoozePersistsAsSnoozeRatherThan45Minutes() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("health.json")
    var engine = ReminderEngine()
    _ = engine.tick(elapsed: 2700)
    try SessionRepository(fileURL: directory.appendingPathComponent("health.session.json")).save(SessionSnapshot(engine: engine))
    let store = HealthStore(dataURL: url, systemIntegration: false)
    #expect(store.engine.phase == .due)
    store.snooze()
    store.tick(uptime: ProcessInfo.processInfo.systemUptime + 8, idleSeconds: 0)
    store.shutdown()
    let reopened = HealthStore(dataURL: url, systemIntegration: false)
    #expect(reopened.engine.isSnoozed)
    #expect(reopened.engine.remaining == store.engine.remaining)
    #expect(reopened.engine.remaining < 300)
}

@MainActor @Test func interruptedBreakRestoresAndCancelReturnsToOldFocus() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("health.json")
    let store = HealthStore(dataURL: url, systemIntegration: false)
    store.tick(uptime: ProcessInfo.processInfo.systemUptime + 8, idleSeconds: 0)
    let previousFocus = store.engine.focusDuration
    store.startBreak()
    store.tick(uptime: ProcessInfo.processInfo.systemUptime + 7, idleSeconds: 0)
    store.shutdown()
    let reopened = HealthStore(dataURL: url, systemIntegration: false)
    #expect(reopened.engine.phase == .resting)
    #expect(reopened.engine.remaining == store.engine.remaining)
    reopened.endBreak()
    #expect(reopened.engine.phase == .focus)
    #expect(reopened.engine.remaining == previousFocus)
}

@MainActor @Test func completedButUnconfirmedBreakSurvivesRestart() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("health.json")
    var previous = ReminderEngine()
    _ = previous.tick(elapsed: 123)
    var resting = previous
    resting.startBreak()
    _ = resting.tick(elapsed: 119)
    try SessionRepository(fileURL: directory.appendingPathComponent("health.session.json")).save(SessionSnapshot(engine: resting, engineBeforeBreak: previous))
    let store = HealthStore(dataURL: url, systemIntegration: false)
    store.tick(uptime: ProcessInfo.processInfo.systemUptime + 2, idleSeconds: 0)
    #expect(store.pendingBreak != nil)
    let reopened = HealthStore(dataURL: url, systemIntegration: false)
    #expect(reopened.pendingBreak == store.pendingBreak)
    #expect(reopened.data.breaks.isEmpty)
    reopened.confirmBreak()
    reopened.confirmBreak()
    let final = HealthStore(dataURL: url, systemIntegration: false)
    #expect(final.data.breaks.count == 1)
    #expect(final.pendingBreak == nil)
}

@MainActor @Test func crashBetweenActivityAndSessionSavesCannotDuplicateActivity() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("health.json")
    let candidate = BreakCandidate(date: Date(), seconds: 120, fromIdle: true)
    var history = HealthData()
    history.breaks.append(BreakEntry(id: candidate.id, date: candidate.date, seconds: 120))
    try HealthRepository(fileURL: url).save(history)
    try SessionRepository(fileURL: directory.appendingPathComponent("health.session.json")).save(SessionSnapshot(engine: ReminderEngine(), pendingBreak: candidate))
    let store = HealthStore(dataURL: url, systemIntegration: false)
    #expect(store.pendingBreak == nil)
    store.confirmBreak()
    #expect(store.data.breaks.count == 1)
}

@MainActor @Test func longIdleReturnKeepsRemainingTime() {
    let store = HealthStore(demo: true)
    let clock = ProcessInfo.processInfo.systemUptime
    let date = Date()
    for second in 1...1900 {
        store.tick(currentDate: date.addingTimeInterval(Double(second)), uptime: clock + Double(second), idleSeconds: Double(second))
    }
    let remaining = store.engine.remaining
    store.tick(currentDate: date.addingTimeInterval(1901), uptime: clock + 1901, idleSeconds: 0)
    #expect(abs(store.engine.remaining - (remaining - 1)) < 0.01)
    #expect(store.pendingBreak == nil)
}

@MainActor @Test func damagedSessionDoesNotDamageHealthHistory() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("health.json")
    let sessionURL = directory.appendingPathComponent("health.session.json")
    var history = HealthData()
    _ = history.addWater(300)
    try HealthRepository(fileURL: url).save(history)
    let badBytes = Data("{broken".utf8)
    try badBytes.write(to: sessionURL)
    let store = HealthStore(dataURL: url, systemIntegration: false)
    store.checkpointSession(force: true)
    #expect(store.data.water.count == 1)
    #expect(store.storageIssue != nil)
    #expect(try Data(contentsOf: sessionURL) == badBytes)
}
