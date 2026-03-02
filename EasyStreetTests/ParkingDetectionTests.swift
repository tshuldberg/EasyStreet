import XCTest
import CoreLocation
import UserNotifications
@testable import EasyStreet

// MARK: - State Machine Tests

class ParkingDetectionStateTests: XCTestCase {

    // MARK: - Test Fixtures

    private let sampleLocation = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
    private let otherLocation = CLLocationCoordinate2D(latitude: 37.7900, longitude: -122.4200)
    private let sampleTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
    private let otherTimestamp = Date(timeIntervalSince1970: 1_700_001_000)

    // MARK: - Valid Transitions

    func testIdleToDriving() {
        let state = ParkingDetectionState.idle
        let result = state.transition(to: .driving)
        XCTAssertEqual(result, .driving)
    }

    func testDrivingToPossiblePark() {
        let state = ParkingDetectionState.driving
        let result = state.transition(to: .possiblePark(location: sampleLocation, timestamp: sampleTimestamp))
        XCTAssertEqual(result, .possiblePark(location: sampleLocation, timestamp: sampleTimestamp))
    }

    func testPossibleParkToConfirmed() {
        let state = ParkingDetectionState.possiblePark(location: sampleLocation, timestamp: sampleTimestamp)
        let result = state.transition(to: .confirmed(location: sampleLocation, streetName: "Market St"))
        XCTAssertEqual(result, .confirmed(location: sampleLocation, streetName: "Market St"))
    }

    func testPossibleParkToDrivingFalsePositive() {
        let state = ParkingDetectionState.possiblePark(location: sampleLocation, timestamp: sampleTimestamp)
        let result = state.transition(to: .driving)
        XCTAssertEqual(result, .driving)
    }

    func testPossibleParkToIdleReset() {
        let state = ParkingDetectionState.possiblePark(location: sampleLocation, timestamp: sampleTimestamp)
        let result = state.transition(to: .idle)
        XCTAssertEqual(result, .idle)
    }

    func testConfirmedToIdleReset() {
        let state = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Market St")
        let result = state.transition(to: .idle)
        XCTAssertEqual(result, .idle)
    }

    func testAnyStateToIdleIsAlwaysValid() {
        let states: [ParkingDetectionState] = [
            .idle,
            .driving,
            .possiblePark(location: sampleLocation, timestamp: sampleTimestamp),
            .confirmed(location: sampleLocation, streetName: "Market St")
        ]

        for state in states {
            let result = state.transition(to: .idle)
            XCTAssertEqual(result, .idle, "Transition from \(state) to .idle should always succeed")
        }
    }

    // MARK: - Invalid Transitions

    func testIdleToPossibleParkIsInvalid() {
        let state = ParkingDetectionState.idle
        let result = state.transition(to: .possiblePark(location: sampleLocation, timestamp: sampleTimestamp))
        XCTAssertNil(result, "idle -> possiblePark should be invalid")
    }

    func testIdleToConfirmedIsInvalid() {
        let state = ParkingDetectionState.idle
        let result = state.transition(to: .confirmed(location: sampleLocation, streetName: "Market St"))
        XCTAssertNil(result, "idle -> confirmed should be invalid")
    }

    func testDrivingToConfirmedIsInvalid() {
        let state = ParkingDetectionState.driving
        let result = state.transition(to: .confirmed(location: sampleLocation, streetName: "Market St"))
        XCTAssertNil(result, "driving -> confirmed must go through possiblePark")
    }

    func testDrivingToDrivingIsInvalid() {
        let state = ParkingDetectionState.driving
        let result = state.transition(to: .driving)
        XCTAssertNil(result, "driving -> driving should be invalid (already driving)")
    }

    func testConfirmedToDrivingIsInvalid() {
        let state = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Market St")
        let result = state.transition(to: .driving)
        XCTAssertNil(result, "confirmed -> driving should be invalid")
    }

