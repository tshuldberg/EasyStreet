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


    // MARK: - Edge Case Tests (Task 19)

    /// weeksOfMonth with value 0 should never match any real week
    func testWeeksOfMonthWithZero() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [0], applyOnHolidays: true)
        // Test all Mondays in March 2026
        for day in [2, 9, 16, 23, 30] {
            let date = makeDate(2026, 3, day)
            XCTAssertFalse(rule.appliesTo(date: date),
                           "weeksOfMonth [0] should never match (weekOfMonth is 1-based)")
        }
    }

    /// weeksOfMonth with value 5 matches the rare 5th occurrence of a weekday
    func testWeeksOfMonthWithFive() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [5], applyOnHolidays: true)
        let march30 = makeDate(2026, 3, 30) // 5th Monday of March 2026
        let march2 = makeDate(2026, 3, 2)   // 1st Monday
        XCTAssertTrue(rule.appliesTo(date: march30),
                       "weeksOfMonth [5] should match March 30 (5th Monday)")
        XCTAssertFalse(rule.appliesTo(date: march2),
                        "weeksOfMonth [5] should NOT match March 2 (1st Monday)")
    }

    /// weeksOfMonth with value 6 should never match (no month has week 6)
    func testWeeksOfMonthWithSix() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [6], applyOnHolidays: true)
        for day in [2, 9, 16, 23, 30] {
            let date = makeDate(2026, 3, day)
            XCTAssertFalse(rule.appliesTo(date: date),
                           "weeksOfMonth [6] should never match any Monday")
        }
    }

    /// dayOfWeek 0 should not match any real weekday (Sunday=1)
    func testDayOfWeekZero() {
        let rule = SweepingRule(dayOfWeek: 0, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        // Test each day of the week in March 2026 (Mon=2 through Sun=8)
        for day in 2...8 {
            let date = makeDate(2026, 3, day)
            XCTAssertFalse(rule.appliesTo(date: date),
                           "dayOfWeek 0 should not match any real day")
        }
    }

    /// dayOfWeek 8 should not match any real weekday (max is 7=Saturday)
    func testDayOfWeekEight() {
        let rule = SweepingRule(dayOfWeek: 8, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        for day in 2...8 {
            let date = makeDate(2026, 3, day)
            XCTAssertFalse(rule.appliesTo(date: date),
                           "dayOfWeek 8 should not match any real day")
        }
    }

    /// Malformed startTime "25:00" should still produce a formatted time range (fallback)
    func testMalformedStartTime() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "25:00", endTime: "26:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let formatted = rule.formattedTimeRange
        // Should fall back to raw string format since DateFormatter won't parse "25:00"
        XCTAssertTrue(formatted.contains("25:00"),
                       "Malformed time should fall back to raw string, got: \(formatted)")
    }

    /// Empty time strings should produce a formatted time range (fallback)
    func testEmptyTimeStrings() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "", endTime: "",
                                weeksOfMonth: [], applyOnHolidays: false)
        let formatted = rule.formattedTimeRange
        // Should fall back to raw format: " - " (empty strings)
        XCTAssertEqual(formatted, " - ",
                       "Empty time strings should produce fallback format, got: \(formatted)")
    }

    /// nextSweeping with malformed startTime should skip that rule gracefully
    func testNextSweepingMalformedTime() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "bad", endTime: "worse",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "edge-1", streetName: "Edge St",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        let refDate = makeDate(2026, 3, 1) // Sunday
        let (nextDate, _) = segment.nextSweeping(from: refDate)
        // With malformed time, the date setting should fail and the loop continues
        // The behavior depends on Int parsing of "bad" -> 0, so it may still produce a date
        // This test documents the current behavior
        if let d = nextDate {
            let weekday = Calendar.current.component(.weekday, from: d)
            XCTAssertEqual(weekday, 2, "If a date is returned, it should still be a Monday")
        }
        // No crash is the key assertion - reaching this point means no crash
    }

    /// nextSweeping with empty rules should return (nil, nil)
    func testNextSweepingNoRules() {
        let segment = StreetSegment(id: "edge-2", streetName: "Edge St",
                                     coordinates: [[37.78, -122.41]], rules: [])
        let (nextDate, nextRule) = segment.nextSweeping()
        XCTAssertNil(nextDate, "Segment with no rules should return nil date")
        XCTAssertNil(nextRule, "Segment with no rules should return nil rule")
    }

    /// weeksDescription with week value 5 should produce "5th"
    func testWeeksDescriptionWeekFive() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [5], applyOnHolidays: false)
        XCTAssertTrue(rule.weeksDescription.contains("5th"),
                       "Week 5 should produce '5th' in description, got: \(rule.weeksDescription)")
    }

    /// weeksDescription with week value 6 (out of range) should not crash after Task 13-F2b fix
    func testWeeksDescriptionWeekSix() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [6], applyOnHolidays: false)
        // After the guard fix, this should not crash - the invalid week is filtered out
        let desc = rule.weeksDescription
        XCTAssertFalse(desc.isEmpty,
                        "Description should not be empty (still has suffix), got: \(desc)")
        // Value 6 is filtered out by compactMap, so only the suffix remains
        XCTAssertTrue(desc.contains("weeks of the month") || desc.contains("week"),
                       "Should still have suffix text, got: \(desc)")
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
