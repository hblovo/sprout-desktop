import Foundation
import Testing
import SproutCore
@testable import SproutApp

@MainActor @Test func endingDueBreakImmediatelyReturnsToWork() {
    let store = HealthStore(demo: true, systemIntegration: false)
    store.enginePreviewDue()
    let count = store.today.breakCount
    store.startBreak()
    store.endBreak()
    #expect(store.engine.phase == .focus)
    #expect(!store.engine.isSnoozed)
    #expect(store.engine.remaining == store.engine.focusDuration)
    #expect(store.today.breakCount == count)
    #expect(store.pendingBreak?.focusRestarted == true)
}

@MainActor @Test func repeatedStartCannotTrapUserInResting() {
    let store = HealthStore(demo: true, systemIntegration: false)
    let before = store.engine.focusDuration
    store.startBreak()
    store.startBreak()
    store.endBreak()
    #expect(store.engine.phase == .focus)
    #expect(store.engine.remaining == before)
    store.endBreak()
    #expect(store.engine.remaining == before)
}

@MainActor @Test func earlyExitFromDueBreakPersistsAcrossRestart() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("health.json")
    var engine = ReminderEngine()
    _ = engine.tick(elapsed: 2700)
    try SessionRepository(fileURL: directory.appendingPathComponent("health.session.json"))
        .save(SessionSnapshot(engine: engine))
    let store = HealthStore(dataURL: url, systemIntegration: false)
    store.startBreak()
    store.togglePause()
    store.endBreak()
    let restored = HealthStore(dataURL: url, systemIntegration: false)
    #expect(restored.engine.phase == .focus)
    #expect(!restored.engine.isSnoozed)
    #expect(!restored.engine.isPaused)
    #expect(restored.engine.remaining == restored.engine.focusDuration)
    #expect(restored.pendingBreak?.focusRestarted == true)
    #expect(restored.today.breakCount == 0)
    restored.tick(uptime: ProcessInfo.processInfo.systemUptime + 1, idleSeconds: 0)
    #expect(restored.engine.phase == .focus)
    #expect(restored.engine.remaining < restored.engine.focusDuration)
}

@MainActor @Test func confirmingActivityDoesNotResetNewFocus() {
    let store = HealthStore(demo: true, systemIntegration: false)
    store.updatePreferences { $0.quietHoursEnabled = false; $0.detectIdle = false; $0.focusMinutes = 30 }
    let count = store.today.breakCount
    store.startBreak()
    store.endBreak()
    #expect(store.engine.remaining == 1800)
    store.tick(uptime: ProcessInfo.processInfo.systemUptime + 5, idleSeconds: 0)
    let remaining = store.engine.remaining
    #expect(remaining < 1800)
    store.confirmBreak()
    store.confirmBreak()
    #expect(store.engine.remaining == remaining)
    #expect(store.today.breakCount == count + 1)
}

@MainActor @Test func decliningActivityDoesNotStopNewFocus() {
    let store = HealthStore(demo: true, systemIntegration: false)
    let count = store.today.breakCount
    store.startBreak()
    store.endBreak()
    store.tick(uptime: ProcessInfo.processInfo.systemUptime + 3, idleSeconds: 0)
    let remaining = store.engine.remaining
    store.dismissBreak()
    #expect(store.engine.remaining == remaining)
    #expect(store.today.breakCount == count)
    #expect(store.pendingBreak == nil)
}

@MainActor @Test func onlyExplicitSnoozeUsesFiveMinutes() {
    let store = HealthStore(demo: true, systemIntegration: false)
    store.enginePreviewDue()
    store.snooze()
    #expect(store.engine.remaining == 300)
    #expect(store.engine.isSnoozed)
}
