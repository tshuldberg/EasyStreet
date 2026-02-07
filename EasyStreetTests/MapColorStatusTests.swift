import XCTest
@testable import EasyStreet

/// Deterministic tests for mapColorStatus using fixed dates.
/// Reference date: March 2, 2026 (Monday, weekday=2).
/// Using mapColorStatus(today:upcomingDates:) for full control.
class MapColorStatusTests: XCTestCase {

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return Calendar.current.date(from: c)!
    }

    /// Build the upcoming dates array for the parameterized mapColorStatus method.
    private func upcomingDates(from refDate: Date) -> [(offset: Int, date: Date)] {
        let cal = Calendar.current
        return (1...3).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: refDate) else { return nil }
            return (offset: offset, date: d)
        }
    }

    // MARK: - Tests

    /// Monday rule on Monday reference -> red
    func testRedWhenSweepingToday() {
        let monday = makeDate(2026, 3, 2) // Monday = weekday 2
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .red, "Should be red when sweeping is today (Monday)")
    }

    /// Saturday rule on Monday reference -> green (4+ days away)
    func testGreenWhenNoSweepingSoon() {
        let monday = makeDate(2026, 3, 2)
        let rule = SweepingRule(dayOfWeek: 7, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true) // Saturday = weekday 7
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .green, "Should be green when sweeping is Saturday (4+ days away)")
    }

    /// Tuesday rule on Monday reference -> orange (tomorrow)
    func testOrangeWhenSweepingTomorrow() {
        let monday = makeDate(2026, 3, 2)
        let rule = SweepingRule(dayOfWeek: 3, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true) // Tuesday = weekday 3
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .orange, "Should be orange when sweeping is tomorrow (Tuesday)")
    }

    /// Wednesday rule on Monday reference -> yellow (2 days)
    func testYellowWhenSweepingIn2Days() {
        let monday = makeDate(2026, 3, 2)
        let rule = SweepingRule(dayOfWeek: 4, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true) // Wednesday = weekday 4
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .yellow, "Should be yellow when sweeping is in 2 days (Wednesday)")
    }

    /// Thursday rule on Monday reference -> yellow (3 days)
    func testYellowWhenSweepingIn3Days() {
        let monday = makeDate(2026, 3, 2)
        let rule = SweepingRule(dayOfWeek: 5, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true) // Thursday = weekday 5
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .yellow, "Should be yellow when sweeping is in 3 days (Thursday)")
    }

    /// Rules for Monday + Tuesday: red takes precedence over orange
    func testRedPrecedenceOverOrange() {
        let monday = makeDate(2026, 3, 2)
        let ruleToday = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                      weeksOfMonth: [], applyOnHolidays: true)
        let ruleTomorrow = SweepingRule(dayOfWeek: 3, startTime: "09:00", endTime: "11:00",
                                         weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]],
                                     rules: [ruleToday, ruleTomorrow])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .red, "Red (today) should take precedence over orange (tomorrow)")
    }

    /// Rules for Tuesday + Wednesday: orange takes precedence over yellow
    func testOrangePrecedenceOverYellow() {
        let monday = makeDate(2026, 3, 2)
        let ruleTomorrow = SweepingRule(dayOfWeek: 3, startTime: "09:00", endTime: "11:00",
                                         weeksOfMonth: [], applyOnHolidays: true)
        let ruleIn2Days = SweepingRule(dayOfWeek: 4, startTime: "09:00", endTime: "11:00",
                                        weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]],
                                     rules: [ruleTomorrow, ruleIn2Days])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .orange, "Orange (tomorrow) should take precedence over yellow (2 days)")
    }

    /// Rule for week 2 Monday, but reference is week 1 Monday -> green
    func testWeekOfMonthRestriction() {
        let monday = makeDate(2026, 3, 2) // Week 1 Monday
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [2], applyOnHolidays: true) // Only week 2
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .green,
                       "Rule for week 2 should not apply on week 1 Monday, resulting in green")
    }

    // MARK: - Additional Edge Cases

    /// Thursday rule on Monday → yellow (exactly 3 days boundary)
    func testYellowExactly3DayBoundary() {
        let monday = makeDate(2026, 3, 2)
        let rule = SweepingRule(dayOfWeek: 5, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .yellow, "Thursday on Monday is exactly 3 days → yellow")
    }

    /// No rules → green
    func testNoRulesReturnsGreen() {
        let monday = makeDate(2026, 3, 2)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .green, "Segment with no rules should always be green")
    }

    /// Red overrides yellow when both rules exist on segment
    func testRedOverridesYellow() {
        let monday = makeDate(2026, 3, 2)
        let todayRule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                      weeksOfMonth: [], applyOnHolidays: true)
        let in3DaysRule = SweepingRule(dayOfWeek: 5, startTime: "09:00", endTime: "11:00",
                                        weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]],
                                     rules: [in3DaysRule, todayRule]) // yellow rule first in array
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .red, "Red should override yellow regardless of rule array order")
    }

    /// End-of-month: March 31 (Tuesday) → April 1 (Wednesday) transition
    func testEndOfMonthTransition() {
        let march31 = makeDate(2026, 3, 31) // Tuesday weekday=3
        let aprilRule = SweepingRule(dayOfWeek: 4, startTime: "09:00", endTime: "11:00",
                                      weeksOfMonth: [], applyOnHolidays: true) // Wednesday = April 1
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [aprilRule])
        let result = segment.mapColorStatus(today: march31, upcomingDates: upcomingDates(from: march31))
        XCTAssertEqual(result, .orange, "Wednesday on Tuesday March 31 should be orange (crosses month boundary)")
    }
}
