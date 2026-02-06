import XCTest
import MapKit
@testable import EasyStreet

class HitTestingTests: XCTestCase {

    // MARK: - perpendicularDistance tests

    func testPointOnLineReturnsZero() {
        let a = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41))
        let b = MKMapPoint(CLLocationCoordinate2D(latitude: 37.79, longitude: -122.41))
        // Midpoint of the line
        let mid = MKMapPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let dist = MapHitTesting.perpendicularDistance(from: mid, toLineFrom: a, to: b)
        XCTAssertEqual(dist, 0, accuracy: 1.0) // within 1 meter
    }

    func testPointPerpendicularToSegment() {
        // Horizontal line at constant latitude
        let a = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.42))
        let b = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41))
        // Point directly north of midpoint
        let p = MKMapPoint(CLLocationCoordinate2D(latitude: 37.781, longitude: -122.415))
        let dist = MapHitTesting.perpendicularDistance(from: p, toLineFrom: a, to: b)
        // ~111 meters per 0.001 degree of latitude
        XCTAssertEqual(dist, 111, accuracy: 20)
    }

    func testPointBeyondSegmentEnd() {
        let a = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.42))
        let b = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41))
        // Point east of endpoint b
        let p = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.40))
        let dist = MapHitTesting.perpendicularDistance(from: p, toLineFrom: a, to: b)
        let expectedDist = p.distance(to: b)
        XCTAssertEqual(dist, expectedDist, accuracy: 1.0)
    }

    func testZeroLengthSegmentReturnsDistanceToPoint() {
        let a = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41))
        let p = MKMapPoint(CLLocationCoordinate2D(latitude: 37.79, longitude: -122.41))
        let dist = MapHitTesting.perpendicularDistance(from: p, toLineFrom: a, to: a)
        let expected = p.distance(to: a)
        XCTAssertEqual(dist, expected, accuracy: 1.0)
    }

    // MARK: - findClosestPolyline tests

    func testFindsClosestPolylineWithinThreshold() {
        let coords1 = [
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.42),
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        ]
        let poly1 = MKPolyline(coordinates: coords1, count: 2)
        poly1.title = "street1"

        let coords2 = [
            CLLocationCoordinate2D(latitude: 37.79, longitude: -122.42),
            CLLocationCoordinate2D(latitude: 37.79, longitude: -122.41)
        ]
        let poly2 = MKPolyline(coordinates: coords2, count: 2)
        poly2.title = "street2"

        // Tap near poly1
        let tap = MKMapPoint(CLLocationCoordinate2D(latitude: 37.7801, longitude: -122.415))

        let result = MapHitTesting.findClosestPolyline(
            tapMapPoint: tap, overlays: [poly1, poly2], thresholdMeters: 500
        )
        XCTAssertEqual(result?.title, "street1")
    }

    func testReturnsNilWhenBeyondThreshold() {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.42),
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        ]
        let poly = MKPolyline(coordinates: coords, count: 2)

        // Tap very far away
        let tap = MKMapPoint(CLLocationCoordinate2D(latitude: 37.90, longitude: -122.41))

        let result = MapHitTesting.findClosestPolyline(
            tapMapPoint: tap, overlays: [poly], thresholdMeters: 50
        )
        XCTAssertNil(result)
    }

    func testReturnsNilWithNoOverlays() {
        let tap = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41))
        let result = MapHitTesting.findClosestPolyline(
            tapMapPoint: tap, overlays: [], thresholdMeters: 500
        )
        XCTAssertNil(result)
    }

    func testIgnoresNonPolylineOverlays() {
        // Create a circle overlay (not a polyline)
        let center = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        let circle = MKCircle(center: center, radius: 100)

        let tap = MKMapPoint(center)
        let result = MapHitTesting.findClosestPolyline(
            tapMapPoint: tap, overlays: [circle], thresholdMeters: 500
        )
        XCTAssertNil(result)
    }

    func testIgnoresSinglePointPolylines() {
        let coords = [CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)]
        let poly = MKPolyline(coordinates: coords, count: 1)
        poly.title = "single"

        let tap = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41))
        let result = MapHitTesting.findClosestPolyline(
            tapMapPoint: tap, overlays: [poly], thresholdMeters: 500
        )
        XCTAssertNil(result)
    }

    // MARK: - Overlapping polyline priority tests

    func testPrefersMoreUrgentColorWhenOverlapping() {
        // Two polylines with identical coordinates (L/R sides of same street)
        let coords = [
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.42),
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        ]

        let polyGreen = MKPolyline(coordinates: coords, count: 2)
        polyGreen.title = "street-L"
        polyGreen.subtitle = "green"

        let polyOrange = MKPolyline(coordinates: coords, count: 2)
        polyOrange.title = "street-R"
        polyOrange.subtitle = "orange"

        // Tap directly on the line
        let tap = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.415))

        let result = MapHitTesting.findClosestPolyline(
            tapMapPoint: tap, overlays: [polyGreen, polyOrange], thresholdMeters: 500
        )
        // Should prefer the orange (more urgent) polyline
        XCTAssertEqual(result?.title, "street-R")
        XCTAssertEqual(result?.subtitle, "orange")
    }

    func testPrefersRedOverAllOtherColors() {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.42),
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        ]

        let polyYellow = MKPolyline(coordinates: coords, count: 2)
        polyYellow.title = "s1"
        polyYellow.subtitle = "yellow"

        let polyRed = MKPolyline(coordinates: coords, count: 2)
        polyRed.title = "s2"
        polyRed.subtitle = "red"

        let polyGreen = MKPolyline(coordinates: coords, count: 2)
        polyGreen.title = "s3"
        polyGreen.subtitle = "green"

        let tap = MKMapPoint(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.415))

        let result = MapHitTesting.findClosestPolyline(
            tapMapPoint: tap, overlays: [polyYellow, polyRed, polyGreen], thresholdMeters: 500
        )
        XCTAssertEqual(result?.subtitle, "red")
    }

    func testDoesNotPreferUrgentColorWhenFarAway() {
        // Two polylines at different locations
        let coords1 = [
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.42),
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        ]
        let polyRed = MKPolyline(coordinates: coords1, count: 2)
        polyRed.title = "far-red"
        polyRed.subtitle = "red"

        let coords2 = [
            CLLocationCoordinate2D(latitude: 37.781, longitude: -122.42),
            CLLocationCoordinate2D(latitude: 37.781, longitude: -122.41)
        ]
        let polyGreen = MKPolyline(coordinates: coords2, count: 2)
        polyGreen.title = "near-green"
        polyGreen.subtitle = "green"

        // Tap much closer to the green polyline
        let tap = MKMapPoint(CLLocationCoordinate2D(latitude: 37.7809, longitude: -122.415))

        let result = MapHitTesting.findClosestPolyline(
            tapMapPoint: tap, overlays: [polyRed, polyGreen], thresholdMeters: 500
        )
        // Should prefer the closer polyline (green) since they're not overlapping
        XCTAssertEqual(result?.subtitle, "green")
    }
}
