import Foundation
import CoreLocation
import CoreMotion
import UserNotifications

/// Detects when the user parks their car using CoreMotion activity recognition
/// and background location monitoring. Fires an actionable notification asking
/// the user to confirm the parking event.
///
/// State machine: idle -> driving -> possiblePark -> confirmed -> idle
class ParkingDetectionService: NSObject, CLLocationManagerDelegate {

    static let shared = ParkingDetectionService()

    // MARK: - Constants

    private enum Constants {
        static let userDefaultsKey = "autoDetectParkingEnabled"
        static let confirmationInterval: TimeInterval = 180 // 3 minutes
        static let dismissTimeout: TimeInterval = 600       // 10 minutes
        static let notificationCategoryID = "parkingDetection"
        static let confirmActionID = "confirmPark"
        static let dismissActionID = "dismissPark"
    }

    // MARK: - Properties

    private let activityManager = CMMotionActivityManager()
    private let locationManager = CLLocationManager()
    private let activityQueue = OperationQueue()

    private(set) var state: ParkingDetectionState = .idle

    private var confirmationTimer: Timer?
    private var dismissTimer: Timer?

    /// Last known location captured while driving, used as parking location.
    private var lastDrivingLocation: CLLocation?

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Constants.userDefaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.userDefaultsKey)
            if newValue {
                start()
            } else {
                stop()
            }
        }
    }

    // MARK: - Init

    private override init() {
        super.init()
        activityQueue.name = "com.easystreet.parkingDetection.activity"
        activityQueue.maxConcurrentOperationCount = 1
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        registerNotificationCategory()
    }

    // MARK: - Public API

    /// Begin monitoring CoreMotion activity and significant location changes.
    func start() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            #if DEBUG
            print("[ParkingDetection] Activity recognition not available on this device")
            #endif
            return
        }

        startActivityUpdates()
        locationManager.startMonitoringSignificantLocationChanges()

        #if DEBUG
        print("[ParkingDetection] Started monitoring")
        #endif
    }

    /// Stop all monitoring, invalidate timers, reset state.
    func stop() {
        activityManager.stopActivityUpdates()
        locationManager.stopMonitoringSignificantLocationChanges()
        invalidateTimers()
        transitionTo(.idle)

        #if DEBUG
        print("[ParkingDetection] Stopped monitoring")
        #endif
    }

    // MARK: - CoreMotion Activity Updates

    private func startActivityUpdates() {
        activityManager.startActivityUpdates(to: activityQueue) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            guard activity.confidence.rawValue >= CMMotionActivityConfidence.medium.rawValue else { return }

            DispatchQueue.main.async {
                self.handleActivity(activity)
            }
        }
    }

    private func handleActivity(_ activity: CMMotionActivity) {
        if activity.automotive {
            handleDrivingDetected()
        } else if activity.walking || activity.stationary {
            handleStoppedDetected()
        }
    }

    private func handleDrivingDetected() {
        switch state {
        case .idle:
            transitionTo(.driving)
        case .possiblePark:
            // False positive — user resumed driving
            invalidateTimers()
            transitionTo(.driving)
        case .driving:
            break // Already driving
        case .confirmed:
            break // Already confirmed, ignore
        }
    }

    private func handleStoppedDetected() {
        guard case .driving = state else { return }

        guard let location = lastDrivingLocation else {
            #if DEBUG
            print("[ParkingDetection] No driving location captured, cannot enter possiblePark")
            #endif
            return
        }

        let newState = ParkingDetectionState.possiblePark(
            location: location.coordinate,
            timestamp: Date()
        )
        transitionTo(newState)
        startConfirmationTimer(at: location.coordinate)
    }

    // MARK: - State Machine

    private func transitionTo(_ newState: ParkingDetectionState) {
        guard let validState = state.transition(to: newState) else {
            #if DEBUG
            print("[ParkingDetection] Invalid transition from \(state) to \(newState)")
            #endif
            return
        }
        state = validState

        #if DEBUG
        print("[ParkingDetection] State -> \(state)")
        #endif
    }

    // MARK: - Confirmation Timer

    private func startConfirmationTimer(at coordinate: CLLocationCoordinate2D) {
        invalidateTimers()

        confirmationTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.confirmationInterval,
            repeats: false
        ) { [weak self] _ in
            self?.confirmationTimerFired(at: coordinate)
        }
    }

    private func confirmationTimerFired(at coordinate: CLLocationCoordinate2D) {
        guard case .possiblePark = state else { return }

        // Don't fire if user already has a parked car saved
        guard !ParkingRepository.shared.isCarParked else {
            #if DEBUG
            print("[ParkingDetection] Car already parked, suppressing notification")
            #endif
            transitionTo(.idle)
            return
        }

        resolveStreetName(for: coordinate) { [weak self] streetName in
            guard let self = self else { return }
            guard case .possiblePark = self.state else { return }

            let confirmed = ParkingDetectionState.confirmed(
                location: coordinate,
                streetName: streetName
            )
            self.transitionTo(confirmed)
            self.fireNotification(at: coordinate, streetName: streetName)
            self.startDismissTimer()
        }
    }

    // MARK: - Dismiss Timer (no-response timeout)

    private func startDismissTimer() {
        dismissTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.dismissTimeout,
            repeats: false
        ) { [weak self] _ in
            #if DEBUG
            print("[ParkingDetection] No response to notification, resetting to idle")
            #endif
            self?.transitionTo(.idle)
        }
    }

    private func invalidateTimers() {
        confirmationTimer?.invalidate()
        confirmationTimer = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    // MARK: - Street Name Resolution

    private func resolveStreetName(
        for coordinate: CLLocationCoordinate2D,
        completion: @escaping (String?) -> Void
    ) {
        // Try street sweeping data first
        if let segment = StreetRepository.shared.findSegment(near: coordinate) {
            completion(segment.streetName)
            return
        }

        // Fall back to CLGeocoder
        CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        ) { placemarks, error in
            DispatchQueue.main.async {
                let streetName = placemarks?.first?.thoroughfare
                #if DEBUG
                if let error = error {
                    print("[ParkingDetection] Geocode error: \(error.localizedDescription)")
                }
                #endif
                completion(streetName)
            }
        }
    }

    // MARK: - Notifications

    private func registerNotificationCategory() {
        let confirmAction = UNNotificationAction(
            identifier: Constants.confirmActionID,
            title: "Yes, Save Spot",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: Constants.dismissActionID,
            title: "No",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Constants.notificationCategoryID,
            actions: [confirmAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func fireNotification(at coordinate: CLLocationCoordinate2D, streetName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Did you just park?"
        if let name = streetName {
            content.body = "It looks like you parked on \(name)"
        } else {
            content.body = "It looks like you just parked your car"
        }
        content.sound = .default
        content.categoryIdentifier = Constants.notificationCategoryID
        content.userInfo = [
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "streetName": streetName as Any
        ]

        let request = UNNotificationRequest(
            identifier: "parkingDetection_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil // Fire immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error = error {
                print("[ParkingDetection] Notification error: \(error.localizedDescription)")
            }
            #endif
        }

        #if DEBUG
        print("[ParkingDetection] Notification fired for \(streetName ?? "unknown street")")
        #endif
    }

    // MARK: - Notification Response Handling

    /// Called from AppDelegate/SceneDelegate when user taps a parking detection notification action.
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard response.notification.request.content.categoryIdentifier == Constants.notificationCategoryID else {
            return
        }

        invalidateTimers()

        switch response.actionIdentifier {
        case Constants.confirmActionID:
            let userInfo = response.notification.request.content.userInfo
            if let lat = userInfo["latitude"] as? Double,
               let lon = userInfo["longitude"] as? Double {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let streetName = userInfo["streetName"] as? String
                ParkingRepository.shared.parkCar(at: coordinate, streetName: streetName)

                #if DEBUG
                print("[ParkingDetection] User confirmed parking at \(streetName ?? "unknown")")
                #endif
            }
        case Constants.dismissActionID:
            #if DEBUG
            print("[ParkingDetection] User dismissed parking notification")
            #endif
        default:
            break
        }

        transitionTo(.idle)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Always track the latest location while monitoring.
        // When in .driving, this captures where the car is so we use the
        // last driving location (not where the user walks to) for parking.
        if case .driving = state {
            lastDrivingLocation = location
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("[ParkingDetection] Location error: \(error.localizedDescription)")
        #endif
    }
}
