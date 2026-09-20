import Foundation

public struct BreakCandidate: Codable, Equatable {
    public let id: UUID
    public let date: Date
    public let seconds: Int
    public let fromIdle: Bool
    public init(id: UUID = UUID(), date: Date, seconds: Int, fromIdle: Bool) {
        self.id = id
        self.date = date
        self.seconds = seconds
        self.fromIdle = fromIdle
    }
}

public struct SessionSnapshot: Codable, Equatable {
    public var version = 1
    public var engine: ReminderEngine
    public var engineBeforeBreak: ReminderEngine?
    public var pendingBreak: BreakCandidate?
    public var reviewElapsed: TimeInterval
    public var waterElapsed: TimeInterval

    public init(engine: ReminderEngine, engineBeforeBreak: ReminderEngine? = nil,
                pendingBreak: BreakCandidate? = nil, reviewElapsed: TimeInterval = 0, waterElapsed: TimeInterval = 0) {
        self.engine = engine
        self.engineBeforeBreak = engineBeforeBreak
        self.pendingBreak = pendingBreak
        self.reviewElapsed = reviewElapsed
        self.waterElapsed = waterElapsed
    }

    public var isValid: Bool {
        version == 1 && engine.isValidSnapshot && (engineBeforeBreak?.isValidSnapshot ?? true)
            && reviewElapsed.isFinite && (0...60).contains(reviewElapsed)
            && waterElapsed.isFinite && (0...3600).contains(waterElapsed)
            && (pendingBreak.map { (1...1800).contains($0.seconds) } ?? true)
            && (engine.phase != .resting || engineBeforeBreak != nil)
    }
}

/// Small, separate checkpoints avoid rewriting the entire health history every few seconds.
public struct SessionRepository {
    public let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> SessionSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let snapshot = try JSONDecoder().decode(SessionSnapshot.self, from: Data(contentsOf: fileURL))
        guard snapshot.isValid else { throw SessionError.invalidSnapshot }
        return snapshot
    }

    public func save(_ snapshot: SessionSnapshot) throws {
        guard snapshot.isValid else { throw SessionError.invalidSnapshot }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
    }

    public enum SessionError: Error { case invalidSnapshot }
}