    func testConfirmedToPossibleParkIsInvalid() {
        let state = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Market St")
        let result = state.transition(to: .possiblePark(location: sampleLocation, timestamp: sampleTimestamp))
        XCTAssertNil(result, "confirmed -> possiblePark should be invalid")
    }

    // MARK: - Equatable Tests

    func testIdleStatesAreEqual() {
        XCTAssertEqual(ParkingDetectionState.idle, ParkingDetectionState.idle)
    }

    func testDrivingStatesAreEqual() {
        XCTAssertEqual(ParkingDetectionState.driving, ParkingDetectionState.driving)
    }

    func testPossibleParkWithSameLocationAndTimeAreEqual() {
        let a = ParkingDetectionState.possiblePark(location: sampleLocation, timestamp: sampleTimestamp)
        let b = ParkingDetectionState.possiblePark(location: sampleLocation, timestamp: sampleTimestamp)
        XCTAssertEqual(a, b)
    }

    func testPossibleParkWithDifferentLocationsAreNotEqual() {
        let a = ParkingDetectionState.possiblePark(location: sampleLocation, timestamp: sampleTimestamp)
        let b = ParkingDetectionState.possiblePark(location: otherLocation, timestamp: sampleTimestamp)
        XCTAssertNotEqual(a, b)
    }

    func testPossibleParkWithDifferentTimestampsAreNotEqual() {
        let a = ParkingDetectionState.possiblePark(location: sampleLocation, timestamp: sampleTimestamp)
        let b = ParkingDetectionState.possiblePark(location: sampleLocation, timestamp: otherTimestamp)
        XCTAssertNotEqual(a, b)
    }

    func testConfirmedWithSameLocationAndStreetNameAreEqual() {
        let a = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Market St")
        let b = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Market St")
        XCTAssertEqual(a, b)
    }

    func testConfirmedWithDifferentStreetNamesAreNotEqual() {
        let a = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Market St")
        let b = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Mission St")
        XCTAssertNotEqual(a, b)
    }

    func testConfirmedWithDifferentLocationsAreNotEqual() {
        let a = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Market St")
        let b = ParkingDetectionState.confirmed(location: otherLocation, streetName: "Market St")
        XCTAssertNotEqual(a, b)
    }

    func testConfirmedWithNilStreetNamesAreEqual() {
        let a = ParkingDetectionState.confirmed(location: sampleLocation, streetName: nil)
        let b = ParkingDetectionState.confirmed(location: sampleLocation, streetName: nil)
        XCTAssertEqual(a, b)
    }

    func testConfirmedNilVsNonNilStreetNameAreNotEqual() {
        let a = ParkingDetectionState.confirmed(location: sampleLocation, streetName: nil)
        let b = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Market St")
        XCTAssertNotEqual(a, b)
    }

    func testDifferentCasesAreNotEqual() {
        let idle = ParkingDetectionState.idle
        let driving = ParkingDetectionState.driving
        let possiblePark = ParkingDetectionState.possiblePark(location: sampleLocation, timestamp: sampleTimestamp)
        let confirmed = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Market St")

        XCTAssertNotEqual(idle, driving)
        XCTAssertNotEqual(idle, possiblePark)
        XCTAssertNotEqual(idle, confirmed)
        XCTAssertNotEqual(driving, possiblePark)
        XCTAssertNotEqual(driving, confirmed)
        XCTAssertNotEqual(possiblePark, confirmed)
    }

    // MARK: - Full State Machine Walkthrough

