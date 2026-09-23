import Foundation
import Testing
@testable import SproutApp

@MainActor @Test func growthCelebratesOnceAndDoesNotReplayAfterRestart() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("health.json")
    let store = HealthStore(dataURL: url, systemIntegration: false)
    store.updatePreferences { $0.waterGoalML = 500 }
    store.addWater(250)
    #expect(!store.celebratingGrowth)
    store.addWater(250)
    #expect(store.celebratingGrowth)
    #expect(store.data.growthXP == 10)
    store.shutdown()
    let restored = HealthStore(dataURL: url, systemIntegration: false)
    #expect(!restored.celebratingGrowth)
    #expect(restored.data.growthXP == 10)
    restored.undoWater()
    restored.addWater(250)
    #expect(!restored.celebratingGrowth)
    #expect(restored.data.growthXP == 10)
    restored.shutdown()
}
