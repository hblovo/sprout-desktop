import Foundation
import Testing
@testable import SproutCore

private func testCalendar(_ zone: String = "Asia/Shanghai") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}
private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

@Test func waterAndUndoUseRecordIdentity() {
    var data = HealthData()
    let timestamp = date("2026-09-20T04:00:00Z")
    let first = data.addWater(250, at: timestamp)!
    _ = data.addWater(500, at: timestamp)
    data.removeWater(id: first)
    data.removeWater(id: first)
    #expect(data.summary(on: timestamp, calendar: testCalendar()).waterML == 500)
    #expect(data.water.count == 1)
}

@Test func invalidWaterEntriesAreRejected() {
    var data = HealthData()
    #expect(data.addWater(-1) == nil)
    #expect(data.addWater(0) == nil)
    #expect(data.addWater(1001) == nil)
    #expect(data.water.isEmpty)
}

@Test func midnightCreatesANewDayWithoutDeletingHistory() {
    var data = HealthData()
    let before = date("2026-09-20T15:59:59Z")
    let after = date("2026-09-20T16:00:00Z")
    _ = data.addWater(250, at: before)
    _ = data.addWater(500, at: after)
    data.breaks.append(BreakEntry(date: before, seconds: 120))
    #expect(data.summary(on: before, calendar: testCalendar()).waterML == 250)
    #expect(data.summary(on: after, calendar: testCalendar()).waterML == 500)
    #expect(data.summary(on: after, calendar: testCalendar()).breakCount == 0)
    #expect(data.water.count == 2)
}

@Test func weeklySeriesHasSevenCalendarDaysAcrossDaylightSaving() {
    let calendar = testCalendar("America/Los_Angeles")
    let data = HealthData()
    let week = data.week(ending: date("2026-03-10T20:00:00Z"), calendar: calendar)
    #expect(week.count == 7)
    #expect(Set(week.map { calendar.component(.day, from: $0.date) }).count == 7)
    #expect(calendar.component(.day, from: week.first!.date) == 4)
    #expect(calendar.component(.day, from: week.last!.date) == 10)
}

@Test func overnightQuietHoursIncludeStartAndExcludeEnd() {
    var preferences = Preferences()
    preferences.quietHoursEnabled = true
    let calendar = testCalendar()
    #expect(preferences.isQuiet(at: date("2026-09-20T14:00:00Z"), calendar: calendar))
    #expect(preferences.isQuiet(at: date("2026-09-20T23:59:59Z"), calendar: calendar))
    #expect(!preferences.isQuiet(at: date("2026-09-21T00:00:00Z"), calendar: calendar))
    #expect(!preferences.isQuiet(at: date("2026-09-20T13:59:59Z"), calendar: calendar))
}

@Test func sameDayQuietHoursAndEqualEndpoints() {
    var preferences = Preferences()
    preferences.quietHoursEnabled = true
    preferences.quietStartHour = 12
    preferences.quietEndHour = 14
    #expect(preferences.isQuiet(at: date("2026-09-20T04:00:00Z"), calendar: testCalendar()))
    #expect(!preferences.isQuiet(at: date("2026-09-20T06:00:00Z"), calendar: testCalendar()))
    preferences.quietEndHour = 12
    #expect(!preferences.isQuiet(at: date("2026-09-20T04:00:00Z"), calendar: testCalendar()))
}

@Test func preferencesAreBoundedBeforeUse() {
    var preferences = Preferences()
    preferences.focusMinutes = -500
    preferences.breakMinutes = 999
    preferences.waterGoalML = 0
    preferences.cupML = -50
    preferences.sanitize()
    #expect(preferences.focusMinutes == 15)
    #expect(preferences.breakMinutes == 10)
    #expect(preferences.waterGoalML == 250)
    #expect(preferences.cupML == 50)
}

@Test func persistentDataRoundTripsAndMissingFileStartsEmpty() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = HealthRepository(fileURL: directory.appendingPathComponent("health.json"))
    #expect(try repository.load() == HealthData())
    var data = HealthData()
    _ = data.addWater(250)
    data.breaks.append(BreakEntry(seconds: 120))
    data.preferences.focusMinutes = 60
    try repository.save(data)
    #expect(try repository.load() == data)
}

@Test func corruptFileIsNeverOverwrittenByLoading() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let broken = Data("{not valid json".utf8)
    try broken.write(to: url)
    #expect(throws: (any Error).self) { try HealthRepository(fileURL: url).load() }
    #expect(try Data(contentsOf: url) == broken)
}

@Test func unsupportedSchemaIsRejected() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let repository = HealthRepository(fileURL: url)
    var data = HealthData()
    data.version = 2
    try repository.save(data)
    #expect(throws: (any Error).self) { try repository.load() }
}

@Test func invalidSavedEventsAreRejected() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let repository = HealthRepository(fileURL: url)
    var data = HealthData()
    data.water.append(WaterEntry(milliliters: -250))
    try repository.save(data)
    #expect(throws: (any Error).self) { try repository.load() }
}
