import Foundation
import CoreLocation

/// Thin data-access layer over parking state.
/// Wraps `ParkedCarManager` so view controllers never touch UserDefaults
/// directly and the backing store can be swapped later.
class ParkingRepository {
    static let shared = ParkingRepository()

    private let manager = ParkedCarManager.shared

    private init() {}

    // MARK: - Read-only state

    var isCarParked: Bool { manager.isCarParked }
    var parkedLocation: CLLocationCoordinate2D? { manager.parkedLocation }
    var parkedStreetName: String? { manager.parkedStreetName }
    var parkedTime: Date? { manager.parkedTime }

    var notificationLeadMinutes: Int {
        get { manager.notificationLeadMinutes }
        set { manager.notificationLeadMinutes = newValue }
    }

    // MARK: - Mutations

    func parkCar(at location: CLLocationCoordinate2D, streetName: String? = nil) {
        manager.parkCar(at: location, streetName: streetName)
    }

    func updateParkedLocation(to location: CLLocationCoordinate2D) {
        manager.updateParkedLocation(to: location)
    }

    func clearParkedCar() {
        manager.clearParkedCar()
    }

    func scheduleNotification(for time: Date, streetName: String) {
        manager.scheduleNotification(for: time, streetName: streetName)
    }
}
