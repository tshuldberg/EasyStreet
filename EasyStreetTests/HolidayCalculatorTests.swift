import XCTest
@testable import EasyStreet

class HolidayCalculatorTests: XCTestCase {

    let calculator = HolidayCalculator()

    // MARK: - Fixed Holidays (with observed-date logic)

    func testNewYearsDay() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 1, 1)))
        XCTAssertTrue(calculator.isHoliday(date(2027, 1, 1)))
    }

    func testJuneteenthIsNotHoliday() {
        // SFMTA enforces sweeping on Juneteenth -- it should NOT be in the holiday list
        XCTAssertFalse(calculator.isHoliday(date(2026, 6, 19)))
        XCTAssertFalse(calculator.isHoliday(date(2025, 6, 19)))
    }

    func testIndependenceDay() {
        // July 4, 2026 is Saturday -> observed Friday July 3
        XCTAssertTrue(calculator.isHoliday(date(2026, 7, 3)),
                      "July 4, 2026 is Saturday, observed date should be Friday July 3")
        XCTAssertFalse(calculator.isHoliday(date(2026, 7, 4)),
                       "July 4, 2026 (Saturday) should NOT be in the holiday list; the observed Friday is")
    }

    func testIndependenceDayOnSaturdayObservedFriday() {
        // July 4, 2026 is Saturday -> observed Friday July 3
        XCTAssertTrue(calculator.isHoliday(date(2026, 7, 3)))
    }

    func testVeteransDay() {
        // Nov 11, 2026 is Wednesday -> observed on the day itself
        XCTAssertTrue(calculator.isHoliday(date(2026, 11, 11)))
    }

    func testVeteransDayOnSaturdayObservedFriday() {
        // Nov 11, 2028 is Saturday -> observed Friday Nov 10
        XCTAssertTrue(calculator.isHoliday(date(2028, 11, 10)),
                      "Veterans Day 2028 (Saturday) should be observed Friday Nov 10")
    }

    func testChristmas() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 12, 25)))
    }

    func testChristmasOnSundayObservedMonday() {
        // Dec 25, 2022 is Sunday -> observed Monday Dec 26
        XCTAssertTrue(calculator.isHoliday(date(2022, 12, 26)),
                      "Christmas 2022 (Sunday) should be observed Monday Dec 26")
    }

    func testChristmas2027OnSaturdayObservedFriday() {
        // Dec 25, 2027 is Saturday -> observed Friday Dec 24
        XCTAssertTrue(calculator.isHoliday(date(2027, 12, 24)),
                      "Christmas 2027 (Saturday) should be observed Friday Dec 24")
    }

    // MARK: - Floating Holidays

    func testMLKDay2026() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 1, 19)))
        XCTAssertFalse(calculator.isHoliday(date(2026, 1, 12)))
    }

    func testPresidentsDay2026() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 2, 16)))
    }

    func testMemorialDay2026() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 5, 25)))
    }

    func testLaborDay2026() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 9, 7)))
    }

    func testIndigenousPeoplesDay2026() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 10, 12)))
    }

    func testThanksgiving2026() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 11, 26)))
        XCTAssertFalse(calculator.isHoliday(date(2026, 11, 19)))
    }

    func testThanksgiving2025() {
        XCTAssertTrue(calculator.isHoliday(date(2025, 11, 27)))
    }

    // MARK: - Day After Thanksgiving

    func testDayAfterThanksgiving2026() {
        // Thanksgiving 2026 is Nov 26 (Thu), day after is Nov 27 (Fri)
        XCTAssertTrue(calculator.isHoliday(date(2026, 11, 27)),
                      "Day after Thanksgiving 2026 should be a holiday")
    }

    func testDayAfterThanksgiving2025() {
        // Thanksgiving 2025 is Nov 27 (Thu), day after is Nov 28 (Fri)
        XCTAssertTrue(calculator.isHoliday(date(2025, 11, 28)),
                      "Day after Thanksgiving 2025 should be a holiday")
    }

    // MARK: - Cross-Year Boundary

    func testCrossYearBoundary2028() {
        // New Year's 2028 falls on Saturday -> observed Dec 31, 2027
        XCTAssertTrue(calculator.isHoliday(date(2027, 12, 31)),
                      "New Year's 2028 (Saturday) should be observed Dec 31, 2027")
    }

    // MARK: - Non-Holidays

    func testRegularDayIsNotHoliday() {
        XCTAssertFalse(calculator.isHoliday(date(2026, 3, 15)))
        XCTAssertFalse(calculator.isHoliday(date(2026, 8, 20)))
    }

    func testGetHolidaysReturns11() {
        // 4 fixed + 6 floating + 1 day-after-Thanksgiving = 11
        let holidays = calculator.holidays(for: 2026)
        XCTAssertEqual(holidays.count, 11)
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
}
