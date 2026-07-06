import Foundation

enum TimerRunState: Equatable {
    case idle
    case running
    case paused
    case completed
}

struct TimerSnapshot: Equatable {
    var configuredDuration: TimeInterval
    var remaining: TimeInterval
    var stealthRemaining: TimeInterval
    var visualProgress: Double
    var state: TimerRunState
    var lastEnteredDuration: TimeInterval
}

struct TimerEngine: Equatable {
    private(set) var configuredDuration: TimeInterval
    private(set) var lastEnteredDuration: TimeInterval
    private(set) var state: TimerRunState

    private var anchorTime: Date?
    private var anchorRemaining: TimeInterval
    private var anchorVisualProgress: Double
    private var completionAlreadyReported: Bool

    init(defaultDuration: TimeInterval = 5 * 60) {
        let duration = max(0, defaultDuration)
        configuredDuration = duration
        lastEnteredDuration = duration
        state = .idle
        anchorTime = nil
        anchorRemaining = duration
        anchorVisualProgress = duration > 0 ? 1 : 0
        completionAlreadyReported = false
    }

    func snapshot(at date: Date) -> TimerSnapshot {
        let values = currentValues(at: date)
        return TimerSnapshot(
            configuredDuration: configuredDuration,
            remaining: values.remaining,
            stealthRemaining: configuredDuration * values.visualProgress,
            visualProgress: values.visualProgress,
            state: state,
            lastEnteredDuration: lastEnteredDuration
        )
    }

    mutating func start(duration: TimeInterval, at date: Date) {
        let sanitizedDuration = max(0, duration)
        configuredDuration = sanitizedDuration
        lastEnteredDuration = sanitizedDuration
        state = sanitizedDuration > 0 ? .running : .completed
        anchorTime = date
        anchorRemaining = sanitizedDuration
        anchorVisualProgress = sanitizedDuration > 0 ? 1 : 0
        completionAlreadyReported = false
    }

    mutating func setPaused(duration: TimeInterval) {
        let sanitizedDuration = max(0, duration)
        configuredDuration = sanitizedDuration
        lastEnteredDuration = sanitizedDuration
        state = sanitizedDuration > 0 ? .paused : .idle
        anchorTime = nil
        anchorRemaining = sanitizedDuration
        anchorVisualProgress = sanitizedDuration > 0 ? 1 : 0
        completionAlreadyReported = false
    }

    mutating func pause(at date: Date) {
        guard state == .running else { return }
        let values = currentValues(at: date)
        state = .paused
        anchorTime = nil
        anchorRemaining = values.remaining
        anchorVisualProgress = values.visualProgress
    }

    mutating func resume(at date: Date) {
        guard state == .paused, anchorRemaining > 0 else { return }
        state = .running
        anchorTime = date
    }

    mutating func toggleRunning(at date: Date) {
        switch state {
        case .running:
            pause(at: date)
        case .paused, .idle:
            if state == .idle {
                start(duration: lastEnteredDuration, at: date)
            } else {
                resume(at: date)
            }
        case .completed:
            start(duration: lastEnteredDuration, at: date)
        }
    }

    mutating func adjustRemaining(by delta: TimeInterval, at date: Date) -> Bool {
        guard state == .running || state == .paused else { return false }
        let values = currentValues(at: date)
        let newRemaining = max(0, values.remaining + delta)
        anchorRemaining = newRemaining
        anchorVisualProgress = newRemaining > 0 ? values.visualProgress : 0
        anchorTime = state == .running ? date : nil

        if newRemaining == 0 {
            state = .completed
            return reportCompletionIfNeeded()
        }

        return false
    }

    mutating func tick(at date: Date) -> Bool {
        guard state == .running else { return false }
        let values = currentValues(at: date)
        guard values.remaining <= 0 else { return false }

        state = .completed
        anchorTime = nil
        anchorRemaining = 0
        anchorVisualProgress = 0

        return reportCompletionIfNeeded()
    }

    private func currentValues(at date: Date) -> (remaining: TimeInterval, visualProgress: Double) {
        guard state == .running, let anchorTime else {
            return (anchorRemaining, anchorVisualProgress)
        }

        let elapsed = max(0, date.timeIntervalSince(anchorTime))
        let remaining = max(0, anchorRemaining - elapsed)

        guard anchorRemaining > 0 else {
            return (0, 0)
        }

        let visualRate = anchorVisualProgress / anchorRemaining
        let visualProgress = clamp(anchorVisualProgress - elapsed * visualRate, lower: 0, upper: 1)
        return (remaining, visualProgress)
    }

    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private mutating func reportCompletionIfNeeded() -> Bool {
        if completionAlreadyReported {
            return false
        }

        completionAlreadyReported = true
        return true
    }
}
