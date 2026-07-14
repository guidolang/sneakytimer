import XCTest
@testable import SneakyTimer

final class TimerEngineTests: XCTestCase {
    private let startDate = Date(timeIntervalSinceReferenceDate: 1_000)

    func testDifferentDisplayedAndActualDurationsDrainTogetherWithoutVisibleJump() {
        var engine = TimerEngine(defaultDuration: 600)

        engine.start(
            displayedDuration: 600,
            actualDuration: 300,
            at: startDate
        )

        let initial = engine.snapshot(at: startDate)
        XCTAssertEqual(initial.remaining, 300, accuracy: 0.001)
        XCTAssertEqual(initial.stealthRemaining, 600, accuracy: 0.001)
        XCTAssertEqual(initial.visualProgress, 1, accuracy: 0.001)

        let halfway = engine.snapshot(at: startDate.addingTimeInterval(150))
        XCTAssertEqual(halfway.remaining, 150, accuracy: 0.001)
        XCTAssertEqual(halfway.stealthRemaining, 300, accuracy: 0.001)
        XCTAssertEqual(halfway.visualProgress, 0.5, accuracy: 0.001)
    }

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

    func testCancellingDurationEntryPreservesPriorTimer() {
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

    func testStartAtSixtyPercentCountsDownFromFullDuration() {
        var engine = TimerEngine(defaultDuration: 600)

        engine.start(duration: 600, initialProgress: 0.6, at: startDate)

        let startingSnapshot = engine.snapshot(at: startDate)
        XCTAssertEqual(startingSnapshot.remaining, 600, accuracy: 0.001)
        XCTAssertEqual(startingSnapshot.stealthRemaining, 600, accuracy: 0.001)
        XCTAssertEqual(startingSnapshot.visualProgress, 0.6, accuracy: 0.001)

        let halfwaySnapshot = engine.snapshot(at: startDate.addingTimeInterval(300))
        XCTAssertEqual(halfwaySnapshot.remaining, 300, accuracy: 0.001)
        XCTAssertEqual(halfwaySnapshot.stealthRemaining, 300, accuracy: 0.001)
        XCTAssertEqual(halfwaySnapshot.visualProgress, 0.3, accuracy: 0.001)

        XCTAssertTrue(engine.tick(at: startDate.addingTimeInterval(600)))
        let completedSnapshot = engine.snapshot(at: startDate.addingTimeInterval(600))
        XCTAssertEqual(completedSnapshot.remaining, 0, accuracy: 0.001)
        XCTAssertEqual(completedSnapshot.visualProgress, 0, accuracy: 0.001)
        XCTAssertEqual(completedSnapshot.state, .completed)
    }
}
