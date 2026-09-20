import Foundation
import Testing
@testable import SproutApp

@MainActor @Test func finishingTimerDoesNotInventAnActivity() {
    let store = HealthStore(demo: true)
    let original = store.data.breaks.count
    store.updatePreferences { $0.breakMinutes = 1 }
    store.startBreak()
    let clock = ProcessInfo.processInfo.systemUptime
    let date = Date()
    for second in 1...61 {
        store.tick(currentDate: date.addingTimeInterval(Double(second)), uptime: clock + Double(second), idleSeconds: 0)
    }
    #expect(store.pendingBreak != nil)
    #expect(store.data.breaks.count == original)
    store.confirmBreak()
    store.confirmBreak()
    #expect(store.data.breaks.count == original + 1)
    #expect(store.data.breaks.last?.seconds == 60)
    #expect(store.pendingBreak == nil)
}

@MainActor @Test func decliningCompletedBreakKeepsNewFocus() {
    let store = HealthStore(demo: true)
    let originalRemaining = store.engine.focusDuration
    let originalCount = store.data.breaks.count
    store.updatePreferences { $0.breakMinutes = 1 }
    store.startBreak()
    let clock = ProcessInfo.processInfo.systemUptime
    let date = Date()
    for second in 1...61 {
        store.tick(currentDate: date.addingTimeInterval(Double(second)), uptime: clock + Double(second), idleSeconds: 0)
    }
    store.dismissBreak()
    #expect(store.engine.remaining == originalRemaining)
    #expect(store.data.breaks.count == originalCount)
}

@MainActor @Test func awayReturnAsksBeforeRecordingAndDoesNotDoubleCount() {
    let store = HealthStore(demo: true)
    let count = store.data.breaks.count
    let clock = ProcessInfo.processInfo.systemUptime
    let date = Date()
    for second in 1...150 {
        store.tick(currentDate: date.addingTimeInterval(Double(second)), uptime: clock + Double(second), idleSeconds: Double(second))
    }
    #expect(store.idleAway)
    #expect(store.data.breaks.count == count)
    store.tick(currentDate: date.addingTimeInterval(151), uptime: clock + 151, idleSeconds: 0)
    #expect(store.pendingBreak?.fromIdle == true)
    #expect(store.data.breaks.count == count)
    store.confirmBreak()
    store.tick(currentDate: date.addingTimeInterval(152), uptime: clock + 152, idleSeconds: 1)
    #expect(store.pendingBreak == nil)
    #expect(store.data.breaks.count == count + 1)
}

@MainActor @Test func sleepAndLockRequireBothToResume() {
    let store = HealthStore(demo: true)
    store.suspend(true, reason: "sleep")
    store.suspend(true, reason: "session")
    store.suspend(false, reason: "sleep")
    #expect(store.systemSuspended)
    store.suspend(false, reason: "session")
    #expect(!store.systemSuspended)
}

@MainActor @Test func disablingIdleDetectionPreservesReadingSessions() {
    let store = HealthStore(demo: true)
    store.updatePreferences { $0.detectIdle = false }
    let clock = ProcessInfo.processInfo.systemUptime
    let date = Date()
    let remaining = store.engine.remaining
    for second in 1...150 {
        store.tick(currentDate: date.addingTimeInterval(Double(second)), uptime: clock + Double(second), idleSeconds: Double(second))
    }
    #expect(!store.idleAway)
    #expect(store.pendingBreak == nil)
    #expect(store.engine.remaining < remaining - 149)
}

@MainActor @Test func ignoredConfirmationDoesNotStopRemindersForever() {
    let store = HealthStore(demo: true)
    let count = store.data.breaks.count
    let clock = ProcessInfo.processInfo.systemUptime
    let date = Date()
    for second in 1...150 {
        store.tick(currentDate: date.addingTimeInterval(Double(second)), uptime: clock + Double(second), idleSeconds: Double(second))
    }
    store.tick(currentDate: date.addingTimeInterval(151), uptime: clock + 151, idleSeconds: 0)
    #expect(store.pendingBreak != nil)
    for second in 152...212 {
        store.tick(currentDate: date.addingTimeInterval(Double(second)), uptime: clock + Double(second), idleSeconds: 0)
    }
    #expect(store.pendingBreak == nil)
    #expect(store.data.breaks.count == count)
    #expect(!store.engine.isPaused)
}
