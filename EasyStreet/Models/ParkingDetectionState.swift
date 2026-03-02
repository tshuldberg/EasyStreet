import Foundation
import CoreLocation

/// State machine for auto-detecting when the user parks their car.
///
/// Transitions:
/// ```
/// idle → driving → possiblePark → confirmed → idle
///                       ↓
///               (driving resumes) → idle
/// ```
enum ParkingDetectionState: Equatable {
    /// Not monitoring or no activity detected
    case idle

    /// User is driving (CoreMotion reports automotive activity)
    case driving

    /// User may have parked — was driving, now walking/stationary.
    /// Captures the location where the car stopped and the time of detection.
    case possiblePark(location: CLLocationCoordinate2D, timestamp: Date)

    /// Parking confirmed after the confirmation timer expired.
    /// Carries the parking location and resolved street name (if available).
    case confirmed(location: CLLocationCoordinate2D, streetName: String?)

    // MARK: - Transition Validation

    /// Attempts a transition to the given state. Returns the new state if valid, nil if invalid.
    func transition(to newState: ParkingDetectionState) -> ParkingDetectionState? {
        // Any state can reset to idle
        if case .idle = newState { return newState }

        switch (self, newState) {
        case (.idle, .driving):
            return newState
        case (.driving, .possiblePark):
            return newState
        case (.possiblePark, .confirmed):
            return newState
        case (.possiblePark, .driving):
            // False positive: user resumed driving before timer expired.
            // Transition back to driving so the pipeline stays active.
            return newState
        default:
            return nil
        }
    }

    // MARK: - Equatable

    static func == (lhs: ParkingDetectionState, rhs: ParkingDetectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.driving, .driving):
            return true
        case (.possiblePark(let l1, let t1), .possiblePark(let l2, let t2)):
            return l1.latitude == l2.latitude
                && l1.longitude == l2.longitude
                && t1 == t2
        case (.confirmed(let l1, let s1), .confirmed(let l2, let s2)):
            return l1.latitude == l2.latitude
                && l1.longitude == l2.longitude
                && s1 == s2
        default:
            return false
        }
    }
}
