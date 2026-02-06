import XCTest
@testable import EasyStreet

class SweepingRuleEngineTests: XCTestCase {

    // MARK: - SweepingRule.appliesTo Tests

    /// Rule with dayOfWeek=2 (Monday) should apply on a Monday
    func testRuleAppliesToCorrectDay() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        // March 2, 2026 is Monday (weekday 2)
        let monday = makeDate(2026, 3, 2)
        XCTAssertTrue(rule.appliesTo(date: monday),
                       "Rule for Monday should apply on March 2, 2026 (Monday)")
    }

    /// Rule with dayOfWeek=2 (Monday) should NOT apply on a Tuesday
    func testRuleDoesNotApplyToWrongDay() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        // March 3, 2026 is Tuesday (weekday 3)
        let tuesday = makeDate(2026, 3, 3)
        XCTAssertFalse(rule.appliesTo(date: tuesday),
                        "Rule for Monday should NOT apply on March 3, 2026 (Tuesday)")
    }

    /// Rule restricted to weeks [1, 3] should only apply on those weeks
    /// Using March 2026 where March 1 = Sunday, giving clean week alignment:
    ///   Mar 2 (Mon) = weekOfMonth 1
    ///   Mar 9 (Mon) = weekOfMonth 2
    ///   Mar 16 (Mon) = weekOfMonth 3
    ///   Mar 23 (Mon) = weekOfMonth 4
    func testRuleRespectsWeekOfMonth() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [1, 3], applyOnHolidays: false)
        let firstMonday = makeDate(2026, 3, 2)   // weekOfMonth = 1
        let secondMonday = makeDate(2026, 3, 9)  // weekOfMonth = 2
        let thirdMonday = makeDate(2026, 3, 16)  // weekOfMonth = 3
        let fourthMonday = makeDate(2026, 3, 23)  // weekOfMonth = 4
        XCTAssertTrue(rule.appliesTo(date: firstMonday),
                       "Rule for weeks [1,3] should apply on weekOfMonth 1 (Mar 2)")
        XCTAssertFalse(rule.appliesTo(date: secondMonday),
                        "Rule for weeks [1,3] should NOT apply on weekOfMonth 2 (Mar 9)")
        XCTAssertTrue(rule.appliesTo(date: thirdMonday),
                       "Rule for weeks [1,3] should apply on weekOfMonth 3 (Mar 16)")
        XCTAssertFalse(rule.appliesTo(date: fourthMonday),
                        "Rule for weeks [1,3] should NOT apply on weekOfMonth 4 (Mar 23)")
    }

    /// Rule with empty weeksOfMonth should apply every week
    func testEmptyWeeksOfMonthAppliesToAllWeeks() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        // All four Mondays in March 2026 should match
        for day in [2, 9, 16, 23] {
            let date = makeDate(2026, 3, day)
            XCTAssertTrue(rule.appliesTo(date: date),
                           "Rule with empty weeksOfMonth should apply on March \(day)")
        }
    }

    /// Rule with applyOnHolidays=false should NOT apply on a holiday
    /// Christmas 2025 = Thursday (weekday 5)
    func testRuleSuspendedOnHoliday() {
        let rule = SweepingRule(dayOfWeek: 5, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let christmas = makeDate(2025, 12, 25) // Thursday = weekday 5
        XCTAssertFalse(rule.appliesTo(date: christmas),
                        "Rule with applyOnHolidays=false should NOT apply on Christmas")
    }

    /// Rule with applyOnHolidays=true should still apply on a holiday
    func testRuleAppliesOnHolidayWhenFlagged() {
        let rule = SweepingRule(dayOfWeek: 5, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let christmas = makeDate(2025, 12, 25) // Thursday = weekday 5
        XCTAssertTrue(rule.appliesTo(date: christmas),
                       "Rule with applyOnHolidays=true should apply even on Christmas")
    }

    /// Rule for a non-holiday weekday with applyOnHolidays=false should still apply
    func testRuleAppliesOnNonHolidayWithFlagFalse() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        // March 2, 2026 is Monday and NOT a holiday
        let monday = makeDate(2026, 3, 2)
        XCTAssertTrue(rule.appliesTo(date: monday),
                       "Rule with applyOnHolidays=false should apply on non-holiday Monday")
    }

    // MARK: - StreetSegment.hasSweeperToday Tests

    /// A segment with a rule matching today should report sweeping today
    func testHasSweeperTodayWhenRuleApplies() {
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        let rule = SweepingRule(dayOfWeek: weekday, startTime: "23:00", endTime: "23:59",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "test-1", streetName: "Test St",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        XCTAssertTrue(segment.hasSweeperToday(),
                       "Segment with rule matching today's weekday should have sweeper today")
    }

    /// A segment with no matching rule should report no sweeping today
    func testHasSweeperTodayWhenNoRuleApplies() {
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        // Pick a different weekday that is NOT today
        let otherDay = (weekday % 7) + 1
        let rule = SweepingRule(dayOfWeek: otherDay, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let segment = StreetSegment(id: "test-2", streetName: "Test St",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        XCTAssertFalse(segment.hasSweeperToday(),
                        "Segment with rule for a different day should NOT have sweeper today")
    }

    // MARK: - StreetSegment.nextSweeping Tests

    /// nextSweeping should find an upcoming date matching the rule's day of week
    func testNextSweepingFindsUpcomingDate() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let segment = StreetSegment(id: "test-3", streetName: "Test St",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        let (nextDate, nextRule) = segment.nextSweeping()
        XCTAssertNotNil(nextDate, "nextSweeping should return a non-nil date for an every-week rule")
        XCTAssertNotNil(nextRule, "nextSweeping should return the associated rule")
        if let d = nextDate {
            let weekday = Calendar.current.component(.weekday, from: d)
            XCTAssertEqual(weekday, 2,
                           "Next sweeping date should fall on Monday (weekday=2)")
            XCTAssertTrue(d > Date(),
                           "Next sweeping date should be in the future")
        }
    }

    /// nextSweeping should return the nearest rule when multiple rules exist
    func testNextSweepingPicksEarliestAcrossMultipleRules() {
        let today = Date()
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: today)

        // Create two rules for different days
        let dayA = (todayWeekday % 7) + 1      // tomorrow-ish
        let dayB = ((todayWeekday + 2) % 7) + 1 // 3 days out

        let ruleA = SweepingRule(dayOfWeek: dayA, startTime: "09:00", endTime: "11:00",
                                  weeksOfMonth: [], applyOnHolidays: true)
        let ruleB = SweepingRule(dayOfWeek: dayB, startTime: "09:00", endTime: "11:00",
                                  weeksOfMonth: [], applyOnHolidays: true)

        let segment = StreetSegment(id: "test-4", streetName: "Test St",
                                     coordinates: [[37.78, -122.41]], rules: [ruleB, ruleA])
        let (nextDate, nextRule) = segment.nextSweeping()
        XCTAssertNotNil(nextDate, "nextSweeping should find a date with two rules")
        XCTAssertNotNil(nextRule, "nextSweeping should return the closest rule")
        if let rule = nextRule {
            XCTAssertEqual(rule.dayOfWeek, dayA,
                           "The nearest rule should be the one closest to tomorrow")
        }
    }

    /// nextSweeping with a referenceDate parameter should search from that date
    func testNextSweepingFromReferenceDate() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "10:00", endTime: "12:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let segment = StreetSegment(id: "test-5", streetName: "Test St",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        // Use March 1, 2026 (Sunday) as reference -- next Monday is March 2
        let refDate = makeDate(2026, 3, 1)
        let (nextDate, _) = segment.nextSweeping(from: refDate)
        XCTAssertNotNil(nextDate, "Should find next sweeping from reference date")
        if let d = nextDate {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: d)
            XCTAssertEqual(components.year, 2026)
            XCTAssertEqual(components.month, 3)
            XCTAssertEqual(components.day, 2,
                           "Next Monday after March 1 should be March 2, 2026")
        }
    }

    // MARK: - SweepingRule Computed Properties

    func testDayName() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        XCTAssertEqual(rule.dayName, "Monday")

        let satRule = SweepingRule(dayOfWeek: 7, startTime: "09:00", endTime: "11:00",
                                    weeksOfMonth: [], applyOnHolidays: false)
        XCTAssertEqual(satRule.dayName, "Saturday")

        let sunRule = SweepingRule(dayOfWeek: 1, startTime: "09:00", endTime: "11:00",
                                    weeksOfMonth: [], applyOnHolidays: false)
        XCTAssertEqual(sunRule.dayName, "Sunday")
    }

    func testWeeksDescription() {
        let everyWeek = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                      weeksOfMonth: [], applyOnHolidays: false)
        XCTAssertEqual(everyWeek.weeksDescription, "Every week")

        let firstAndThird = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                          weeksOfMonth: [1, 3], applyOnHolidays: false)
        XCTAssertEqual(firstAndThird.weeksDescription, "1st & 3rd weeks of the month")
    }

    func testFormattedTimeRange() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let formatted = rule.formattedTimeRange
        // Should contain AM/PM format
        XCTAssertTrue(formatted.contains("AM") || formatted.contains("am") ||
                       formatted.contains("PM") || formatted.contains("pm"),
                       "Formatted time range should contain AM/PM indicator, got: \(formatted)")
    }

    // MARK: - SweepingRuleEngine.isHoliday

    func testEngineIsHolidayDelegatesToCalculator() {
        let engine = SweepingRuleEngine.shared
        let christmas = makeDate(2026, 12, 25)
        let regularDay = makeDate(2026, 3, 15)
        XCTAssertTrue(engine.isHoliday(christmas),
                       "Engine should identify Christmas as a holiday")
        XCTAssertFalse(engine.isHoliday(regularDay),
                        "Engine should identify March 15 as a non-holiday")
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
