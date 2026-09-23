import Foundation
import Testing
@testable import SproutCore

@Test func growthRewardsCrossingGoalOnlyOncePerDay() throws {
    var data = HealthData()
    data.preferences.waterGoalML = 500
    let now = Date(timeIntervalSince1970: 1800000000)
    _ = data.addWater(250, at: now)
    #expect(data.growthXP == 0)
    let entryID = data.addWater(250, at: now)
    let last = try #require(entryID)
    #expect(data.growthXP == 10)
    data.removeWater(id: last)
    _ = data.addWater(250, at: now)
    _ = data.addWater(1000, at: now)
    #expect(data.growthXP == 10)
    #expect(data.level == 1)
}

@Test func growthLevelsAndAwardsSurvivePersistence() throws {
    var data = HealthData()
    data.preferences.waterGoalML = 500
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = Date(timeIntervalSince1970: 1800000000)
    for day in 0..<3 {
        _ = data.addWater(500, at: calendar.date(byAdding: .day, value: day, to: start)!, calendar: calendar)
    }
    #expect(data.level == 2)
    #expect(data.levelXP == 0)
    let bytes = try JSONEncoder().encode(data)
    var restored = try JSONDecoder().decode(HealthData.self, from: bytes)
    #expect(restored.growthXP == 30)
    restored.water = []
    _ = restored.addWater(500, at: start, calendar: calendar)
    #expect(restored.growthXP == 30)
}

@Test func growthOldRecordsLoadWithoutRetroactiveRewards() throws {
    var old = HealthData()
    _ = old.addWater(1000)
    let encoded = try JSONEncoder().encode(old)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "growthDays")
    let restored = try JSONDecoder().decode(HealthData.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(restored.level == 1)
    #expect(restored.growthXP == 0)
    #expect(restored.water == old.water)
}

@Test func growthDoesNotRewardLoweringGoalOrInvalidWater() {
    var data = HealthData()
    _ = data.addWater(500)
    data.preferences.waterGoalML = 250
    _ = data.addWater(250)
    #expect(data.growthXP == 0)
    #expect(data.addWater(0) == nil)
    #expect(data.growthXP == 0)
}

@Test func growthUsesLocalDayAcrossMidnight() {
    var data = HealthData()
    data.preferences.waterGoalML = 250
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 28800)!
    let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 23, minute: 59))!
    _ = data.addWater(250, at: date, calendar: calendar)
    _ = data.addWater(250, at: date.addingTimeInterval(120), calendar: calendar)
    #expect(data.growthXP == 20)
}