    func testFullParkingLifecycle() {
        var state = ParkingDetectionState.idle

        // Start driving
        guard let driving = state.transition(to: .driving) else {
            XCTFail("idle -> driving should succeed")
            return
        }
        state = driving
        XCTAssertEqual(state, .driving)

        // Possible park detected
        let parkState = ParkingDetectionState.possiblePark(location: sampleLocation, timestamp: sampleTimestamp)
        guard let possible = state.transition(to: parkState) else {
            XCTFail("driving -> possiblePark should succeed")
            return
        }
        state = possible
        XCTAssertEqual(state, parkState)

        // Confirmed
        let confirmedState = ParkingDetectionState.confirmed(location: sampleLocation, streetName: "Market St")
        guard let confirmed = state.transition(to: confirmedState) else {
            XCTFail("possiblePark -> confirmed should succeed")
            return
        }
        state = confirmed
        XCTAssertEqual(state, confirmedState)

        // Reset
        guard let reset = state.transition(to: .idle) else {
            XCTFail("confirmed -> idle should succeed")
            return
        }
        state = reset
        XCTAssertEqual(state, .idle)
    }

    func testFalsePositiveLifecycle() {
        var state = ParkingDetectionState.idle

        // Start driving
        state = state.transition(to: .driving)!

        // Possible park detected
        state = state.transition(to: .possiblePark(location: sampleLocation, timestamp: sampleTimestamp))!

        // False positive - resume driving
        guard let resumed = state.transition(to: .driving) else {
            XCTFail("possiblePark -> driving (false positive) should succeed")
            return
        }
        state = resumed
        XCTAssertEqual(state, .driving)

        // Second possible park
        state = state.transition(to: .possiblePark(location: otherLocation, timestamp: otherTimestamp))!

        // This time confirmed
        let confirmed = state.transition(to: .confirmed(location: otherLocation, streetName: "Mission St"))
        XCTAssertNotNil(confirmed)
    }
}

// MARK: - Service Tests

class ParkingDetectionServiceTests: XCTestCase {

    private let userDefaultsKey = "autoDetectParkingEnabled"
    private var service: ParkingDetectionService!

    override func setUp() {
        super.setUp()
        service = ParkingDetectionService.shared
        // Ensure clean state
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        service.stop()
    }

    override func tearDown() {
        service.stop()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        service = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testServiceStartsInIdleState() {
        XCTAssertEqual(service.state, .idle)
    }

    // MARK: - isEnabled / UserDefaults

    func testIsEnabledDefaultsToFalse() {
        XCTAssertFalse(service.isEnabled, "Auto-detect should be disabled by default")
    }

    func testIsEnabledReflectsUserDefaultsTrue() {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        XCTAssertTrue(service.isEnabled)
    }

    func testIsEnabledReflectsUserDefaultsFalse() {
        UserDefaults.standard.set(false, forKey: userDefaultsKey)
        XCTAssertFalse(service.isEnabled)
    }

    func testSettingIsEnabledPersistsToUserDefaults() {
        service.isEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: userDefaultsKey))

        service.isEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: userDefaultsKey))
    }

    // MARK: - Stop resets state

    func testStopResetsStateToIdle() {
        // Service should be idle after stop (called in setUp)
        XCTAssertEqual(service.state, .idle)
    }

    // MARK: - Notification Category Registration

    func testNotificationCategoryIsRegistered() {
        let expectation = expectation(description: "Notification categories fetched")

        UNUserNotificationCenter.current().getNotificationCategories { categories in
            let parkingCategory = categories.first(where: { $0.identifier == "parkingDetection" })
            XCTAssertNotNil(parkingCategory, "parkingDetection category should be registered")

            if let category = parkingCategory {
                XCTAssertEqual(category.actions.count, 2, "Category should have 2 actions")

                let confirmAction = category.actions.first(where: { $0.identifier == "confirmPark" })
                XCTAssertNotNil(confirmAction, "confirmPark action should exist")
                XCTAssertEqual(confirmAction?.title, "Yes, Save Spot")

                let dismissAction = category.actions.first(where: { $0.identifier == "dismissPark" })
                XCTAssertNotNil(dismissAction, "dismissPark action should exist")
                XCTAssertEqual(dismissAction?.title, "No")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Disabling stops monitoring

    func testDisablingServiceCallsStop() {
        service.isEnabled = true
        service.isEnabled = false
        XCTAssertEqual(service.state, .idle, "Disabling should reset state to idle")
    }
}
