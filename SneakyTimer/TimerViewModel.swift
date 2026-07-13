import Combine
import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var snapshot: TimerSnapshot
    @Published private(set) var adjustmentDuration: TimeInterval
    @Published private(set) var initialTimerPosition: Int
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
    private var shouldStartNewRunOnPlay = true

    private static let lastDurationKey = "lastEnteredDuration"
    private static let adjustmentDurationKey = "adjustmentDuration"
    private static let hidesAdjustedTimeKey = "hidesAdjustedTime"
    private static let initialTimerPositionKey = "initialTimerPosition"

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
        let storedInitialTimerPosition = defaults.object(forKey: Self.initialTimerPositionKey) as? Int
        adjustmentDuration = storedAdjustmentDuration ?? 30
        hidesAdjustedTime = storedHidesAdjustedTime ?? true
        initialTimerPosition = Self.sanitizedInitialTimerPosition(storedInitialTimerPosition ?? 100)
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
        return TimerFormatting.countdown(displayedRemaining)
    }

    var entryDefaultText: String {
        TimerFormatting.digits(for: snapshot.lastEnteredDuration)
    }

    var adjustmentEntryDefaultText: String {
        TimerFormatting.digits(for: adjustmentDuration)
    }

    var adjustmentDisplayText: String {
        TimerFormatting.readableDuration(adjustmentDuration)
    }

    var initialDurationDisplayText: String {
        TimerFormatting.readableDuration(snapshot.lastEnteredDuration)
    }

    var initialPositionEntryDefaultText: String {
        String(initialTimerPosition)
    }

    var initialPositionDisplayText: String {
        "\(initialTimerPosition)%"
    }

    var isRunning: Bool {
        snapshot.state == .running
    }

    func toggleRunning() {
        let now = nowProvider()
        switch snapshot.state {
        case .running:
            engine.pause(at: now)
        case .paused:
            if shouldStartNewRunOnPlay {
                beginNewRun(duration: snapshot.lastEnteredDuration, at: now)
            } else {
                resumeCurrentRun(at: now)
            }
        case .idle, .completed:
            beginNewRun(duration: snapshot.lastEnteredDuration, at: now)
        }
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
        beginNewRun(duration: duration, at: now)
        defaults.set(duration, forKey: Self.lastDurationKey)
        endActualRemainingReveal()
        refresh(at: now)
        updateCompletionAlert()
    }

    func save(duration: TimeInterval) {
        engine.setPaused(duration: duration)
        defaults.set(duration, forKey: Self.lastDurationKey)
        shouldStartNewRunOnPlay = true
        endActualRemainingReveal()
        refresh(at: nowProvider())
        updateCompletionAlert()
    }

    func saveAdjustmentDuration(_ duration: TimeInterval) {
        adjustmentDuration = max(0, duration)
        defaults.set(adjustmentDuration, forKey: Self.adjustmentDurationKey)
    }

    func saveInitialTimerPosition(_ position: Int) {
        guard (1...100).contains(position) else { return }
        initialTimerPosition = position
        defaults.set(position, forKey: Self.initialTimerPositionKey)
        shouldStartNewRunOnPlay = true
    }

    func resetToCurrentSettings() {
        engine.setPaused(
            duration: snapshot.lastEnteredDuration,
            initialProgress: Double(initialTimerPosition) / 100
        )
        shouldStartNewRunOnPlay = true
        endActualRemainingReveal()
        refresh(at: nowProvider())
        updateCompletionAlert()
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

    private static func sanitizedInitialTimerPosition(_ position: Int) -> Int {
        (1...100).contains(position) ? position : 100
    }

    private func beginNewRun(duration: TimeInterval, at date: Date) {
        engine.start(
            duration: duration,
            initialProgress: Double(initialTimerPosition) / 100,
            at: date
        )
        shouldStartNewRunOnPlay = false
    }

    private func resumeCurrentRun(at date: Date) {
        engine.resume(at: date)
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
