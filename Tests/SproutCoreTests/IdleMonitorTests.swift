import Foundation
import Testing
@testable import SproutCore

@Test func idleStartsAfterOneMinuteAndReturnsOnlyOnce() {
    var monitor = IdleMonitor()
    #expect(monitor.sample(idleSeconds: 59) == nil)
    #expect(!monitor.isAway)
    #expect(monitor.sample(idleSeconds: 60) == .becameIdle)
    #expect(monitor.isAway)
    #expect(monitor.sample(idleSeconds: 120) == nil)
    #expect(monitor.sample(idleSeconds: 180) == nil)
    #expect(monitor.sample(idleSeconds: 0.2) == .returned(seconds: 180))
    #expect(!monitor.isAway)
    #expect(monitor.sample(idleSeconds: 1.2) == nil)
}

@Test func idleResetDiscardsThePreviousEpisode() {
    var monitor = IdleMonitor()
    _ = monitor.sample(idleSeconds: 300)
    monitor.reset()
    #expect(monitor.sample(idleSeconds: 0) == nil)
    #expect(!monitor.isAway)
}

@Test func invalidIdleSamplesCannotChangeState() {
    var monitor = IdleMonitor()
    _ = monitor.sample(idleSeconds: .infinity)
    _ = monitor.sample(idleSeconds: .nan)
    _ = monitor.sample(idleSeconds: -1)
    #expect(!monitor.isAway)
}

@Test func versionOnePreferencesLoadWithNewSensibleDefaults() throws {
    let json = Data(#"{"focusMinutes":60,"cupML":300,"petVisible":false}"#.utf8)
    let preferences = try JSONDecoder().decode(Preferences.self, from: json)
    #expect(preferences.focusMinutes == 60)
    #expect(preferences.cupML == 300)
    #expect(!preferences.petVisible)
    #expect(preferences.detectIdle)
    #expect(preferences.breakMinutes == 2)
}
