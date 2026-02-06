import XCTest
@testable import EasyStreet

class HolidayCalculatorTests: XCTestCase {

    let calculator = HolidayCalculator()

    // MARK: - Fixed Holidays

    func testNewYearsDay() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 1, 1)))
        XCTAssertTrue(calculator.isHoliday(date(2027, 1, 1)))
    }

    func testJuneteenth() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 6, 19)))
    }

    func testIndependenceDay() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 7, 4)))
    }

    func testVeteransDay() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 11, 11)))
    }

    func testChristmas() {
        XCTAssertTrue(calculator.isHoliday(date(2026, 12, 25)))
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

    // MARK: - Non-Holidays

    func testRegularDayIsNotHoliday() {
        XCTAssertFalse(calculator.isHoliday(date(2026, 3, 15)))
        XCTAssertFalse(calculator.isHoliday(date(2026, 8, 20)))
    }

    func testGetHolidaysReturns11() {
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
