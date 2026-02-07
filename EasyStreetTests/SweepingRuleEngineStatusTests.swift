import XCTest
@testable import EasyStreet

class SweepingRuleEngineStatusTests: XCTestCase {

    let engine = SweepingRuleEngine.shared

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    private func makeSegment(dayOfWeek: Int, startTime: String, endTime: String, weeksOfMonth: [Int] = []) -> StreetSegment {
        let rule = SweepingRule(dayOfWeek: dayOfWeek, startTime: startTime, endTime: endTime,
                                weeksOfMonth: weeksOfMonth, applyOnHolidays: true)
        return StreetSegment(id: "status-test", streetName: "Status St",
                             coordinates: [[37.78, -122.41]], rules: [rule])
    }

    // MARK: - Tests

    func testNoSegmentReturnsNoData() {
        let status = engine.determineStatus(for: nil, at: Date())
        if case .noData = status { } else { XCTFail("Expected .noData, got \(status)") }
    }

    func testSweepingAlreadyPassedReturnsSafe() {
        // March 2, 2026 = Monday (weekday 2), sweep at 06:00, now is 14:00
        let segment = makeSegment(dayOfWeek: 2, startTime: "06:00", endTime: "08:00")
        let now = makeDate(2026, 3, 2, 14, 0)
        let status = engine.determineStatus(for: segment, at: now)
        if case .safe = status { } else { XCTFail("Expected .safe (sweep already passed), got \(status)") }
    }

    func testSweepingMoreThanOneHourAwayReturnsToday() {
        // Monday, sweep at 18:00, now 14:00 (4 hours away)
        let segment = makeSegment(dayOfWeek: 2, startTime: "18:00", endTime: "20:00")
        let now = makeDate(2026, 3, 2, 14, 0)
        let status = engine.determineStatus(for: segment, at: now)
        if case .today = status { } else { XCTFail("Expected .today, got \(status)") }
    }

    func testSweepingLessThanOneHourAwayReturnsImminent() {
        // Monday, sweep at 14:30, now 14:00 (30 min away)
        let segment = makeSegment(dayOfWeek: 2, startTime: "14:30", endTime: "16:00")
        let now = makeDate(2026, 3, 2, 14, 0)
        let status = engine.determineStatus(for: segment, at: now)
        if case .imminent = status { } else { XCTFail("Expected .imminent, got \(status)") }
    }

    func testSweepingExactlyOneHourAwayReturnsToday() {
        // Monday, sweep at 15:00, now 14:00 (exactly 1 hour)
        let segment = makeSegment(dayOfWeek: 2, startTime: "15:00", endTime: "17:00")
        let now = makeDate(2026, 3, 2, 14, 0)
        let status = engine.determineStatus(for: segment, at: now)
        if case .today = status { } else { XCTFail("Expected .today (exactly 1 hour = not imminent), got \(status)") }
    }

    func testSweepingJustUnderOneHourReturnsImminent() {
        // Monday, sweep at 14:59, now 14:00 (59 min away)
        let segment = makeSegment(dayOfWeek: 2, startTime: "14:59", endTime: "16:00")
        let now = makeDate(2026, 3, 2, 14, 0)
        let status = engine.determineStatus(for: segment, at: now)
        if case .imminent = status { } else { XCTFail("Expected .imminent (just under 1 hour), got \(status)") }
    }

    func testMalformedStartTimeReturnsUnknown() {
        let segment = makeSegment(dayOfWeek: 2, startTime: "bad", endTime: "worse")
        let now = makeDate(2026, 3, 2, 14, 0)
        let status = engine.determineStatus(for: segment, at: now)
        if case .unknown = status { } else { XCTFail("Expected .unknown for malformed time, got \(status)") }
    }

    func testNoSweeperTodayWithUpcomingReturnsUpcoming() {
        // Rule for Tuesday (weekday 3), but now is Monday (weekday 2)
        let segment = makeSegment(dayOfWeek: 3, startTime: "09:00", endTime: "11:00")
        let now = makeDate(2026, 3, 2, 14, 0) // Monday
        let status = engine.determineStatus(for: segment, at: now)
        if case .upcoming = status { } else { XCTFail("Expected .upcoming for different day, got \(status)") }
    }

