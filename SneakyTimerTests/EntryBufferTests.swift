import XCTest
@testable import SneakyTimer

final class EntryBufferTests: XCTestCase {
    @MainActor
    func testDurationEntryFirstDigitReplacesInitialDuration() {
        var buffer = DurationEntryBuffer(initialDigits: "0100")

        buffer.appendDigit("5")

        XCTAssertEqual(buffer.digits, "5")
        XCTAssertEqual(TimerFormatting.duration(from: buffer.digits), 5)
    }

    @MainActor
    func testDurationEntrySubsequentDigitsAppendAfterReplacement() {
        var buffer = DurationEntryBuffer(initialDigits: "0100")

        buffer.appendDigit("5")
        buffer.appendDigit("3")

        XCTAssertEqual(buffer.digits, "53")
        XCTAssertEqual(TimerFormatting.duration(from: buffer.digits), 53)
    }

    @MainActor
    func testDurationEntryAcceptsHoursMinutesSeconds() {
        var buffer = DurationEntryBuffer(initialDigits: "000100")

        for digit in "123456" {
            buffer.appendDigit(String(digit))
        }

        XCTAssertEqual(buffer.digits, "123456")
        XCTAssertEqual(TimerFormatting.duration(from: buffer.digits), 45_296)
        XCTAssertEqual(TimerFormatting.entryDuration(TimerFormatting.duration(from: buffer.digits)), "12 : 34 : 56")
    }

    @MainActor
    func testDurationEntryNormalizesOverflowedMinutes() {
        XCTAssertEqual(TimerFormatting.duration(from: "7500"), 4_500)
        XCTAssertEqual(TimerFormatting.entryDuration(TimerFormatting.duration(from: "7500")), "01 : 15 : 00")
    }

    @MainActor
    func testDurationEntryShowsRawDigitsBeforeSave() {
        var buffer = DurationEntryBuffer(initialDigits: "000100")

        for digit in "7500" {
            buffer.appendDigit(String(digit))
        }

        XCTAssertEqual(buffer.formattedDigits, "00 : 75 : 00")
        XCTAssertEqual(TimerFormatting.entryDuration(TimerFormatting.duration(from: buffer.digits)), "01 : 15 : 00")
    }

    @MainActor
    func testPercentageEntryReplacesInitialValueAndValidatesRange() {
        var buffer = PercentageEntryBuffer(initialDigits: "100")
        XCTAssertEqual(buffer.displayText, "100%")
        XCTAssertEqual(buffer.validPosition, 100)

        buffer.appendDigit("5")
        buffer.appendDigit("0")
        XCTAssertEqual(buffer.displayText, "50%")
        XCTAssertEqual(buffer.validPosition, 50)

        buffer.appendDigit("1")
        XCTAssertNil(buffer.validPosition)
        buffer.removeDigit()
        buffer.removeDigit()
        buffer.removeDigit()
        XCTAssertEqual(buffer.displayText, "0%")
        XCTAssertNil(buffer.validPosition)
    }

    @MainActor
    func testInitialTimerPositionParserRejectsInvalidInput() {
        XCTAssertEqual(TimerFormatting.timerPosition(from: "1"), 1)
        XCTAssertEqual(TimerFormatting.timerPosition(from: "100"), 100)
        XCTAssertNil(TimerFormatting.timerPosition(from: ""))
        XCTAssertNil(TimerFormatting.timerPosition(from: "0"))
        XCTAssertNil(TimerFormatting.timerPosition(from: "101"))
        XCTAssertNil(TimerFormatting.timerPosition(from: "50.5"))
    }

    @MainActor
    func testHomeCountdownUsesMinutesSecondsThroughExactlySixtyMinutes() {
        XCTAssertEqual(TimerFormatting.countdown(3_600), "60 : 00")
        XCTAssertEqual(TimerFormatting.countdown(3_601), "01 : 00 : 01")
    }

    func testDeleteFirstClearsInitialValueForBothEntryBuffers() {
        var duration = DurationEntryBuffer(initialDigits: "000100")
        var percentage = PercentageEntryBuffer(initialDigits: "100")

        duration.removeDigit()
        percentage.removeDigit()

        XCTAssertEqual(duration.digits, "")
        XCTAssertEqual(percentage.digits, "")
    }

    func testEntryBuffersIgnoreNondigitKeypadInput() {
        var duration = DurationEntryBuffer(initialDigits: "")
        var percentage = PercentageEntryBuffer(initialDigits: "")

        duration.appendDigit("x")
        percentage.appendDigit("x")

        XCTAssertEqual(duration.digits, "")
        XCTAssertEqual(percentage.digits, "")
    }
}
