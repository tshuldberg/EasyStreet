import Foundation
import CoreLocation
import UserNotifications

/// Manages the user's parked car location and notification scheduling
class ParkedCarManager {
    // Shared singleton instance
    static let shared = ParkedCarManager()

    // Notification identifier constants
    private struct NotificationIDs {
        static let sweepingReminder = "sweepingReminder"
    }

    // UserDefaults keys
    private struct UserDefaultsKeys {
        static let parkedLatitude = "parkedLatitude"
        static let parkedLongitude = "parkedLongitude"
        static let parkedTimestamp = "parkedTimestamp"
        static let parkedStreetName = "parkedStreetName"
        static let notificationLeadMinutes = "notificationLeadMinutes"
    }

    private init() {}

    // MARK: - Properties

    /// Check if a car is currently parked
    var isCarParked: Bool {
        return UserDefaults.standard.object(forKey: UserDefaultsKeys.parkedLatitude) != nil
    }

    /// Get the parked car location
    var parkedLocation: CLLocationCoordinate2D? {
        guard let lat = UserDefaults.standard.object(forKey: UserDefaultsKeys.parkedLatitude) as? Double,
              let lon = UserDefaults.standard.object(forKey: UserDefaultsKeys.parkedLongitude) as? Double else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Get the time the car was parked
    var parkedTime: Date? {
        guard let timestamp = UserDefaults.standard.object(forKey: UserDefaultsKeys.parkedTimestamp) as? Double else {
            return nil
        }

        return Date(timeIntervalSince1970: timestamp)
    }

    /// Get street name where car is parked
    var parkedStreetName: String? {
        return UserDefaults.standard.string(forKey: UserDefaultsKeys.parkedStreetName)
    }

    /// Notification lead time in minutes (default: 60)
    var notificationLeadMinutes: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: UserDefaultsKeys.notificationLeadMinutes)
            return stored > 0 ? stored : 60
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.notificationLeadMinutes)
        }
    }

    /// Save parked car location
    /// - Parameters:
    ///   - location: The location where the car is parked
    ///   - streetName: The name of the street (optional)
    func parkCar(at location: CLLocationCoordinate2D, streetName: String? = nil) {
        // Save to UserDefaults
        UserDefaults.standard.set(location.latitude, forKey: UserDefaultsKeys.parkedLatitude)
        UserDefaults.standard.set(location.longitude, forKey: UserDefaultsKeys.parkedLongitude)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.parkedTimestamp)

        if let streetName = streetName {
            UserDefaults.standard.set(streetName, forKey: UserDefaultsKeys.parkedStreetName)
        }

        // Notify observers that parked car status has changed
        NotificationCenter.default.post(name: .parkedCarStatusDidChange, object: nil)
    }

    /// Update the location of the parked car (for manual pin adjustment)
    func updateParkedLocation(to newLocation: CLLocationCoordinate2D) {
        guard isCarParked else { return }

        UserDefaults.standard.set(newLocation.latitude, forKey: UserDefaultsKeys.parkedLatitude)
        UserDefaults.standard.set(newLocation.longitude, forKey: UserDefaultsKeys.parkedLongitude)

        // Notify observers that parked car status has changed
        NotificationCenter.default.post(name: .parkedCarStatusDidChange, object: nil)
    }

    /// Clear parked car data and cancel notifications
    func clearParkedCar() {
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.parkedLatitude)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.parkedLongitude)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.parkedTimestamp)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.parkedStreetName)

        // Cancel any scheduled notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [NotificationIDs.sweepingReminder]
        )

        // Notify observers that parked car status has changed
        NotificationCenter.default.post(name: .parkedCarStatusDidChange, object: nil)
    }

    /// Schedule a notification for upcoming street sweeping
    /// - Parameters:
    ///   - sweepingTime: The time when sweeping will begin
    ///   - streetName: Name of the street where car is parked
    func scheduleNotification(for sweepingTime: Date, streetName: String) {
        // Request notification permission if not already granted
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                print("Notification permission denied or error: \(String(describing: error))")
                return
            }

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Street Sweeping Alert"
            content.body = "Street sweeping soon at \(streetName)! Move your car by \(self.formatTime(sweepingTime))."
            content.sound = .default

            // Notify user ahead of sweeping by configurable lead time
            let leadSeconds = TimeInterval(self.notificationLeadMinutes * 60)
            let notificationTime = sweepingTime.addingTimeInterval(-leadSeconds)

            // Only schedule if notification time is in the future
            guard notificationTime > Date() else {
                print("Warning: Attempted to schedule a notification in the past")
                return
            }

            // Create trigger (with some time before the actual sweeping)
            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notificationTime
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

            // Create request
            let request = UNNotificationRequest(
                identifier: NotificationIDs.sweepingReminder,
                content: content,
                trigger: trigger
            )

            // Add to notification center
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let parkedCarStatusDidChange = Notification.Name("parkedCarStatusDidChange")
}
