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
}
