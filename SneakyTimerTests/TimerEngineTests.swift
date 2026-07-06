import XCTest
@testable import SneakyTimer

final class TimerEngineTests: XCTestCase {
    private let startDate = Date(timeIntervalSinceReferenceDate: 1_000)

    func testStartCountsDownFromSelectedDuration() {
        var engine = TimerEngine(defaultDuration: 60)

        engine.start(duration: 120, at: startDate)

        let snapshot = engine.snapshot(at: startDate.addingTimeInterval(15))
        XCTAssertEqual(snapshot.remaining, 105, accuracy: 0.001)
        XCTAssertEqual(snapshot.visualProgress, 0.875, accuracy: 0.001)
        XCTAssertEqual(snapshot.state, .running)
    }

    func testPauseAndResumeFreezeThenContinue() {
        var engine = TimerEngine(defaultDuration: 60)
        engine.start(duration: 60, at: startDate)

        engine.pause(at: startDate.addingTimeInterval(10))
        let paused = engine.snapshot(at: startDate.addingTimeInterval(30))
        XCTAssertEqual(paused.remaining, 50, accuracy: 0.001)

        engine.resume(at: startDate.addingTimeInterval(40))
        let resumed = engine.snapshot(at: startDate.addingTimeInterval(45))
        XCTAssertEqual(resumed.remaining, 45, accuracy: 0.001)
    }

    func testPlusAddsThirtySecondsWithoutJumpingVisualProgress() {
        var engine = TimerEngine(defaultDuration: 60)
        engine.start(duration: 60, at: startDate)

        let before = engine.snapshot(at: startDate.addingTimeInterval(20))
        _ = engine.adjustRemaining(by: 30, at: startDate.addingTimeInterval(20))
        let after = engine.snapshot(at: startDate.addingTimeInterval(20))

        XCTAssertEqual(before.visualProgress, after.visualProgress, accuracy: 0.001)
        XCTAssertEqual(after.remaining, 70, accuracy: 0.001)
    }

    func testMinusSubtractsThirtySecondsWithoutJumpingVisualProgress() {
        var engine = TimerEngine(defaultDuration: 60)
        engine.start(duration: 90, at: startDate)

        let before = engine.snapshot(at: startDate.addingTimeInterval(20))
        _ = engine.adjustRemaining(by: -30, at: startDate.addingTimeInterval(20))
        let after = engine.snapshot(at: startDate.addingTimeInterval(20))

        XCTAssertEqual(before.visualProgress, after.visualProgress, accuracy: 0.001)
        XCTAssertEqual(after.remaining, 40, accuracy: 0.001)
    }

    func testMinusFloorsAtZero() {
        var engine = TimerEngine(defaultDuration: 60)
        engine.start(duration: 20, at: startDate)

        _ = engine.adjustRemaining(by: -30, at: startDate.addingTimeInterval(5))

        let snapshot = engine.snapshot(at: startDate.addingTimeInterval(5))
        XCTAssertEqual(snapshot.remaining, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.visualProgress, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.state, .completed)
    }

    func testVisualProgressRateChangesAfterAdjustment() {
        var engine = TimerEngine(defaultDuration: 60)
        engine.start(duration: 60, at: startDate)

        _ = engine.adjustRemaining(by: 30, at: startDate.addingTimeInterval(30))

        let snapshot = engine.snapshot(at: startDate.addingTimeInterval(60))
        XCTAssertEqual(snapshot.remaining, 30, accuracy: 0.001)
        XCTAssertEqual(snapshot.visualProgress, 0.25, accuracy: 0.001)
    }

    func testStealthRemainingDoesNotJumpAfterAdjustment() {
        var engine = TimerEngine(defaultDuration: 60)
        engine.start(duration: 60, at: startDate)

        let adjustmentDate = startDate.addingTimeInterval(20)
        let before = engine.snapshot(at: adjustmentDate)
        _ = engine.adjustRemaining(by: 30, at: adjustmentDate)
        let after = engine.snapshot(at: adjustmentDate)

        XCTAssertEqual(before.stealthRemaining, after.stealthRemaining, accuracy: 0.001)
        XCTAssertEqual(after.remaining, 70, accuracy: 0.001)
        XCTAssertEqual(after.stealthRemaining, 40, accuracy: 0.001)
    }

    func testStealthRemainingReachesZeroWithActualRemainingAfterAdjustment() {
        var engine = TimerEngine(defaultDuration: 60)
        engine.start(duration: 60, at: startDate)

        _ = engine.adjustRemaining(by: 30, at: startDate.addingTimeInterval(30))

        let snapshot = engine.snapshot(at: startDate.addingTimeInterval(90))
        XCTAssertEqual(snapshot.remaining, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.stealthRemaining, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.visualProgress, 0, accuracy: 0.001)
    }

