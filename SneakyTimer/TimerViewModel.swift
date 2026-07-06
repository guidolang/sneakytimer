import Combine
import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var snapshot: TimerSnapshot
    @Published private(set) var adjustmentDuration: TimeInterval
    @Published private(set) var isShowingActualRemaining = false
    @Published var hidesAdjustedTime: Bool {
        didSet {
            defaults.set(hidesAdjustedTime, forKey: Self.hidesAdjustedTimeKey)
            if !hidesAdjustedTime {
                endActualRemainingReveal()
            }
        }
    }

    private var engine: TimerEngine
    private let alarmService: AlarmService
    private let completionNotifier: TimerCompletionNotifier
    private let defaults: UserDefaults
    private let nowProvider: () -> Date
    private let actualRemainingHoldDuration: TimeInterval
    private var ticker: AnyCancellable?
    private var actualRemainingRevealEndDate: Date?
    private var isTimeDisplayPressed = false

    private static let lastDurationKey = "lastEnteredDuration"
    private static let adjustmentDurationKey = "adjustmentDuration"
    private static let hidesAdjustedTimeKey = "hidesAdjustedTime"

    init(
        engine: TimerEngine? = nil,
        alarmService: AlarmService = SystemAlarmService(),
        completionNotifier: TimerCompletionNotifier = SystemTimerCompletionNotifier(),
        defaults: UserDefaults = .standard,
        nowProvider: @escaping () -> Date = Date.init,
        actualRemainingHoldDuration: TimeInterval = 1.25,
        shouldStartTicker: Bool = true
    ) {
        self.defaults = defaults
        self.nowProvider = nowProvider
        self.actualRemainingHoldDuration = actualRemainingHoldDuration
        let storedDuration = defaults.object(forKey: Self.lastDurationKey) as? Double
        let storedAdjustmentDuration = defaults.object(forKey: Self.adjustmentDurationKey) as? Double
        let storedHidesAdjustedTime = defaults.object(forKey: Self.hidesAdjustedTimeKey) as? Bool
        adjustmentDuration = storedAdjustmentDuration ?? 30
        hidesAdjustedTime = storedHidesAdjustedTime ?? true
        self.engine = engine ?? TimerEngine(defaultDuration: storedDuration ?? 60)
        self.alarmService = alarmService
        self.completionNotifier = completionNotifier
        snapshot = self.engine.snapshot(at: nowProvider())

        if shouldStartTicker {
            ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] date in
                    Task { @MainActor in
                        self?.tick(at: date)
                    }
                }
        }
    }

    var countdownText: String {
        let displayedRemaining = hidesAdjustedTime && !isShowingActualRemaining ? snapshot.stealthRemaining : snapshot.remaining
        return Self.formatDuration(displayedRemaining)
    }

    var entryDefaultText: String {
        Self.digits(for: snapshot.lastEnteredDuration)
    }

    var adjustmentEntryDefaultText: String {
        Self.digits(for: adjustmentDuration)
    }

    var adjustmentDisplayText: String {
        Self.formatReadableDuration(adjustmentDuration)
    }

    var isRunning: Bool {
        snapshot.state == .running
    }

    func toggleRunning() {
        let now = nowProvider()
        engine.toggleRunning(at: now)
        refresh(at: now)
        updateCompletionAlert()
    }

    func addAdjustmentDuration() {
        adjust(by: adjustmentDuration)
    }

    func subtractAdjustmentDuration() {
        adjust(by: -adjustmentDuration)
    }

    func start(duration: TimeInterval) {
        let now = nowProvider()
        engine.start(duration: duration, at: now)
        defaults.set(duration, forKey: Self.lastDurationKey)
        endActualRemainingReveal()
        refresh(at: now)
        updateCompletionAlert()
    }

    func save(duration: TimeInterval) {
        engine.setPaused(duration: duration)
        defaults.set(duration, forKey: Self.lastDurationKey)
        endActualRemainingReveal()
        refresh(at: nowProvider())
        updateCompletionAlert()
    }

    func saveAdjustmentDuration(_ duration: TimeInterval) {
        adjustmentDuration = max(0, duration)
        defaults.set(adjustmentDuration, forKey: Self.adjustmentDurationKey)
    }

    func handleTimeDisplayPress() {
        guard hidesAdjustedTime else { return }
        isTimeDisplayPressed = true
        actualRemainingRevealEndDate = nil
        isShowingActualRemaining = true
    }

    func handleTimeDisplayRelease() {
        guard hidesAdjustedTime else { return }
        isTimeDisplayPressed = false
        revealActualRemaining(until: nowProvider().addingTimeInterval(actualRemainingHoldDuration))
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(ceil(duration)))
        if totalSeconds > 60 * 60 {
            return formatHoursMinutesSeconds(totalSeconds)
        }

        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d : %02d", minutes, seconds)
    }

    static func formatEntryDuration(_ duration: TimeInterval) -> String {
        formatHoursMinutesSeconds(max(0, Int(duration.rounded())))
    }

    static func duration(from digits: String) -> TimeInterval {
        let padded = String(digits.suffix(6)).leftPadded(toLength: 6, with: "0")
        let hourDigits = padded.prefix(2)
        let minuteDigits = padded.dropFirst(2).prefix(2)
        let secondDigits = padded.suffix(2)
        let hours = Int(hourDigits) ?? 0
        let minutes = Int(minuteDigits) ?? 0
        let seconds = Int(secondDigits) ?? 0
        return TimeInterval(hours * 60 * 60 + minutes * 60 + seconds)
    }

    static func digits(for duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = min(totalSeconds / 3600, 99)
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d%02d%02d", hours, minutes, seconds)
    }

    static func formatReadableDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        var parts: [String] = []

        if hours > 0 {
            parts.append("\(hours) hr")
        }
        if minutes > 0 {
            parts.append("\(minutes) min")
        }
        if seconds > 0 || parts.isEmpty {
            parts.append("\(seconds) sec")
        }

        return parts.joined(separator: " ")
    }

    private static func formatHoursMinutesSeconds(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d : %02d : %02d", hours, minutes, seconds)
    }

    private func adjust(by delta: TimeInterval) {
        let now = nowProvider()
        let beforeAdjustment = engine.snapshot(at: now)
        let didAcceptAdjustment = beforeAdjustment.state == .running || beforeAdjustment.state == .paused
        if engine.adjustRemaining(by: delta, at: now) || engine.tick(at: now) {
            alarmService.timerDidComplete()
        }
        if didAcceptAdjustment && hidesAdjustedTime {
            revealActualRemaining(until: now.addingTimeInterval(actualRemainingHoldDuration))
        }
        refresh(at: now)
        updateCompletionAlert()
    }

    func tick(at date: Date) {
        if engine.tick(at: date) {
            completionNotifier.cancelTimerCompletedAlert()
            alarmService.timerDidComplete()
        }
        refresh(at: date)
    }

    private func refresh(at date: Date) {
        snapshot = engine.snapshot(at: date)
        updateActualRemainingReveal(at: date)
    }

    private func updateCompletionAlert() {
        if snapshot.state == .running, snapshot.remaining > 0 {
            completionNotifier.requestAuthorization()
            completionNotifier.scheduleTimerCompletedAlert(in: snapshot.remaining)
        } else {
            completionNotifier.cancelTimerCompletedAlert()
        }
    }

    private func revealActualRemaining(until endDate: Date) {
        actualRemainingRevealEndDate = endDate
        isShowingActualRemaining = true
    }

    private func updateActualRemainingReveal(at date: Date) {
        guard !isTimeDisplayPressed, let actualRemainingRevealEndDate else { return }
        if date >= actualRemainingRevealEndDate {
            endActualRemainingReveal()
        }
    }

    private func endActualRemainingReveal() {
        actualRemainingRevealEndDate = nil
        isTimeDisplayPressed = false
        isShowingActualRemaining = false
    }
}

private extension String {
    func leftPadded(toLength length: Int, with character: Character) -> String {
        guard count < length else { return self }
        return String(repeating: String(character), count: length - count) + self
    }
}
