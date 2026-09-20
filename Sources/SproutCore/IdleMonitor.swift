import Foundation

/// Uses only aggregate seconds since input. Inactivity is a hint, never proof of standing.
public struct IdleMonitor {
    public enum Event: Equatable {
        case becameIdle
        case returned(seconds: Int)
    }
    public private(set) var isAway = false
    private var peakIdle: TimeInterval = 0
    public init() {}

    public mutating func sample(idleSeconds: TimeInterval) -> Event? {
        guard idleSeconds.isFinite, idleSeconds >= 0 else { return nil }
        if idleSeconds >= 60 {
            peakIdle = max(peakIdle, idleSeconds)
            guard !isAway else { return nil }
            isAway = true
            return .becameIdle
        }
        guard isAway else { return nil }
        let duration = Int(min(peakIdle, 86_400))
        isAway = false
        peakIdle = 0
        return .returned(seconds: duration)
    }

    public mutating func reset() { isAway = false; peakIdle = 0 }
}