    func testCompletionFiresOnlyOnce() {
        var engine = TimerEngine(defaultDuration: 60)
        engine.start(duration: 10, at: startDate)

        XCTAssertTrue(engine.tick(at: startDate.addingTimeInterval(10)))
        XCTAssertFalse(engine.tick(at: startDate.addingTimeInterval(11)))
        XCTAssertEqual(engine.snapshot(at: startDate.addingTimeInterval(11)).state, .completed)
    }

    func testCancelResetCanPreservePriorTimerByNotMutatingEngine() {
        var engine = TimerEngine(defaultDuration: 60)
        engine.start(duration: 90, at: startDate)

        let before = engine.snapshot(at: startDate.addingTimeInterval(10))
        let after = engine.snapshot(at: startDate.addingTimeInterval(10))

        XCTAssertEqual(before, after)
    }

    func testStartAppliesEnteredDurationAndStoresDefault() {
        var engine = TimerEngine(defaultDuration: 60)

        engine.start(duration: 75, at: startDate)

        let snapshot = engine.snapshot(at: startDate)
        XCTAssertEqual(snapshot.remaining, 75, accuracy: 0.001)
        XCTAssertEqual(snapshot.lastEnteredDuration, 75, accuracy: 0.001)
    }

    func testSetPausedAppliesEnteredDurationWithoutStartingTimer() {
        var engine = TimerEngine(defaultDuration: 60)
        engine.start(duration: 90, at: startDate)

        engine.setPaused(duration: 45)

        let snapshot = engine.snapshot(at: startDate.addingTimeInterval(30))
        XCTAssertEqual(snapshot.remaining, 45, accuracy: 0.001)
        XCTAssertEqual(snapshot.visualProgress, 1, accuracy: 0.001)
        XCTAssertEqual(snapshot.lastEnteredDuration, 45, accuracy: 0.001)
        XCTAssertEqual(snapshot.state, .paused)
    }

    @MainActor
    func testDurationEntryFirstDigitReplacesInitialDuration() {
        var buffer = DurationEntryBuffer(initialDigits: "0100")

        buffer.appendDigit("5")

        XCTAssertEqual(buffer.digits, "5")
        XCTAssertEqual(TimerViewModel.duration(from: buffer.digits), 5)
    }

    @MainActor
    func testDurationEntrySubsequentDigitsAppendAfterReplacement() {
        var buffer = DurationEntryBuffer(initialDigits: "0100")

        buffer.appendDigit("5")
        buffer.appendDigit("3")

        XCTAssertEqual(buffer.digits, "53")
        XCTAssertEqual(TimerViewModel.duration(from: buffer.digits), 53)
    }

    @MainActor
    func testDurationEntryAcceptsHoursMinutesSeconds() {
        var buffer = DurationEntryBuffer(initialDigits: "000100")

        for digit in "123456" {
            buffer.appendDigit(String(digit))
        }

        XCTAssertEqual(buffer.digits, "123456")
        XCTAssertEqual(TimerViewModel.duration(from: buffer.digits), 45_296)
        XCTAssertEqual(TimerViewModel.formatEntryDuration(TimerViewModel.duration(from: buffer.digits)), "12 : 34 : 56")
    }

    @MainActor
    func testDurationEntryNormalizesOverflowedMinutes() {
        XCTAssertEqual(TimerViewModel.duration(from: "7500"), 4_500)
        XCTAssertEqual(TimerViewModel.formatEntryDuration(TimerViewModel.duration(from: "7500")), "01 : 15 : 00")
    }

    @MainActor
    func testDurationEntryShowsRawDigitsBeforeSave() {
        var buffer = DurationEntryBuffer(initialDigits: "000100")

        for digit in "7500" {
            buffer.appendDigit(String(digit))
        }

        XCTAssertEqual(buffer.formattedDigits, "00 : 75 : 00")
        XCTAssertEqual(TimerViewModel.formatEntryDuration(TimerViewModel.duration(from: buffer.digits)), "01 : 15 : 00")
    }

    @MainActor
    func testHomeCountdownUsesMinutesSecondsThroughExactlySixtyMinutes() {
        XCTAssertEqual(TimerViewModel.formatDuration(3_600), "60 : 00")
        XCTAssertEqual(TimerViewModel.formatDuration(3_601), "01 : 00 : 01")
    }

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
        XCTAssertEqual(TimerViewModel.formatReadableDuration(90), "1 min 30 sec")
        XCTAssertEqual(TimerViewModel.formatReadableDuration(3_900), "1 hr 5 min")
        XCTAssertEqual(TimerViewModel.formatReadableDuration(0), "0 sec")
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
