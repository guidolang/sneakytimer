import Combine
import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var snapshot: TimerSnapshot
    @Published private(set) var adjustmentDuration: TimeInterval
    @Published private(set) var displayedInitialDuration: TimeInterval
    @Published private(set) var actualInitialDuration: TimeInterval
    @Published private(set) var initialTimerPosition: Int
    @Published private(set) var presetDurations: [TimeInterval]
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
    private var preparedTimerConfiguration: PreparedTimerConfiguration

    private static let lastDurationKey = "lastEnteredDuration"
    private static let actualInitialDurationKey = "actualInitialDuration"
    private static let adjustmentDurationKey = "adjustmentDuration"
    private static let hidesAdjustedTimeKey = "hidesAdjustedTime"
    private static let initialTimerPositionKey = "initialTimerPosition"
    private static let presetDurationsKey = "presetDurations"
    private static let defaultPresetDurations: [TimeInterval] = [60, 300, 600]
    private static let maximumPresetCount = 10

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
        let displayedDuration = storedDuration ?? 60
        let storedActualInitialDuration = defaults.object(forKey: Self.actualInitialDurationKey) as? Double
        let storedAdjustmentDuration = defaults.object(forKey: Self.adjustmentDurationKey) as? Double
        let storedHidesAdjustedTime = defaults.object(forKey: Self.hidesAdjustedTimeKey) as? Bool
        let storedInitialTimerPosition = defaults.object(forKey: Self.initialTimerPositionKey) as? Int
        let storedPresetDurations = defaults.array(forKey: Self.presetDurationsKey)?
            .compactMap { ($0 as? NSNumber)?.doubleValue }
        adjustmentDuration = storedAdjustmentDuration ?? 30
        displayedInitialDuration = max(0, displayedDuration)
        actualInitialDuration = max(0, storedActualInitialDuration ?? displayedDuration)
        hidesAdjustedTime = storedHidesAdjustedTime ?? true
        initialTimerPosition = Self.sanitizedInitialTimerPosition(storedInitialTimerPosition ?? 100)
        presetDurations = Self.sanitizedPresetDurations(storedPresetDurations)
        preparedTimerConfiguration = PreparedTimerConfiguration(
            displayedDuration: max(0, displayedDuration),
            actualDuration: max(0, storedActualInitialDuration ?? displayedDuration),
            initialProgress: Double(Self.sanitizedInitialTimerPosition(storedInitialTimerPosition ?? 100)) / 100
        )
        self.engine = engine ?? TimerEngine(defaultDuration: displayedDuration)
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
        TimerFormatting.digits(for: displayedInitialDuration)
    }

    var actualDurationEntryDefaultText: String {
        TimerFormatting.digits(for: actualInitialDuration)
    }

    var adjustmentEntryDefaultText: String {
        TimerFormatting.digits(for: adjustmentDuration)
    }

    var adjustmentDisplayText: String {
        TimerFormatting.readableDuration(adjustmentDuration)
    }

    var displayedDurationDisplayText: String {
        TimerFormatting.readableDuration(displayedInitialDuration)
    }

    var actualDurationDisplayText: String {
        TimerFormatting.readableDuration(actualInitialDuration)
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

    var canAddPresetTimer: Bool {
        presetDurations.count < Self.maximumPresetCount
    }

    var canDeletePresetTimer: Bool {
        presetDurations.count > 1
    }

    func toggleRunning() {
        let now = nowProvider()
        switch snapshot.state {
        case .running:
            engine.pause(at: now)
        case .paused:
            if shouldStartNewRunOnPlay {
                beginNewRun(at: now)
            } else {
                resumeCurrentRun(at: now)
            }
        case .idle, .completed:
            beginNewRun(at: now)
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
        displayedInitialDuration = max(0, duration)
        actualInitialDuration = displayedInitialDuration
        preparedTimerConfiguration = PreparedTimerConfiguration(
            displayedDuration: displayedInitialDuration,
            actualDuration: actualInitialDuration,
            initialProgress: Double(initialTimerPosition) / 100
        )
        defaults.set(displayedInitialDuration, forKey: Self.lastDurationKey)
        defaults.set(actualInitialDuration, forKey: Self.actualInitialDurationKey)
        engine.start(
            displayedDuration: displayedInitialDuration,
            actualDuration: actualInitialDuration,
            initialProgress: Double(initialTimerPosition) / 100,
            at: now
        )
        shouldStartNewRunOnPlay = false
        endActualRemainingReveal()
        refresh(at: now)
        updateCompletionAlert()
    }

    func saveDisplayedDuration(_ duration: TimeInterval) {
        let sanitizedDuration = max(0, duration)
        displayedInitialDuration = sanitizedDuration
        actualInitialDuration = sanitizedDuration
        defaults.set(sanitizedDuration, forKey: Self.lastDurationKey)
        defaults.set(sanitizedDuration, forKey: Self.actualInitialDurationKey)
        resetToCurrentSettings()
    }

    func saveActualDuration(_ duration: TimeInterval) {
        actualInitialDuration = max(0, duration)
        defaults.set(actualInitialDuration, forKey: Self.actualInitialDurationKey)
        resetToCurrentSettings()
    }

    func save(duration: TimeInterval) {
        saveDisplayedDuration(duration)
    }

    private func preparePausedTimerFromCurrentSettings() {
        preparePausedTimer(
            displayedDuration: displayedInitialDuration,
            actualDuration: actualInitialDuration,
            initialProgress: Double(initialTimerPosition) / 100
        )
    }

    func saveAdjustmentDuration(_ duration: TimeInterval) {
        adjustmentDuration = max(0, duration)
        defaults.set(adjustmentDuration, forKey: Self.adjustmentDurationKey)
    }

    func saveInitialTimerPosition(_ position: Int) {
        guard (1...100).contains(position) else { return }
        initialTimerPosition = position
        defaults.set(position, forKey: Self.initialTimerPositionKey)
        resetToCurrentSettings()
    }

    func resetToCurrentSettings() {
        preparePausedTimerFromCurrentSettings()
    }

    func resetToSelectedTimer() {
        preparePausedTimer(
            displayedDuration: preparedTimerConfiguration.displayedDuration,
            actualDuration: preparedTimerConfiguration.actualDuration,
            initialProgress: preparedTimerConfiguration.initialProgress
        )
    }

    func savePresetDuration(_ duration: TimeInterval, at index: Int) {
        guard presetDurations.indices.contains(index), duration.isFinite, duration > 0 else { return }
        presetDurations[index] = duration
        persistSortedPresetDurations()
    }

    func addPresetDuration(_ duration: TimeInterval) {
        guard canAddPresetTimer, duration.isFinite, duration > 0 else { return }
        presetDurations.append(duration)
        persistSortedPresetDurations()
    }

    func deletePresetDuration(at index: Int) {
        guard canDeletePresetTimer, presetDurations.indices.contains(index) else { return }
        presetDurations.remove(at: index)
        persistSortedPresetDurations()
    }

    func presetEntryDefaultText(at index: Int) -> String {
        guard presetDurations.indices.contains(index) else { return "" }
        return TimerFormatting.digits(for: presetDurations[index])
    }

    func presetDisplayText(at index: Int) -> String {
        guard presetDurations.indices.contains(index) else { return "" }
        return TimerFormatting.readableDuration(presetDurations[index])
    }

    func preparePresetTimer(at index: Int) {
        guard presetDurations.indices.contains(index) else { return }
        let duration = presetDurations[index]
        preparePausedTimer(
            displayedDuration: duration,
            actualDuration: duration,
            initialProgress: 1
        )
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

    private static func sanitizedPresetDurations(_ storedDurations: [TimeInterval]?) -> [TimeInterval] {
        guard let storedDurations,
              (1...maximumPresetCount).contains(storedDurations.count),
              storedDurations.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            return defaultPresetDurations
        }
        return storedDurations.sorted()
    }

    private func persistSortedPresetDurations() {
        presetDurations.sort()
        defaults.set(presetDurations, forKey: Self.presetDurationsKey)
    }

    private func beginNewRun(at date: Date) {
        engine.start(
            displayedDuration: preparedTimerConfiguration.displayedDuration,
            actualDuration: preparedTimerConfiguration.actualDuration,
            initialProgress: preparedTimerConfiguration.initialProgress,
            at: date
        )
        shouldStartNewRunOnPlay = false
    }

    private func preparePausedTimer(
        displayedDuration: TimeInterval,
        actualDuration: TimeInterval,
        initialProgress: Double
    ) {
        preparedTimerConfiguration = PreparedTimerConfiguration(
            displayedDuration: displayedDuration,
            actualDuration: actualDuration,
            initialProgress: initialProgress
        )
        engine.setPaused(
            displayedDuration: displayedDuration,
            actualDuration: actualDuration,
            initialProgress: initialProgress
        )
        shouldStartNewRunOnPlay = true
        endActualRemainingReveal()
        refresh(at: nowProvider())
        updateCompletionAlert()
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

private struct PreparedTimerConfiguration {
    let displayedDuration: TimeInterval
    let actualDuration: TimeInterval
    let initialProgress: Double
}
