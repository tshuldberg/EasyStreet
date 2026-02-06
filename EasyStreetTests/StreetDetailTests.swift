import XCTest
import MapKit
import CoreLocation
@testable import EasyStreet

class MockStreetDetailDelegate: StreetDetailDelegate {
    var parkHereCalled = false
    var receivedCoordinate: CLLocationCoordinate2D?
    var receivedStreetName: String?

    func streetDetailDidParkHere(at coordinate: CLLocationCoordinate2D, streetName: String) {
        parkHereCalled = true
        receivedCoordinate = coordinate
        receivedStreetName = streetName
    }
}

class StreetDetailTests: XCTestCase {

    private func makeSegment(
        rules: [SweepingRule] = [],
        coordinates: [[Double]] = [[37.78, -122.41], [37.79, -122.42]]
    ) -> StreetSegment {
        return StreetSegment(id: "test-1", streetName: "Market St",
                             coordinates: coordinates, rules: rules)
    }

    func testDisplaysStreetName() {
        let segment = makeSegment()
        let vc = StreetDetailViewController(segment: segment)
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.streetNameLabel.text, "Market St")
    }

    func testDisplaysGreenStatusWhenNoRules() {
        let segment = makeSegment(rules: [])
        let vc = StreetDetailViewController(segment: segment)
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.nextSweepingLabel.textColor, .systemGreen)
    }

    func testDisplaysRedStatusWhenSweepingToday() {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let rule = SweepingRule(dayOfWeek: weekday, startTime: "23:00", endTime: "23:59",
                                weeksOfMonth: [], applyOnHolidays: true)
        let segment = makeSegment(rules: [rule])
        let vc = StreetDetailViewController(segment: segment)
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.nextSweepingLabel.textColor, .systemRed)
    }

    func testShowsNoRulesMessage() {
        let segment = makeSegment(rules: [])
        let vc = StreetDetailViewController(segment: segment)
        vc.loadViewIfNeeded()
        // rulesStackView should contain a "No sweeping rules on file" label
        let labels = vc.rulesStackView.arrangedSubviews.compactMap { $0 as? UILabel }
        XCTAssertTrue(labels.contains(where: { $0.text?.contains("No sweeping rules") == true }))
    }

    func testShowsRulesWhenPresent() {
        let rule = SweepingRule(dayOfWeek: 2, startTime: "09:00", endTime: "11:00",
                                weeksOfMonth: [1, 3], applyOnHolidays: false)
        let segment = makeSegment(rules: [rule])
        let vc = StreetDetailViewController(segment: segment)
        vc.loadViewIfNeeded()
        let labels = vc.rulesStackView.arrangedSubviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels.count, 1)
        XCTAssertTrue(labels[0].text?.contains("Monday") == true)
    }

    func testParkHereCallsDelegateWithMidpoint() {
        let coords: [[Double]] = [
            [37.78, -122.41],
            [37.79, -122.42],
            [37.80, -122.43],
            [37.81, -122.44]
        ]
        let segment = makeSegment(coordinates: coords)
        let vc = StreetDetailViewController(segment: segment)
        let mockDelegate = MockStreetDetailDelegate()
        vc.delegate = mockDelegate
        vc.loadViewIfNeeded()

        // Simulate Park Here tap
        vc.parkHereButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(mockDelegate.parkHereCalled)
        XCTAssertEqual(mockDelegate.receivedStreetName, "Market St")
        // Midpoint is index 4/2 = 2 -> coords[2] = [37.80, -122.43]
        XCTAssertEqual(mockDelegate.receivedCoordinate?.latitude ?? 0, 37.80, accuracy: 0.001)
        XCTAssertEqual(mockDelegate.receivedCoordinate?.longitude ?? 0, -122.43, accuracy: 0.001)
    }

    func testParkHereWithEmptyCoordinatesDoesNotCallDelegate() {
        let segment = makeSegment(coordinates: [])
        let vc = StreetDetailViewController(segment: segment)
        let mockDelegate = MockStreetDetailDelegate()
        vc.delegate = mockDelegate
        vc.loadViewIfNeeded()

        vc.parkHereButton.sendActions(for: .touchUpInside)

        XCTAssertFalse(mockDelegate.parkHereCalled)
    }

    func testParkHereWithTwoCoordinatesUsesSecond() {
        // With 2 coordinates, midIndex = 2/2 = 1, so coords[1]
        let coords: [[Double]] = [[37.78, -122.41], [37.79, -122.42]]
        let segment = makeSegment(coordinates: coords)
        let vc = StreetDetailViewController(segment: segment)
        let mockDelegate = MockStreetDetailDelegate()
        vc.delegate = mockDelegate
        vc.loadViewIfNeeded()

        vc.parkHereButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(mockDelegate.parkHereCalled)
        XCTAssertEqual(mockDelegate.receivedCoordinate?.latitude ?? 0, 37.79, accuracy: 0.001)
        XCTAssertEqual(mockDelegate.receivedCoordinate?.longitude ?? 0, -122.42, accuracy: 0.001)
    }
}
