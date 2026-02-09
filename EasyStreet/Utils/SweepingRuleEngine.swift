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

        let todayRules = segment.rules.filter { rule in
            rule.dayOfWeek == weekday && rule.appliesTo(date: now)
        }

        var nextTodaySweep: Date?
        var parsedTodayRuleCount = 0
        var hadParseError = false

        for rule in todayRules {
            guard let (hour, minute) = parseHourMinute(rule.startTime) else {
                hadParseError = true
                continue
            }

            guard let sweepingDateTime = calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: now
            ) else {
                hadParseError = true
                continue
            }

            parsedTodayRuleCount += 1

            if sweepingDateTime >= now {
                if let existing = nextTodaySweep {
                    if sweepingDateTime < existing {
                        nextTodaySweep = sweepingDateTime
                    }
                } else {
                    nextTodaySweep = sweepingDateTime
                }
            }
        }

        if let nextTodaySweep = nextTodaySweep {
            let hoursRemaining = nextTodaySweep.timeIntervalSince(now) / 3600
            if hoursRemaining < 1 {
                return .imminent(time: nextTodaySweep, streetName: segment.streetName)
            }
            return .today(time: nextTodaySweep, streetName: segment.streetName)
        }

        if parsedTodayRuleCount == 0 && hadParseError {
            return .unknown
        }

        let (nextDate, _) = segment.nextSweeping(from: now)
        if let nextDate = nextDate {
            return .upcoming(time: nextDate, streetName: segment.streetName)
        }

        return .safe
    }

    /// Check if a given date is a holiday in San Francisco
    /// - Parameter date: The date to check
    /// - Returns: Boolean indicating if it's a holiday
    func isHoliday(_ date: Date) -> Bool {
        return holidayCalculator.isHoliday(date)
    }

    private func parseHourMinute(_ value: String) -> (Int, Int)? {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
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
