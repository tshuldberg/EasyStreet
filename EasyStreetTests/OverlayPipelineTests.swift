import XCTest
import MapKit
@testable import EasyStreet

class OverlayPipelineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreetSegment.clearPolylineCache()
    }

    func testStreetSegmentPolylineHasValidPoints() {
        let segment = StreetSegment(
            id: "test", streetName: "Test St",
            coordinates: [[37.78, -122.41], [37.79, -122.42]],
            rules: []
        )
        XCTAssertEqual(segment.polyline.pointCount, 2)
    }

    func testEmptyCoordinatesProducesEmptyPolyline() {
        let segment = StreetSegment(id: "test", streetName: "Test St", coordinates: [], rules: [])
        XCTAssertEqual(segment.polyline.pointCount, 0)
    }

    func testSingleCoordinatePolyline() {
        let segment = StreetSegment(id: "test", streetName: "Test St", coordinates: [[37.78, -122.41]], rules: [])
        XCTAssertEqual(segment.polyline.pointCount, 1)
    }

    func testMultipleCoordinatesPolyline() {
        let coords: [[Double]] = [
            [37.78, -122.41],
            [37.785, -122.415],
            [37.79, -122.42],
            [37.795, -122.425]
        ]
        let segment = StreetSegment(id: "test", streetName: "Test St", coordinates: coords, rules: [])
        XCTAssertEqual(segment.polyline.pointCount, 4)
    }

    func testPolylineCoordinatesMatchInput() {
        let inputCoords: [[Double]] = [[37.78, -122.41], [37.79, -122.42]]
        let segment = StreetSegment(id: "test", streetName: "Test St", coordinates: inputCoords, rules: [])
        let polyline = segment.polyline

        XCTAssertEqual(polyline.pointCount, 2)

        let points = polyline.points()
        let coord0 = points[0].coordinate
        let coord1 = points[1].coordinate

        XCTAssertEqual(coord0.latitude, 37.78, accuracy: 0.0001)
        XCTAssertEqual(coord0.longitude, -122.41, accuracy: 0.0001)
        XCTAssertEqual(coord1.latitude, 37.79, accuracy: 0.0001)
        XCTAssertEqual(coord1.longitude, -122.42, accuracy: 0.0001)
    }

    func testMapColorSubtitleEncodingRed() {
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        let rule = SweepingRule(dayOfWeek: weekday, startTime: "23:00", endTime: "23:59",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        XCTAssertEqual(segment.mapColorStatus(), .red)
    }

    func testMapColorSubtitleEncodingGreen() {
        // Rule for a day far in the future (5 days out)
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let weekday = Calendar.current.component(.weekday, from: futureDate)
        let rule = SweepingRule(dayOfWeek: weekday, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [rule])
        XCTAssertEqual(segment.mapColorStatus(), .green)
    }

    func testSegmentWithNoRulesIsGreen() {
        let segment = StreetSegment(id: "t", streetName: "T",
                                     coordinates: [[37.78, -122.41]], rules: [])
        XCTAssertEqual(segment.mapColorStatus(), .green)
    }
}
