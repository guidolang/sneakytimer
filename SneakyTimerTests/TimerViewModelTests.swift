import XCTest
@testable import SneakyTimer

final class TimerViewModelTests: XCTestCase {
    private let startDate = Date(timeIntervalSinceReferenceDate: 1_000)

    @MainActor
    func testViewModelPersistsLastEnteredDuration() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        viewModel.start(duration: 125)

        let restoredViewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        XCTAssertEqual(restoredViewModel.snapshot.lastEnteredDuration, 125, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testViewModelSavePersistsDurationAndLeavesTimerPaused() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        viewModel.save(duration: 80)

        XCTAssertEqual(viewModel.snapshot.remaining, 80, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.state, .paused)

        let restoredViewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        XCTAssertEqual(restoredViewModel.snapshot.lastEnteredDuration, 80, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testResetToCurrentSettingsAppliesDurationAndPositionAndLeavesTimerPaused() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var now = startDate

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults,
            nowProvider: { now },
            shouldStartTicker: false
        )
        viewModel.save(duration: 600)
        viewModel.saveInitialTimerPosition(40)
        viewModel.toggleRunning()
        now = startDate.addingTimeInterval(60)
        viewModel.tick(at: now)

        viewModel.resetToCurrentSettings()

        XCTAssertEqual(viewModel.snapshot.state, .paused)
        XCTAssertEqual(viewModel.snapshot.remaining, 600, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.stealthRemaining, 600, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.visualProgress, 0.4, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testViewModelDefaultsAdjustmentDurationToThirtySeconds() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )

        XCTAssertEqual(viewModel.adjustmentDuration, 30, accuracy: 0.001)
        XCTAssertEqual(viewModel.adjustmentEntryDefaultText, "000030")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testViewModelDefaultsInitialPositionToOneHundredPercent() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )

        XCTAssertEqual(viewModel.initialTimerPosition, 100)
        XCTAssertEqual(viewModel.initialPositionEntryDefaultText, "100")
        XCTAssertEqual(viewModel.initialPositionDisplayText, "100%")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testViewModelPersistsInitialPosition() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        viewModel.saveInitialTimerPosition(40)

