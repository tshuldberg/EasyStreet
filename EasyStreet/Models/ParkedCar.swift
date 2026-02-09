import Foundation
import CoreLocation
import UserNotifications

/// Manages the user's parked car location and notification scheduling
class ParkedCarManager {
    // Shared singleton instance
    static let shared = ParkedCarManager()

    // Notification identifier constants
    private struct NotificationIDs {
        static let sweepingReminderPrefix = "sweepingReminder_"
    }

    private enum NotificationLeadOptions {
        static let supportedMinutes: [Int] = [60, 120, 360, 1440, 2880]
        static let fallbackMinutes = 60
    }

    private var scheduledNotificationIDs: [String] {
        didSet { defaults.set(scheduledNotificationIDs, forKey: UserDefaultsKeys.scheduledNotificationIDs) }
    }

    // UserDefaults keys
    private struct UserDefaultsKeys {
        static let parkedLatitude = "parkedLatitude"
        static let parkedLongitude = "parkedLongitude"
        static let parkedTimestamp = "parkedTimestamp"
        static let parkedStreetName = "parkedStreetName"
        static let notificationLeadMinutes = "notificationLeadMinutes"
        static let notificationLeadMinutesSet = "notificationLeadMinutesSet"
        static let scheduledNotificationIDs = "scheduledNotificationIDs"
    }

    private let defaults: UserDefaults

    private init() {
        self.defaults = .standard
        self.scheduledNotificationIDs = defaults.stringArray(forKey: UserDefaultsKeys.scheduledNotificationIDs) ?? []
    }