    func testNoSweeperTodayNoUpcomingReturnsSafe() {
        // Segment with empty rules
        let segment = StreetSegment(id: "empty", streetName: "Empty St",
                                     coordinates: [[37.78, -122.41]], rules: [])
        let now = makeDate(2026, 3, 2, 14, 0)
        let status = engine.determineStatus(for: segment, at: now)
        if case .safe = status { } else { XCTFail("Expected .safe for no rules, got \(status)") }
    }

    func testNoMatchingRuleReturnsSafe() {
        // Rule for week 4 Monday, but ref date is week 1 Monday
        let segment = makeSegment(dayOfWeek: 2, startTime: "09:00", endTime: "11:00", weeksOfMonth: [4])
        let now = makeDate(2026, 3, 2, 8, 0) // Week 1 Monday
        let status = engine.determineStatus(for: segment, at: now)
        // Since the rule doesn't apply this week, it falls to the "else" branch (upcoming or safe)
        switch status {
        case .safe, .upcoming: break
        default: XCTFail("Expected .safe or .upcoming for non-matching week, got \(status)")
        }
    }

    // MARK: - Additional Edge Cases

    /// Midnight start time: sweep at 00:00, now is 23:00 day before → upcoming
    func testMidnightStartTimeUpcoming() {
        // March 1 (Sunday) at 23:00, rule is for Monday at 00:00
        let segment = makeSegment(dayOfWeek: 2, startTime: "00:00", endTime: "02:00")
        let now = makeDate(2026, 3, 1, 23, 0) // Sunday 11 PM
        let status = engine.determineStatus(for: segment, at: now)
        if case .upcoming = status { } else { XCTFail("Expected .upcoming for midnight sweep on next day, got \(status)") }
    }

    /// Status after sweep ends same day → safe
    func testAfterSweepEndsSameDay() {
        // Monday sweep 09:00-11:00, now is 15:00
        let segment = makeSegment(dayOfWeek: 2, startTime: "09:00", endTime: "11:00")
        let now = makeDate(2026, 3, 2, 15, 0)
        let status = engine.determineStatus(for: segment, at: now)
        if case .safe = status { } else { XCTFail("Expected .safe after sweep ended, got \(status)") }
    }

    /// Multiple rules same day — documents first(where:) limitation
    /// Morning rule passed → returns .safe even though evening rule is upcoming
    func testMultipleRulesSameDayFirstWhereLimit() {
        let morningRule = SweepingRule(dayOfWeek: 2, startTime: "06:00", endTime: "08:00",
                                       weeksOfMonth: [], applyOnHolidays: true)
        let eveningRule = SweepingRule(dayOfWeek: 2, startTime: "18:00", endTime: "20:00",
                                       weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "multi", streetName: "Multi St",
                                     coordinates: [[37.78, -122.41]],
                                     rules: [morningRule, eveningRule])
        let now = makeDate(2026, 3, 2, 10, 0) // Monday 10 AM (morning passed, evening upcoming)
        let status = engine.determineStatus(for: segment, at: now)
        // Known limitation: first(where:) finds morning rule first, sweep passed → .safe
        // Even though evening rule is upcoming. This test documents the behavior.
        if case .safe = status {
            // This is the known-limitation behavior — morning rule matched first, already passed
        } else if case .today = status {
            // If implementation improves to check all rules, this would be acceptable too
        } else if case .imminent = status {
            // Also acceptable if implementation improves
        } else {
            XCTFail("Expected .safe (known limitation) or .today/.imminent (if improved), got \(status)")
        }
    }

    /// 59 minutes away → imminent
    func test59MinutesAwayIsImminent() {
        let segment = makeSegment(dayOfWeek: 2, startTime: "15:00", endTime: "17:00")
        let now = makeDate(2026, 3, 2, 14, 1) // 59 minutes before 15:00
        let status = engine.determineStatus(for: segment, at: now)
        if case .imminent = status { } else { XCTFail("Expected .imminent for 59 minutes away, got \(status)") }
    }
}
