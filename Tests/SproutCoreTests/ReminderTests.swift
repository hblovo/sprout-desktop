import Foundation
import Testing
@testable import SproutCore

@Test func defaultCycleIs45Minutes() {
    let engine = ReminderEngine()
    #expect(engine.displayTime == "45:00")
    #expect(engine.phase == .focus)
    #expect(engine.progress == 0)
}

@Test func dueReminderFiresExactlyOnce() {
    var engine = ReminderEngine()
    #expect(engine.tick(elapsed: 2699) == nil)
    #expect(engine.displayTime == "00:01")
    #expect(engine.tick(elapsed: 1) == .breakDue)
    #expect(engine.phase == .due)
    #expect(engine.tick(elapsed: 10000) == nil)
}

@Test func pausePreservesRemainingAndPhase() {
    var engine = ReminderEngine()
    _ = engine.tick(elapsed: 100)
    engine.setPaused(true)
    #expect(engine.tick(elapsed: 600) == nil)
    #expect(engine.remaining == 2600)
    engine.setPaused(false)
    _ = engine.tick(elapsed: 1)
    #expect(engine.remaining == 2599)
}

@Test func quietHoursFreezeTheTimer() {
    var engine = ReminderEngine()
    _ = engine.tick(elapsed: 2701, quiet: true)
    #expect(engine.remaining == 2700)
    #expect(engine.phase == .focus)
}

@Test func snoozeIsFiveMinutesAndCannotAffectOtherPhases() {
    var engine = ReminderEngine()
    engine.snooze()
    #expect(engine.remaining == 2700)
    _ = engine.tick(elapsed: 2700)
    engine.snooze()
    #expect(engine.remaining == 300)
    #expect(engine.isSnoozed)
    #expect(engine.tick(elapsed: 300) == .breakDue)
    #expect(!engine.isSnoozed)
}

@Test func completedBreakReturnsOneEventAndFreshFocus() {
    var engine = ReminderEngine()
    engine.startBreak()
    #expect(engine.displayTime == "02:00")
    #expect(engine.tick(elapsed: 120) == .breakCompleted(seconds: 120))
    #expect(engine.phase == .focus)
    #expect(engine.remaining == 2700)
    #expect(engine.tick(elapsed: 1) == nil)
}

@Test func canceledBreakDoesNotEmitCompletion() {
    var engine = ReminderEngine()
    engine.startBreak()
    _ = engine.tick(elapsed: 60)
    engine.resetFocus()
    #expect(engine.tick(elapsed: 60) == nil)
    #expect(engine.phase == .focus)
}

@Test func breakCanBePausedAndResumed() {
    var engine = ReminderEngine()
    engine.startBreak()
    engine.setPaused(true)
    _ = engine.tick(elapsed: 500)
    #expect(engine.remaining == 120)
    engine.setPaused(false)
    #expect(engine.tick(elapsed: 120) == .breakCompleted(seconds: 120))
}

@Test func changedPreferencesApplyToNextBreakWithoutRewritingCurrentOne() {
    var engine = ReminderEngine()
    engine.startBreak()
    _ = engine.tick(elapsed: 30)
    engine.configure(focusMinutes: 60, breakMinutes: 5)
    #expect(engine.remaining == 90)
    #expect(engine.tick(elapsed: 90) == .breakCompleted(seconds: 120))
    #expect(engine.remaining == 3600)
    engine.startBreak()
    #expect(engine.remaining == 300)
}

@Test func changedFocusIntervalRestartsCycleButRetainsPause() {
    var engine = ReminderEngine()
    _ = engine.tick(elapsed: 100)
    engine.setPaused(true)
    engine.configure(focusMinutes: 30, breakMinutes: 2)
    #expect(engine.remaining == 1800)
    #expect(engine.isPaused)
}

@Test func malformedElapsedIsIgnored() {
    var engine = ReminderEngine()
    _ = engine.tick(elapsed: -.infinity)
    _ = engine.tick(elapsed: .nan)
    _ = engine.tick(elapsed: -100)
    #expect(engine.remaining == 2700)
}
