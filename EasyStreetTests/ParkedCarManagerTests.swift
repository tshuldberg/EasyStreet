import XCTest
@testable import EasyStreet

class ParkedCarManagerTests: XCTestCase {

    private let suiteName = "ParkedCarManagerTests"
    private var testDefaults: UserDefaults!
    private var manager: ParkedCarManager!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.removePersistentDomain(forName: suiteName)
        manager = ParkedCarManager(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - isCarParked

    func testIsCarParkedFalseInitially() {
        XCTAssertFalse(manager.isCarParked, "Should not be parked initially")
    }

    func testParkCarSetsIsCarParkedTrue() {
        let location = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        manager.parkCar(at: location, streetName: "Test St")
        XCTAssertTrue(manager.isCarParked, "Should be parked after parkCar")
    }

    // MARK: - Coordinate Persistence

    func testParkCarSavesCoordinates() {
        let location = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
        manager.parkCar(at: location, streetName: "Market St")

        guard let parked = manager.parkedLocation else {
            XCTFail("Parked location should not be nil")
            return
        }
        XCTAssertEqual(parked.latitude, 37.7849, accuracy: 0.0001)
        XCTAssertEqual(parked.longitude, -122.4094, accuracy: 0.0001)
    }

    // MARK: - Street Name

    func testParkCarSavesStreetName() {
        let location = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        manager.parkCar(at: location, streetName: "Mission St")
        XCTAssertEqual(manager.parkedStreetName, "Mission St")
    }

    func testParkCarWithoutStreetName() {
        let location = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        manager.parkCar(at: location)
        XCTAssertNil(manager.parkedStreetName, "Street name should be nil when not provided")
    }

    // MARK: - Timestamp

    func testParkCarSavesTimestamp() {
        let before = Date()
        let location = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        manager.parkCar(at: location)
        let after = Date()

        guard let parkedTime = manager.parkedTime else {
            XCTFail("Parked time should not be nil")
            return
        }
        XCTAssertTrue(parkedTime >= before && parkedTime <= after,
                       "Parked time should be between before and after parking")
    }

    // MARK: - Clear

    func testClearParkedCarRemovesAll() {
        let location = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        manager.parkCar(at: location, streetName: "Test St")
        XCTAssertTrue(manager.isCarParked)

        manager.clearParkedCar()
        XCTAssertFalse(manager.isCarParked, "Should not be parked after clear")
        XCTAssertNil(manager.parkedLocation, "Location should be nil after clear")
        XCTAssertNil(manager.parkedStreetName, "Street name should be nil after clear")
    }

    // MARK: - Update Location

    func testUpdateParkedLocationChanges() {
        let original = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        manager.parkCar(at: original, streetName: "Test St")

        let newLocation = CLLocationCoordinate2D(latitude: 37.79, longitude: -122.42)
        manager.updateParkedLocation(to: newLocation)

        guard let updated = manager.parkedLocation else {
            XCTFail("Updated location should not be nil")
            return
        }
        XCTAssertEqual(updated.latitude, 37.79, accuracy: 0.0001)
        XCTAssertEqual(updated.longitude, -122.42, accuracy: 0.0001)
    }

    func testUpdateParkedLocationNoop() {
        // No car parked, update should be a no-op
        let newLocation = CLLocationCoordinate2D(latitude: 37.79, longitude: -122.42)
        manager.updateParkedLocation(to: newLocation)
        XCTAssertFalse(manager.isCarParked, "Should still not be parked")
    }

    // MARK: - Notification Lead Minutes

    func testNotificationLeadMinutesDefault() {
        XCTAssertEqual(manager.notificationLeadMinutes, 60, "Default should be 60 minutes")
    }

    func testNotificationLeadMinutesPersists() {
        manager.notificationLeadMinutes = 30
        XCTAssertEqual(manager.notificationLeadMinutes, 30, "Custom lead time should persist")
    }

    // MARK: - NSNotification Posting

    func testParkCarPostsNotification() {
        let expectation = expectation(forNotification: .parkedCarStatusDidChange, object: nil)
        let location = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        manager.parkCar(at: location)
        wait(for: [expectation], timeout: 1.0)
    }

    func testClearParkedCarPostsNotification() {
        let location = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        manager.parkCar(at: location)

        let expectation = expectation(forNotification: .parkedCarStatusDidChange, object: nil)
        manager.clearParkedCar()
        wait(for: [expectation], timeout: 1.0)
    }

    func testUpdateLocationPostsNotification() {
        let location = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)
        manager.parkCar(at: location)

        let expectation = expectation(forNotification: .parkedCarStatusDidChange, object: nil)
        let newLocation = CLLocationCoordinate2D(latitude: 37.79, longitude: -122.42)
        manager.updateParkedLocation(to: newLocation)
        wait(for: [expectation], timeout: 1.0)
    }
}
