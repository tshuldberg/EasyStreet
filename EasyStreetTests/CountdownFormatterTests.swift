import XCTest
@testable import EasyStreet

class CountdownFormatterTests: XCTestCase {

    // MARK: - Days + Hours format (>= 24h)

    func testDaysAndHoursFormat() {
        // 1 day 3 hours = 97200s
        XCTAssertEqual(CountdownFormatter.format(interval: 97200), "1d 3h remaining")
    }

    func testTwoDaysZeroHours() {
        // 2 days exactly = 172800s
        XCTAssertEqual(CountdownFormatter.format(interval: 172800), "2d 0h remaining")
    }

    func testExactly24Hours() {
        // 86400s = exactly 24 hours → should show days format
        XCTAssertEqual(CountdownFormatter.format(interval: 86400), "1d 0h remaining")
    }

    // MARK: - Hours + Minutes format (1h - 24h)

    func testHoursAndMinutesFormat() {
        // 2 hours 45 minutes = 9900s
        XCTAssertEqual(CountdownFormatter.format(interval: 9900), "2h 45m remaining")
    }

    func testOneHourZeroMinutes() {
        // 1 hour exactly = 3600s
        XCTAssertEqual(CountdownFormatter.format(interval: 3600), "1h 0m remaining")
    }

    func testJustUnder24Hours() {
        // 86399s = 23h 59m 59s
        XCTAssertEqual(CountdownFormatter.format(interval: 86399), "23h 59m remaining")
    }

    // MARK: - Minutes + Seconds format (< 1h)

    func testMinutesAndSecondsFormat() {
        // 45 minutes 30 seconds = 2730s
        XCTAssertEqual(CountdownFormatter.format(interval: 2730), "45m 30s remaining")
    }

    func testZeroMinutes45Seconds() {
        XCTAssertEqual(CountdownFormatter.format(interval: 45), "0m 45s remaining")
    }

    func testJustUnder1Hour() {
        // 3599s = 59m 59s
        XCTAssertEqual(CountdownFormatter.format(interval: 3599), "59m 59s remaining")
    }

    func testOneSecond() {
        XCTAssertEqual(CountdownFormatter.format(interval: 1), "0m 1s remaining")
    }

    // MARK: - Zero and Negative intervals

    func testExactlyZero() {
        XCTAssertEqual(CountdownFormatter.format(interval: 0), "Sweeping in progress")
    }

    func testNegativeWithinSweepDuration() {
        // 10 minutes into a 2-hour sweep: interval = -600, sweepDuration = 7200
        XCTAssertEqual(CountdownFormatter.format(interval: -600, sweepDuration: 7200), "Sweeping in progress")
    }

    func testNegativeAtStartOfSweep() {
        // Just started: interval = -1, sweepDuration = 7200
        XCTAssertEqual(CountdownFormatter.format(interval: -1, sweepDuration: 7200), "Sweeping in progress")
    }

    func testNegativePastSweepDuration() {
        // Sweep ended: interval = -8000, sweepDuration = 7200
        XCTAssertEqual(CountdownFormatter.format(interval: -8000, sweepDuration: 7200), "Sweep completed")
    }

    func testNegativeNoSweepDuration() {
        // Negative with no duration info → completed
        XCTAssertEqual(CountdownFormatter.format(interval: -100), "Sweep completed")
    }

    func testNegativeExactlyAtSweepDurationBoundary() {
        // interval = -7200, sweepDuration = 7200 → abs(interval) == sweepDuration, NOT < sweepDuration → completed
        XCTAssertEqual(CountdownFormatter.format(interval: -7200, sweepDuration: 7200), "Sweep completed")
    }

    // MARK: - Edge cases

    func testVeryLargeInterval() {
        // 30 days = 2592000s
        XCTAssertEqual(CountdownFormatter.format(interval: 2592000), "30d 0h remaining")
    }

    func testFractionalSecondsRoundDown() {
        // 2730.9 seconds → should still show 45m 30s (Int truncation)
        XCTAssertEqual(CountdownFormatter.format(interval: 2730.9), "45m 30s remaining")
    }
}
