import XCTest
@testable import EasyStreet

class ColorCodingAccuracyTests: XCTestCase {

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    private func upcomingDates(from refDate: Date) -> [(offset: Int, date: Date)] {
        let cal = Calendar.current
        return (1...3).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: refDate) else { return nil }
            return (offset: offset, date: d)
        }
    }

    private func makeSegment(rules: [SweepingRule]) -> StreetSegment {
        StreetSegment(id: "cc-test", streetName: "Color St",
                     coordinates: [[37.78, -122.41]], rules: rules)
    }

    // MARK: - Day-of-week boundaries

    /// Saturday ref, Sunday rule → orange (tomorrow)
    func testSaturdayToSundayTransition() {
        let saturday = makeDate(2026, 3, 28) // Saturday weekday=7
        let sundayRule = SweepingRule(dayOfWeek: 1, startTime: "09:00", endTime: "11:00",
                                      weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [sundayRule])
        let result = segment.mapColorStatus(today: saturday, upcomingDates: upcomingDates(from: saturday))
        XCTAssertEqual(result, .orange, "Sunday rule should be orange on Saturday (tomorrow)")
    }

    /// Friday ref, Monday rule → yellow (3 days)
    func testFridayToMondayYellow() {
        let friday = makeDate(2026, 3, 27) // Friday weekday=6
        let mondayRule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                      weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [mondayRule])
        let result = segment.mapColorStatus(today: friday, upcomingDates: upcomingDates(from: friday))
        XCTAssertEqual(result, .yellow, "Monday rule should be yellow on Friday (3 days)")
    }

    /// Sunday ref, Thursday rule → green (4 days away, out of 3-day window)
    func testSundayToThursdayGreen() {
        let sunday = makeDate(2026, 3, 29) // Sunday weekday=1
        let thursdayRule = SweepingRule(dayOfWeek: 5, startTime: "09:00", endTime: "11:00",
                                         weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [thursdayRule])
        let result = segment.mapColorStatus(today: sunday, upcomingDates: upcomingDates(from: sunday))
        XCTAssertEqual(result, .green, "Thursday rule on Sunday should be green (4 days away)")
    }

    /// Sunday ref, Tuesday rule → yellow (2 days)
    func testSundayToTuesdayYellow() {
        let sunday = makeDate(2026, 3, 29) // Sunday weekday=1
        let tuesdayRule = SweepingRule(dayOfWeek: 3, startTime: "09:00", endTime: "11:00",
                                       weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [tuesdayRule])
        let result = segment.mapColorStatus(today: sunday, upcomingDates: upcomingDates(from: sunday))
        XCTAssertEqual(result, .yellow, "Tuesday rule on Sunday should be yellow (2 days)")
    }

    // MARK: - Week-of-month boundaries

    /// 4th Monday with weeksOfMonth:[4] should be red; 5th Monday should NOT apply
    func testWeek4MondayRedWeek5Green() {
        // March 23, 2026 = 4th Monday, March 30, 2026 = 5th Monday
        let week4Monday = makeDate(2026, 3, 23)
        let week5Monday = makeDate(2026, 3, 30)
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [4], applyOnHolidays: true)
        let segment = makeSegment(rules: [rule])

        let result4 = segment.mapColorStatus(today: week4Monday, upcomingDates: upcomingDates(from: week4Monday))
        XCTAssertEqual(result4, .red, "4th Monday should be red with weeksOfMonth:[4]")

        let result5 = segment.mapColorStatus(today: week5Monday, upcomingDates: upcomingDates(from: week5Monday))
        XCTAssertEqual(result5, .green, "5th Monday should be green (week 5 not in [4])")
    }

    /// Alternating weeks [1,3]: 1st Monday red, 2nd Monday green
    func testAlternatingWeeks() {
        // March 2, 2026 = 1st Monday, March 9, 2026 = 2nd Monday
        let week1Monday = makeDate(2026, 3, 2)
        let week2Monday = makeDate(2026, 3, 9)
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [1, 3], applyOnHolidays: true)
        let segment = makeSegment(rules: [rule])

        let result1 = segment.mapColorStatus(today: week1Monday, upcomingDates: upcomingDates(from: week1Monday))
        XCTAssertEqual(result1, .red, "1st Monday should be red with alternating weeks [1,3]")

        let result2 = segment.mapColorStatus(today: week2Monday, upcomingDates: upcomingDates(from: week2Monday))
        XCTAssertEqual(result2, .green, "2nd Monday should be green (week 2 not in [1,3])")
    }

    // MARK: - Holiday handling

    /// Christmas 2026 (Friday) with applyOnHolidays:false → green
    func testChristmasSkippedWhenNotApplyOnHolidays() {
        let christmas = makeDate(2026, 12, 25) // Friday weekday=6
        let rule = SweepingRule(dayOfWeek: 6, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: false)
        let segment = makeSegment(rules: [rule])
        let result = segment.mapColorStatus(today: christmas, upcomingDates: upcomingDates(from: christmas))
        XCTAssertEqual(result, .green, "Christmas Friday with applyOnHolidays:false should be green")
    }

    /// Christmas 2026 (Friday) with applyOnHolidays:true → red
    func testChristmasEnforcedWhenApplyOnHolidays() {
        let christmas = makeDate(2026, 12, 25) // Friday weekday=6
        let rule = SweepingRule(dayOfWeek: 6, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [rule])
        let result = segment.mapColorStatus(today: christmas, upcomingDates: upcomingDates(from: christmas))
        XCTAssertEqual(result, .red, "Christmas Friday with applyOnHolidays:true should be red")
    }

    /// Day before Christmas: Thursday rule for Friday (Christmas) with applyOnHolidays:false → NOT orange
    func testDayBeforeHolidayNotOrange() {
        let thursday = makeDate(2026, 12, 24) // Thursday before Christmas
        let fridayRule = SweepingRule(dayOfWeek: 6, startTime: "09:00", endTime: "11:00",
                                      weeksOfMonth: [], applyOnHolidays: false)
        let segment = makeSegment(rules: [fridayRule])
        let result = segment.mapColorStatus(today: thursday, upcomingDates: upcomingDates(from: thursday))
        XCTAssertEqual(result, .green, "Friday rule on Thursday before Christmas (applyOnHolidays:false) should be green, not orange")
    }

    // MARK: - Multiple rules precedence

    /// Today rule + future rule → red wins
    func testTodayRuleOverridesFutureRule() {
        let monday = makeDate(2026, 3, 2)
        let todayRule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                     weeksOfMonth: [], applyOnHolidays: true)
        let thursdayRule = SweepingRule(dayOfWeek: 5, startTime: "09:00", endTime: "11:00",
                                        weeksOfMonth: [], applyOnHolidays: true)
        // Put future rule first in array to test precedence
        let segment = makeSegment(rules: [thursdayRule, todayRule])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .red, "Today rule should take precedence (red) regardless of array order")
    }

    /// Tomorrow rule + 3-day rule → orange wins regardless of array order
    func testTomorrowRuleOverrides3DayRule() {
        let monday = makeDate(2026, 3, 2)
        let thursdayRule = SweepingRule(dayOfWeek: 5, startTime: "09:00", endTime: "11:00",
                                        weeksOfMonth: [], applyOnHolidays: true) // 3 days
        let tuesdayRule = SweepingRule(dayOfWeek: 3, startTime: "09:00", endTime: "11:00",
                                       weeksOfMonth: [], applyOnHolidays: true) // tomorrow
        // Put 3-day rule first in array
        let segment = makeSegment(rules: [thursdayRule, tuesdayRule])
        let result = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(result, .orange, "Tomorrow rule should take precedence (orange) over 3-day rule")
    }

    // MARK: - Color/status correlation

    /// RED street → determineStatus returns .today or .imminent
    func testRedStatusCorrelation() {
        let monday = makeDate(2026, 3, 2, 7, 0) // Monday 7:00 AM, sweep at 09:00
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [rule])

        let colorStatus = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(colorStatus, .red)

        let engineStatus = SweepingRuleEngine.shared.determineStatus(for: segment, at: monday)
        switch engineStatus {
        case .today, .imminent: break // Expected
        default: XCTFail("Red street should have .today or .imminent status, got \(engineStatus)")
        }
    }

    /// GREEN street → determineStatus returns .safe or .upcoming
    func testGreenStatusCorrelation() {
        let monday = makeDate(2026, 3, 2, 7, 0)
        let saturdayRule = SweepingRule(dayOfWeek: 7, startTime: "09:00", endTime: "11:00",
                                        weeksOfMonth: [], applyOnHolidays: true) // Saturday = 5 days away
        let segment = makeSegment(rules: [saturdayRule])

        let colorStatus = segment.mapColorStatus(today: monday, upcomingDates: upcomingDates(from: monday))
        XCTAssertEqual(colorStatus, .green)

        let engineStatus = SweepingRuleEngine.shared.determineStatus(for: segment, at: monday)
        switch engineStatus {
        case .safe, .upcoming: break // Expected
        default: XCTFail("Green street should have .safe or .upcoming status, got \(engineStatus)")
        }
    }

    // MARK: - Timer calculation via nextSweepIncludingToday

    /// Sweep today, not started → correct interval
    func testNextSweepTodayNotStarted() {
        let now = makeDate(2026, 3, 2, 7, 0) // Monday 7:00 AM
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [rule])

        let result = segment.nextSweepIncludingToday(from: now)
        XCTAssertNotNil(result.start, "Should find today's sweep")
        XCTAssertNotNil(result.end)

        if let start = result.start {
            let interval = start.timeIntervalSince(now)
            XCTAssertEqual(interval, 7200, accuracy: 1, "Should be ~2 hours (7200s) until 9:00 AM")
        }
    }

    /// In-progress detection: now between start and end
    func testSweepInProgress() {
        let now = makeDate(2026, 3, 2, 10, 0) // Monday 10:00 AM, during 09:00-11:00 sweep
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [rule])

        let result = segment.nextSweepIncludingToday(from: now)
        XCTAssertNotNil(result.start)
        XCTAssertNotNil(result.end)

        if let start = result.start, let end = result.end {
            let interval = start.timeIntervalSince(now)
            XCTAssertLessThan(interval, 0, "Start should be in the past (in-progress)")
            XCTAssertGreaterThan(end.timeIntervalSince(now), 0, "End should be in the future")
        }
    }

    /// Boundary: exactly at endTime → falls through to next occurrence
    func testExactlyAtEndTimeFallsThrough() {
        let now = makeDate(2026, 3, 2, 11, 0) // Monday 11:00 = exactly at endTime
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [rule])

        let result = segment.nextSweepIncludingToday(from: now)
        // endDateTime (11:00) is NOT > referenceDate (11:00), so should fall through to next week
        if let start = result.start {
            XCTAssertGreaterThan(start.timeIntervalSince(now), 0, "Should find next occurrence, not today's ended sweep")
        }
    }

    /// Late night sweep (23:00-23:59): correct interval from 22:00
    func testLateNightSweep() {
        let now = makeDate(2026, 3, 2, 22, 0) // Monday 10:00 PM
        let rule = SweepingRule(dayOfWeek: 2, startTime: "23:00", endTime: "23:59",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [rule])

        let result = segment.nextSweepIncludingToday(from: now)
        XCTAssertNotNil(result.start)

        if let start = result.start {
            let interval = start.timeIntervalSince(now)
            XCTAssertEqual(interval, 3600, accuracy: 1, "Should be ~1 hour until 11:00 PM")
        }
    }
}
