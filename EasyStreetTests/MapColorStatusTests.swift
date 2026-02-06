import XCTest
@testable import EasyStreet

class MapColorStatusTests: XCTestCase {

    func testMapColorStatusRedWhenSweepingToday() {
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        let rule = SweepingRule(dayOfWeek: weekday, startTime: "23:00", endTime: "23:59",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        XCTAssertEqual(segment.mapColorStatus(), .red)
    }

    func testMapColorStatusGreenWhenNoSweepingSoon() {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let weekday = Calendar.current.component(.weekday, from: future)
        let rule = SweepingRule(dayOfWeek: weekday, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        XCTAssertEqual(segment.mapColorStatus(), .green)
    }

    func testMapColorStatusOrangeWhenSweepingTomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let weekday = Calendar.current.component(.weekday, from: tomorrow)
        let rule = SweepingRule(dayOfWeek: weekday, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        // If today also has sweeping, it would be red; only test tomorrow scenario
        let today = Date()
        let todayWeekday = Calendar.current.component(.weekday, from: today)
        if todayWeekday != weekday {
            XCTAssertEqual(segment.mapColorStatus(), .orange)
        }
    }

    func testMapColorStatusYellowWhenSweepingIn2Or3Days() {
        // Find a day 2-3 days from now that is NOT today or tomorrow
        let twoDaysOut = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        let weekday = Calendar.current.component(.weekday, from: twoDaysOut)
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let tomorrowWeekday = Calendar.current.component(.weekday, from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)

        // Only test if the 2-day-out weekday doesn't collide with today or tomorrow
        if weekday != todayWeekday && weekday != tomorrowWeekday {
            let rule = SweepingRule(dayOfWeek: weekday, startTime: "09:00", endTime: "11:00",
                                    weeksOfMonth: [], applyOnHolidays: true)
            let segment = StreetSegment(id: "t", streetName: "T",
                                         coordinates: [[37.78, -122.41]], rules: [rule])
            XCTAssertEqual(segment.mapColorStatus(), .yellow)
        }
    }
}
