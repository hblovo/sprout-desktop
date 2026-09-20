import Foundation

public struct Preferences: Codable, Equatable {
    public var focusMinutes = 45
    public var breakMinutes = 2
    public var cupML = 250
    public var waterGoalML = 2000
    public var petVisible = true
    public var reduceMotion = false
    public var notificationsEnabled = false
    public var waterRemindersEnabled = false
    public var quietHoursEnabled = false
    public var quietStartHour = 22
    public var quietEndHour = 8
    public var detectIdle = true

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case focusMinutes, breakMinutes, cupML, waterGoalML, petVisible, reduceMotion
        case notificationsEnabled, waterRemindersEnabled, quietHoursEnabled, quietStartHour, quietEndHour, detectIdle
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try values.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 45
        breakMinutes = try values.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 2
        cupML = try values.decodeIfPresent(Int.self, forKey: .cupML) ?? 250
        waterGoalML = try values.decodeIfPresent(Int.self, forKey: .waterGoalML) ?? 2000
        petVisible = try values.decodeIfPresent(Bool.self, forKey: .petVisible) ?? true
        reduceMotion = try values.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
        notificationsEnabled = try values.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        waterRemindersEnabled = try values.decodeIfPresent(Bool.self, forKey: .waterRemindersEnabled) ?? false
        quietHoursEnabled = try values.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? false
        quietStartHour = try values.decodeIfPresent(Int.self, forKey: .quietStartHour) ?? 22
        quietEndHour = try values.decodeIfPresent(Int.self, forKey: .quietEndHour) ?? 8
        detectIdle = try values.decodeIfPresent(Bool.self, forKey: .detectIdle) ?? true
    }

    public mutating func sanitize() {
        focusMinutes = min(120, max(15, focusMinutes))
        breakMinutes = min(10, max(1, breakMinutes))
        cupML = min(1000, max(50, cupML))
        waterGoalML = min(5000, max(250, waterGoalML))
        quietStartHour = min(23, max(0, quietStartHour))
        quietEndHour = min(23, max(0, quietEndHour))
    }

    public func isQuiet(at date: Date, calendar: Calendar = .current) -> Bool {
        guard quietHoursEnabled, quietStartHour != quietEndHour else { return false }
        let hour = calendar.component(.hour, from: date)
        if quietStartHour < quietEndHour {
            return hour >= quietStartHour && hour < quietEndHour
        }
        return hour >= quietStartHour || hour < quietEndHour
    }
}

public struct WaterEntry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var date: Date
    public var milliliters: Int

    public init(id: UUID = UUID(), date: Date = Date(), milliliters: Int) {
        self.id = id
        self.date = date
        self.milliliters = milliliters
    }
}

public struct BreakEntry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var date: Date
    public var seconds: Int

    public init(id: UUID = UUID(), date: Date = Date(), seconds: Int) {
        self.id = id
        self.date = date
        self.seconds = seconds
    }
}

public struct DailySummary: Identifiable {
    public var date: Date
    public var waterML: Int
    public var breakCount: Int
    public var breakSeconds: Int
    public var id: Date { date }
}

public struct HealthData: Codable, Equatable {
    public var version = 1
    public var preferences = Preferences()
    public var water: [WaterEntry] = []
    public var breaks: [BreakEntry] = []

    public init() {}

    public func summary(on date: Date, calendar: Calendar = .current) -> DailySummary {
        let waterToday = water.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let breaksToday = breaks.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return DailySummary(
            date: calendar.startOfDay(for: date),
            waterML: waterToday.reduce(0) { $0 + $1.milliliters },
            breakCount: breaksToday.count,
            breakSeconds: breaksToday.reduce(0) { $0 + $1.seconds }
        )
    }

    public func week(ending date: Date, calendar: Calendar = .current) -> [DailySummary] {
        (-6...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: date).map { summary(on: $0, calendar: calendar) }
        }
    }

    @discardableResult public mutating func addWater(_ amount: Int, at date: Date = Date()) -> UUID? {
        guard (50...1000).contains(amount) else { return nil }
        let entry = WaterEntry(date: date, milliliters: amount)
        water.append(entry)
        return entry.id
    }

    public mutating func removeWater(id: UUID) {
        water.removeAll { $0.id == id }
    }
}

public struct HealthRepository {
    public let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> HealthData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return HealthData() }
        let bytes = try Data(contentsOf: fileURL)
        var result = try JSONDecoder().decode(HealthData.self, from: bytes)
        guard result.version == 1 else { throw RepositoryError.unsupportedVersion }
        result.preferences.sanitize()
        guard result.water.allSatisfy({ (50...1000).contains($0.milliliters) }),
              result.breaks.allSatisfy({ $0.seconds > 0 && $0.seconds <= 1800 }) else {
            throw RepositoryError.invalidData
        }
        return result
    }

    public func save(_ data: HealthData) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: fileURL, options: .atomic)
    }

    public enum RepositoryError: Error { case unsupportedVersion, invalidData }
}
