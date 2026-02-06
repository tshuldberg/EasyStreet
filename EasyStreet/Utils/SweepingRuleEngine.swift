import Foundation
import CoreLocation

/// Core logic engine for determining street sweeping rules for a location
class SweepingRuleEngine {
    // Shared instance
    static let shared = SweepingRuleEngine()

    private let holidayCalculator = HolidayCalculator()
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Find the street segment for a given location and analyze its sweeping rules
    /// - Parameters:
    ///   - location: The location to check (typically where car is parked)
    ///   - completion: Completion handler with sweeping status result
    func analyzeSweeperStatus(for location: CLLocationCoordinate2D, completion: @escaping (SweepingStatus) -> Void) {
        let segment = StreetRepository.shared.findSegment(near: location)
        completion(determineStatus(for: segment, at: Date()))
    }
    
    /// Testable method: determine sweeping status for a segment at a given time.
    func determineStatus(for segment: StreetSegment?, at now: Date) -> SweepingStatus {
        guard let segment = segment else { return .noData }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        // Check if sweeping is today
        if let todayRule = segment.rules.first(where: { rule in
            rule.dayOfWeek == weekday && rule.appliesTo(date: now)
        }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"

            guard let startTime = formatter.date(from: todayRule.startTime) else {
                return .unknown
            }

            guard let sweepingDateTime = calendar.date(
                bySettingHour: calendar.component(.hour, from: startTime),
                minute: calendar.component(.minute, from: startTime),
                second: 0, of: now
            ) else {
                return .unknown
            }

            if sweepingDateTime < now {
                return .safe
            } else {
                let hoursRemaining = sweepingDateTime.timeIntervalSince(now) / 3600
                if hoursRemaining < 1 {
                    return .imminent(time: sweepingDateTime, streetName: segment.streetName)
                } else {
                    return .today(time: sweepingDateTime, streetName: segment.streetName)
                }
            }
        } else {
            let (nextDate, _) = segment.nextSweeping(from: now)
            if let nextDate = nextDate {
                return .upcoming(time: nextDate, streetName: segment.streetName)
            } else {
                return .safe
            }
        }
    }

    /// Check if a given date is a holiday in San Francisco
    /// - Parameter date: The date to check
    /// - Returns: Boolean indicating if it's a holiday
    func isHoliday(_ date: Date) -> Bool {
        return holidayCalculator.isHoliday(date)
    }
}

/// Result of analyzing the street sweeping status for a location
enum SweepingStatus {
    /// No data available for this location
    case noData
    
    /// No imminent sweeping, safe to park
    case safe
    
    /// Sweeping scheduled for today but not in the immediate future
    case today(time: Date, streetName: String)
    
    /// Sweeping imminent (less than 1 hour away)
    case imminent(time: Date, streetName: String)
    
    /// Next sweeping is in the future (not today)
    case upcoming(time: Date, streetName: String)
    
    /// Could not determine status
    case unknown
} 