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
        // Get the street segment for this location
        guard let segment = StreetRepository.shared.findSegment(near: location) else {
            completion(.noData)
            return
        }
        
        // Check if sweeping is today
        if segment.hasSweeperToday() {
            // Find the rule that applies to today
            let today = Date()
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: today)
            
            if let todayRule = segment.rules.first(where: { rule in
                rule.dayOfWeek == weekday && rule.appliesTo(date: today)
            }) {
                // Parse the rule times to get actual start time
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                
                let startTimeString = todayRule.startTime
                guard let startTime = formatter.date(from: startTimeString) else {
                    completion(.unknown)
                    return
                }
                
                // Set time components only (keep today's date)
                let sweepingDateTime = calendar.date(bySettingHour: calendar.component(.hour, from: startTime),
                                                     minute: calendar.component(.minute, from: startTime),
                                                     second: 0,
                                                     of: today)!
                
                // Check if we're past today's sweeping
                if sweepingDateTime < today {
                    // Sweeping already happened today, so it's safe to park
                    completion(.safe)
                } else {
                    // Sweeping is later today
                    let timeRemaining = sweepingDateTime.timeIntervalSince(today)
                    let hoursRemaining = timeRemaining / 3600
                    
                    if hoursRemaining < 1 {
                        // Less than 1 hour until sweeping
                        completion(.imminent(time: sweepingDateTime, streetName: segment.streetName))
                    } else {
                        // Sweeping today but not imminent
                        completion(.today(time: sweepingDateTime, streetName: segment.streetName))
                    }
                }
            } else {
                // This shouldn't happen if hasSweeperToday is accurate
                completion(.safe)
            }
        } else {
            // Check for next upcoming sweeping
            let (nextDate, _) = segment.nextSweeping()
            if let nextDate = nextDate {
                completion(.upcoming(time: nextDate, streetName: segment.streetName))
            } else {
                completion(.safe)
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