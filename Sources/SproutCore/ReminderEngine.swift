import Foundation

public struct ReminderEngine: Codable, Equatable {
    public enum Phase: String, Codable, Equatable { case focus, due, resting }
    public enum Event: Equatable { case breakDue, breakCompleted(seconds: Int) }

    public private(set) var phase: Phase = .focus
    public private(set) var remaining: TimeInterval
    public private(set) var isPaused = false
    public private(set) var isSnoozed = false
    public private(set) var focusDuration: TimeInterval
    public private(set) var breakDuration: TimeInterval
    public private(set) var cycleDuration: TimeInterval
    private var currentBreakDuration: TimeInterval

    public var isValidSnapshot: Bool {
        guard (60...7200).contains(focusDuration), (60...600).contains(breakDuration),
              (60...600).contains(currentBreakDuration), cycleDuration.isFinite,
              cycleDuration > 0, cycleDuration <= 7200, remaining.isFinite,
              remaining >= 0, remaining <= cycleDuration else { return false }
        switch phase {
        case .focus: return remaining > 0 && cycleDuration == (isSnoozed ? 300 : focusDuration)
        case .due: return remaining == 0 && !isSnoozed
        case .resting: return remaining > 0 && cycleDuration == currentBreakDuration && !isSnoozed
        }
    }

    public init(focusMinutes: Int = 45, breakMinutes: Int = 2) {
        focusDuration = TimeInterval(max(1, focusMinutes) * 60)
        breakDuration = TimeInterval(max(1, breakMinutes) * 60)
        currentBreakDuration = breakDuration
        cycleDuration = focusDuration
        remaining = focusDuration
    }

    public var progress: Double {
        guard cycleDuration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / cycleDuration))
    }

    public var displayTime: String {
        let seconds = max(0, Int(ceil(remaining)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    /// Caller supplies awake, monotonic elapsed time. Quiet hours freeze the cycle.
    public mutating func tick(elapsed: TimeInterval, quiet: Bool = false) -> Event? {
        guard !isPaused, !quiet, elapsed.isFinite, elapsed > 0, phase != .due else { return nil }
        remaining = max(0, remaining - elapsed)
        guard remaining == 0 else { return nil }
        switch phase {
        case .focus:
            phase = .due
            isSnoozed = false
            return .breakDue
        case .resting:
            let completed = Int(currentBreakDuration)
            resetFocus()
            return .breakCompleted(seconds: completed)
        case .due:
            return nil
        }
    }

    public mutating func startBreak() {
        phase = .resting
        isPaused = false
        isSnoozed = false
        currentBreakDuration = breakDuration
        cycleDuration = breakDuration
        remaining = breakDuration
    }

    public mutating func snooze() {
        guard phase == .due else { return }
        phase = .focus
        isPaused = false
        isSnoozed = true
        remaining = 5 * 60
        cycleDuration = remaining
    }

    public mutating func setPaused(_ paused: Bool) { isPaused = paused }

    public mutating func resetFocus() {
        phase = .focus
        remaining = focusDuration
        cycleDuration = focusDuration
        isSnoozed = false
    }

    public mutating func configure(focusMinutes: Int, breakMinutes: Int) {
        let newFocus = TimeInterval(max(1, focusMinutes) * 60)
        let changed = newFocus != focusDuration
        focusDuration = newFocus
        breakDuration = TimeInterval(max(1, breakMinutes) * 60)
        if changed && phase != .resting { resetFocus() }
    }
}
