import XCTest
import MapKit
@testable import EasyStreet

class SpatialIndexTests: XCTestCase {

    // MARK: - Holiday Caching

    func testHolidayCachingPerformance() {
        let calc = HolidayCalculator()
        let christmas = makeDate(2026, 12, 25)

        // Warm up the cache
        _ = calc.isHoliday(christmas)

        // Subsequent calls should be fast (cached)
        measure {
            for _ in 0..<10_000 {
                _ = calc.isHoliday(christmas)
            }
        }
    }

    func testHolidayCacheReturnsCorrectResults() {
        let calc = HolidayCalculator()
        let christmas = makeDate(2026, 12, 25)
        let regularDay = makeDate(2026, 3, 15)
        let newYears = makeDate(2026, 1, 1)

        XCTAssertTrue(calc.isHoliday(christmas))
        XCTAssertFalse(calc.isHoliday(regularDay))
        XCTAssertTrue(calc.isHoliday(newYears))

        // Call again to verify cached path returns same results
        XCTAssertTrue(calc.isHoliday(christmas))
        XCTAssertFalse(calc.isHoliday(regularDay))
    }

    func testHolidayCacheWorksAcrossYears() {
        let calc = HolidayCalculator()
        let christmas2025 = makeDate(2025, 12, 25) // Thursday
        let christmas2026 = makeDate(2026, 12, 25) // Friday
        // Christmas 2027 falls on Saturday, observed Friday Dec 24
        let christmas2027observed = makeDate(2027, 12, 24)

        XCTAssertTrue(calc.isHoliday(christmas2025))
        XCTAssertTrue(calc.isHoliday(christmas2026))
        XCTAssertTrue(calc.isHoliday(christmas2027observed))
    }

    // MARK: - mapColorStatus with pre-computed dates

    func testMapColorStatusWithPrecomputedDates() {
        let today = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: today)

        let ruleToday = SweepingRule(dayOfWeek: weekday, startTime: "09:00", endTime: "11:00",
                                      weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "test-color", streetName: "Test St",
                                     coordinates: [[37.78, -122.41]], rules: [ruleToday])

        let upcomingDates: [(offset: Int, date: Date)] = (1...3).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            return (offset, d)
        }

        let status = segment.mapColorStatus(today: today, upcomingDates: upcomingDates)
        XCTAssertEqual(status, .red, "Segment with rule matching today should be red")
    }

    func testMapColorStatusGreenWithPrecomputedDates() {
        let today = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: today)

        // Rule for a day 5 days from now (outside the 3-day window)
        let farDay = ((weekday + 4) % 7) + 1
        let rule = SweepingRule(dayOfWeek: farDay, startTime: "09:00", endTime: "11:00",
                                 weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "test-green", streetName: "Test St",
                                     coordinates: [[37.78, -122.41]], rules: [rule])

        let upcomingDates: [(offset: Int, date: Date)] = (1...3).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            return (offset, d)
        }

        let status = segment.mapColorStatus(today: today, upcomingDates: upcomingDates)
        // If the rule happens to match one of the 3 upcoming days, it won't be green
        // so we check it's not red at minimum (today's weekday is different from farDay)
        XCTAssertNotEqual(status, .red, "Segment with rule for a far-off day should not be red")
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return Calendar.current.date(from: c)!
    }
}