        let restoredViewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        XCTAssertEqual(restoredViewModel.initialTimerPosition, 40)
        XCTAssertEqual(restoredViewModel.initialPositionDisplayText, "40%")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testViewModelFallsBackToOneHundredForInvalidStoredPosition() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(0, forKey: "initialTimerPosition")

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )

        XCTAssertEqual(viewModel.initialTimerPosition, 100)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testSavingInitialPositionDoesNotMutateRunningTimerUntilNextPlay() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var now = startDate

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults,
            nowProvider: { now },
            shouldStartTicker: false
        )
        viewModel.save(duration: 600)
        viewModel.toggleRunning()
        now = startDate.addingTimeInterval(60)
        viewModel.tick(at: now)
        let beforeSave = viewModel.snapshot

        viewModel.saveInitialTimerPosition(50)

        XCTAssertEqual(viewModel.snapshot, beforeSave)
        viewModel.toggleRunning()
        XCTAssertEqual(viewModel.snapshot.state, .paused)
        XCTAssertEqual(viewModel.snapshot.remaining, 540, accuracy: 0.001)

        viewModel.toggleRunning()
        XCTAssertEqual(viewModel.snapshot.state, .running)
        XCTAssertEqual(viewModel.snapshot.remaining, 600, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.stealthRemaining, 600, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.visualProgress, 0.5, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testPauseAndResumeNormallyAfterPendingPositionIsApplied() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var now = startDate

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults,
            nowProvider: { now },
            shouldStartTicker: false
        )
        viewModel.saveInitialTimerPosition(50)
        viewModel.save(duration: 600)
        viewModel.toggleRunning()

        now = startDate.addingTimeInterval(20)
        viewModel.tick(at: now)
        viewModel.toggleRunning()
        XCTAssertEqual(viewModel.snapshot.remaining, 580, accuracy: 0.001)

        now = startDate.addingTimeInterval(70)
        viewModel.toggleRunning()
        now = startDate.addingTimeInterval(80)
        viewModel.tick(at: now)
        XCTAssertEqual(viewModel.snapshot.remaining, 570, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.visualProgress, 0.475, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testSavedDurationCombinesWithInitialPositionOnNextPlay() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults,
            shouldStartTicker: false
        )
        viewModel.saveInitialTimerPosition(25)
        viewModel.save(duration: 800)

        XCTAssertEqual(viewModel.snapshot.state, .paused)
        XCTAssertEqual(viewModel.snapshot.remaining, 800, accuracy: 0.001)
        viewModel.toggleRunning()
        XCTAssertEqual(viewModel.snapshot.remaining, 800, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.stealthRemaining, 800, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.visualProgress, 0.25, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testFiveMinuteTimerAtFiftyPercentStartsWithFiveMinutesRemaining() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults,
            shouldStartTicker: false
        )
        viewModel.saveInitialTimerPosition(50)
        viewModel.save(duration: 5 * 60)
        viewModel.toggleRunning()

        XCTAssertEqual(viewModel.snapshot.remaining, 5 * 60, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.stealthRemaining, 5 * 60, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.visualProgress, 0.5, accuracy: 0.001)
        XCTAssertEqual(viewModel.countdownText, "05 : 00")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testFreshRunAfterCompletionReusesInitialPosition() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var now = startDate

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults,
            nowProvider: { now },
            shouldStartTicker: false
        )
        viewModel.saveInitialTimerPosition(50)
        viewModel.save(duration: 10)
        viewModel.toggleRunning()
        XCTAssertEqual(viewModel.snapshot.remaining, 10, accuracy: 0.001)

        now = startDate.addingTimeInterval(10)
        viewModel.tick(at: now)
        XCTAssertEqual(viewModel.snapshot.state, .completed)

        now = startDate.addingTimeInterval(11)
        viewModel.toggleRunning()
        XCTAssertEqual(viewModel.snapshot.state, .running)
        XCTAssertEqual(viewModel.snapshot.remaining, 10, accuracy: 0.001)
        XCTAssertEqual(viewModel.snapshot.visualProgress, 0.5, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testViewModelDefaultsHideAdjustedTimeToTrue() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )

        XCTAssertTrue(viewModel.hidesAdjustedTime)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testViewModelPersistsHideAdjustedTime() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        viewModel.hidesAdjustedTime = false

        let restoredViewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        XCTAssertFalse(restoredViewModel.hidesAdjustedTime)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testViewModelPersistsAdjustmentDuration() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        XCTAssertEqual(viewModel.adjustmentDisplayText, "30 sec")

        viewModel.saveAdjustmentDuration(45)
        XCTAssertEqual(viewModel.adjustmentDisplayText, "45 sec")

        let restoredViewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        XCTAssertEqual(restoredViewModel.adjustmentDuration, 45, accuracy: 0.001)
        XCTAssertEqual(restoredViewModel.adjustmentEntryDefaultText, "000045")
        XCTAssertEqual(restoredViewModel.adjustmentDisplayText, "45 sec")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testReadableAdjustmentDurationUsesHoursMinutesSeconds() {
        XCTAssertEqual(TimerFormatting.readableDuration(90), "1 min 30 sec")
        XCTAssertEqual(TimerFormatting.readableDuration(3_900), "1 hr 5 min")
        XCTAssertEqual(TimerFormatting.readableDuration(0), "0 sec")
    }

    @MainActor
    func testSavingAdjustmentDoesNotMutateTimerState() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        viewModel.save(duration: 120)
        let beforeSave = viewModel.snapshot

        viewModel.saveAdjustmentDuration(90)

        XCTAssertEqual(viewModel.snapshot, beforeSave)
        XCTAssertEqual(viewModel.adjustmentDisplayText, "1 min 30 sec")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testPlusUsesSavedAdjustmentDuration() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        viewModel.save(duration: 100)
        viewModel.saveAdjustmentDuration(45)
        viewModel.addAdjustmentDuration()

        XCTAssertEqual(viewModel.snapshot.remaining, 145, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testAddingTimePastSixtyMinutesSwitchesCountdownToHours() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        viewModel.save(duration: 3_600)
        XCTAssertEqual(viewModel.countdownText, "60 : 00")

        viewModel.saveAdjustmentDuration(30)
        viewModel.addAdjustmentDuration()

        XCTAssertEqual(viewModel.countdownText, "01 : 00 : 30")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testPlusShowsActualRemainingUntilHoldExpires() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var now = startDate

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults,
            nowProvider: { now },
            shouldStartTicker: false
        )
        viewModel.save(duration: 100)
        viewModel.saveAdjustmentDuration(30)
        viewModel.toggleRunning()

        now = startDate.addingTimeInterval(20)
        viewModel.tick(at: now)
        XCTAssertEqual(viewModel.countdownText, "01 : 20")

        viewModel.addAdjustmentDuration()
        XCTAssertTrue(viewModel.isShowingActualRemaining)
        XCTAssertEqual(viewModel.countdownText, "01 : 50")

        now = now.addingTimeInterval(1.26)
        viewModel.tick(at: now)
        XCTAssertFalse(viewModel.isShowingActualRemaining)
        XCTAssertEqual(viewModel.countdownText, "01 : 20")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testPressingTimeDisplayShowsActualRemainingUntilReleaseHoldExpires() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var now = startDate

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults,
            nowProvider: { now },
            shouldStartTicker: false
        )
        viewModel.save(duration: 100)
        viewModel.saveAdjustmentDuration(30)
        viewModel.toggleRunning()

        now = startDate.addingTimeInterval(20)
        viewModel.tick(at: now)
        viewModel.addAdjustmentDuration()

        now = now.addingTimeInterval(1.26)
        viewModel.tick(at: now)
        XCTAssertFalse(viewModel.isShowingActualRemaining)
        XCTAssertEqual(viewModel.countdownText, "01 : 20")

        viewModel.handleTimeDisplayPress()
        XCTAssertTrue(viewModel.isShowingActualRemaining)
        XCTAssertEqual(viewModel.countdownText, "01 : 49")

        viewModel.handleTimeDisplayRelease()
        now = now.addingTimeInterval(1.0)
        viewModel.tick(at: now)
        XCTAssertTrue(viewModel.isShowingActualRemaining)

        now = now.addingTimeInterval(0.26)
        viewModel.tick(at: now)
        XCTAssertFalse(viewModel.isShowingActualRemaining)
        XCTAssertEqual(viewModel.countdownText, "01 : 19")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testDisablingHideAdjustedTimeAlwaysShowsActualRemainingWithoutReveal() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var now = startDate

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults,
            nowProvider: { now },
            shouldStartTicker: false
        )
        viewModel.save(duration: 100)
        viewModel.saveAdjustmentDuration(30)
        viewModel.toggleRunning()
        viewModel.hidesAdjustedTime = false

        now = startDate.addingTimeInterval(20)
        viewModel.tick(at: now)
        XCTAssertEqual(viewModel.countdownText, "01 : 20")

        viewModel.addAdjustmentDuration()
        XCTAssertFalse(viewModel.isShowingActualRemaining)
        XCTAssertEqual(viewModel.countdownText, "01 : 50")

        viewModel.handleTimeDisplayPress()
        XCTAssertFalse(viewModel.isShowingActualRemaining)
        XCTAssertEqual(viewModel.countdownText, "01 : 50")

        now = now.addingTimeInterval(1)
        viewModel.tick(at: now)
        XCTAssertEqual(viewModel.countdownText, "01 : 49")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testDisablingHideAdjustedTimeClearsPendingReveal() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var now = startDate

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults,
            nowProvider: { now },
            shouldStartTicker: false
        )
        viewModel.save(duration: 100)
        viewModel.saveAdjustmentDuration(30)
        viewModel.toggleRunning()

        now = startDate.addingTimeInterval(20)
        viewModel.tick(at: now)
        viewModel.addAdjustmentDuration()
        XCTAssertTrue(viewModel.isShowingActualRemaining)

        viewModel.hidesAdjustedTime = false
        XCTAssertFalse(viewModel.isShowingActualRemaining)
        XCTAssertEqual(viewModel.countdownText, "01 : 50")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testMinusUsesSavedAdjustmentDuration() {
        let suiteName = "SneakyTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: SilentCompletionNotifier(),
            defaults: defaults
        )
        viewModel.save(duration: 100)
        viewModel.saveAdjustmentDuration(45)
        viewModel.subtractAdjustmentDuration()

        XCTAssertEqual(viewModel.snapshot.remaining, 55, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testRunningTimerSchedulesCompletionAlert() {
        let notifier = RecordingCompletionNotifier()
        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: notifier,
            defaults: UserDefaults(suiteName: "SneakyTimerTests.\(UUID().uuidString)")!
        )

        viewModel.save(duration: 90)
        viewModel.toggleRunning()

        XCTAssertTrue(notifier.didRequestAuthorization)
        XCTAssertEqual(notifier.scheduledSeconds.last ?? 0, 90, accuracy: 0.25)
    }

    @MainActor
    func testInitialPositionSchedulesAlertForFullDuration() {
        let notifier = RecordingCompletionNotifier()
        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: notifier,
            defaults: UserDefaults(suiteName: "SneakyTimerTests.\(UUID().uuidString)")!,
            shouldStartTicker: false
        )

        viewModel.saveInitialTimerPosition(40)
        viewModel.save(duration: 600)
        viewModel.toggleRunning()

        XCTAssertTrue(notifier.didRequestAuthorization)
        XCTAssertEqual(notifier.scheduledSeconds.last ?? 0, 600, accuracy: 0.25)
    }

    @MainActor
    func testPausedTimerCancelsCompletionAlert() {
        let notifier = RecordingCompletionNotifier()
        let viewModel = TimerViewModel(
            alarmService: SilentAlarmService(),
            completionNotifier: notifier,
            defaults: UserDefaults(suiteName: "SneakyTimerTests.\(UUID().uuidString)")!
        )

        viewModel.save(duration: 90)
        viewModel.toggleRunning()
        viewModel.toggleRunning()

        XCTAssertGreaterThanOrEqual(notifier.cancelCount, 1)
    }
}
private struct SilentAlarmService: AlarmService {
    func timerDidComplete() {}
}

private struct SilentCompletionNotifier: TimerCompletionNotifier {
    func requestAuthorization() {}
    func scheduleTimerCompletedAlert(in seconds: TimeInterval) {}
    func cancelTimerCompletedAlert() {}
}

private final class RecordingCompletionNotifier: TimerCompletionNotifier {
    private(set) var didRequestAuthorization = false
    private(set) var scheduledSeconds: [TimeInterval] = []
    private(set) var cancelCount = 0

    func requestAuthorization() {
        didRequestAuthorization = true
    }

    func scheduleTimerCompletedAlert(in seconds: TimeInterval) {
        scheduledSeconds.append(seconds)
    }

    func cancelTimerCompletedAlert() {
        cancelCount += 1
    }
}