    /// Injectable initializer for testing
    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.scheduledNotificationIDs = defaults.stringArray(forKey: UserDefaultsKeys.scheduledNotificationIDs) ?? []
    }

    // MARK: - Properties

    /// Check if a car is currently parked
    var isCarParked: Bool {
        return defaults.object(forKey: UserDefaultsKeys.parkedLatitude) != nil
    }

    /// Get the parked car location
    var parkedLocation: CLLocationCoordinate2D? {
        guard let lat = defaults.object(forKey: UserDefaultsKeys.parkedLatitude) as? Double,
              let lon = defaults.object(forKey: UserDefaultsKeys.parkedLongitude) as? Double else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Get the time the car was parked
    var parkedTime: Date? {
        guard let timestamp = defaults.object(forKey: UserDefaultsKeys.parkedTimestamp) as? Double else {
            return nil
        }

        return Date(timeIntervalSince1970: timestamp)
    }

    /// Get street name where car is parked
    var parkedStreetName: String? {
        return defaults.string(forKey: UserDefaultsKeys.parkedStreetName)
    }

    var availableNotificationLeadMinutes: [Int] {
        NotificationLeadOptions.supportedMinutes
    }

    /// Notification lead time in minutes (legacy single-select API, default: 60)
    var notificationLeadMinutes: Int {
        get {
            notificationLeadMinutesSet.first ?? NotificationLeadOptions.fallbackMinutes
        }
        set {
            let normalized = sanitizeLeadMinutesSet([newValue])
            defaults.set(normalized.first ?? NotificationLeadOptions.fallbackMinutes, forKey: UserDefaultsKeys.notificationLeadMinutes)
            defaults.set(normalized, forKey: UserDefaultsKeys.notificationLeadMinutesSet)
        }
    }

    /// Notification lead times in minutes (multi-select API)
    var notificationLeadMinutesSet: [Int] {
        get {
            if let stored = defaults.array(forKey: UserDefaultsKeys.notificationLeadMinutesSet) as? [Int] {
                let normalized = sanitizeLeadMinutesSet(stored)
                if normalized != stored {
                    defaults.set(normalized, forKey: UserDefaultsKeys.notificationLeadMinutesSet)
                }
                defaults.set(normalized.first ?? NotificationLeadOptions.fallbackMinutes, forKey: UserDefaultsKeys.notificationLeadMinutes)
                return normalized
            }

            // Migrate legacy single value to a normalized set.
            let legacy = defaults.integer(forKey: UserDefaultsKeys.notificationLeadMinutes)
            let normalized = sanitizeLeadMinutesSet([legacy])
            defaults.set(normalized, forKey: UserDefaultsKeys.notificationLeadMinutesSet)
            defaults.set(normalized.first ?? NotificationLeadOptions.fallbackMinutes, forKey: UserDefaultsKeys.notificationLeadMinutes)
            return normalized
        }
        set {
            let normalized = sanitizeLeadMinutesSet(newValue)
            defaults.set(normalized, forKey: UserDefaultsKeys.notificationLeadMinutesSet)
            defaults.set(normalized.first ?? NotificationLeadOptions.fallbackMinutes, forKey: UserDefaultsKeys.notificationLeadMinutes)
        }
    }

    /// Save parked car location
    /// - Parameters:
    ///   - location: The location where the car is parked
    ///   - streetName: The name of the street (optional)
    func parkCar(at location: CLLocationCoordinate2D, streetName: String? = nil) {
        // Save to UserDefaults
        defaults.set(location.latitude, forKey: UserDefaultsKeys.parkedLatitude)
        defaults.set(location.longitude, forKey: UserDefaultsKeys.parkedLongitude)
        defaults.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.parkedTimestamp)

        if let streetName = streetName {
            defaults.set(streetName, forKey: UserDefaultsKeys.parkedStreetName)
        }

        // Notify observers that parked car status has changed
        NotificationCenter.default.post(name: .parkedCarStatusDidChange, object: nil)
    }

    /// Update the location of the parked car (for manual pin adjustment)
    func updateParkedLocation(to newLocation: CLLocationCoordinate2D) {
        guard isCarParked else { return }

        defaults.set(newLocation.latitude, forKey: UserDefaultsKeys.parkedLatitude)
        defaults.set(newLocation.longitude, forKey: UserDefaultsKeys.parkedLongitude)

        // Notify observers that parked car status has changed
        NotificationCenter.default.post(name: .parkedCarStatusDidChange, object: nil)
    }

    /// Clear parked car data and cancel notifications
    func clearParkedCar() {
        // Remove from UserDefaults
        defaults.removeObject(forKey: UserDefaultsKeys.parkedLatitude)
        defaults.removeObject(forKey: UserDefaultsKeys.parkedLongitude)
        defaults.removeObject(forKey: UserDefaultsKeys.parkedTimestamp)
        defaults.removeObject(forKey: UserDefaultsKeys.parkedStreetName)

        // Cancel any scheduled notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: scheduledNotificationIDs
        )
        scheduledNotificationIDs.removeAll()

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
                #if DEBUG
                print("Notification permission denied or error: \(String(describing: error))")
                #endif
                return
            }

            // Deduplicate: remove any existing sweeping reminders before scheduling new ones
            let existingIDs = self.scheduledNotificationIDs.filter { $0.hasPrefix(NotificationIDs.sweepingReminderPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: existingIDs)
            self.scheduledNotificationIDs.removeAll()

            let selectedLeadMinutes = self.notificationLeadMinutesSet.sorted(by: >)
            let now = Date()
            var hasScheduledRequest = false

            for leadMinutes in selectedLeadMinutes {
                let leadSeconds = TimeInterval(leadMinutes * 60)
                let notificationTime = sweepingTime.addingTimeInterval(-leadSeconds)
                guard notificationTime > now else { continue }

                hasScheduledRequest = true

                let content = UNMutableNotificationContent()
                content.title = "Street Sweeping Alert"
                content.body = "Street sweeping at \(streetName) starts at \(self.formatTime(sweepingTime)). Reminder: \(self.formatLeadTime(leadMinutes)) before."
                content.sound = .default

                let triggerDate = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: notificationTime
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

                let notificationID = "\(NotificationIDs.sweepingReminderPrefix)\(Int(sweepingTime.timeIntervalSince1970))_\(leadMinutes)"
                let request = UNNotificationRequest(
                    identifier: notificationID,
                    content: content,
                    trigger: trigger
                )

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        #if DEBUG
                        print("Error scheduling notification: \(error)")
                        #endif
                    } else {
                        self.scheduledNotificationIDs.append(notificationID)
                    }
                }
            }

            if !hasScheduledRequest {
                #if DEBUG
                print("Warning: No reminders scheduled because all selected lead times are in the past")
                #endif
            }
        }
    }

    // MARK: - Private Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatLeadTime(_ minutes: Int) -> String {
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
        return "\(minutes) minutes"
    }

    private func sanitizeLeadMinutesSet(_ values: [Int]) -> [Int] {
        let allowed = Set(NotificationLeadOptions.supportedMinutes)
        let normalized = Array(Set(values.filter { allowed.contains($0) })).sorted()
        return normalized.isEmpty ? [NotificationLeadOptions.fallbackMinutes] : normalized
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let parkedCarStatusDidChange = Notification.Name("parkedCarStatusDidChange")
}
