import Foundation
import CoreLocation
import MapKit

// MARK: - Data Models for Street Sweeping

/// Represents a street sweeping rule for a specific street segment
struct SweepingRule: Codable {
    let dayOfWeek: Int // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    let startTime: String // 24-hour format "HH:MM"
    let endTime: String // 24-hour format "HH:MM"
    let weeksOfMonth: [Int] // e.g., [1, 3] for 1st and 3rd weeks, or [] if every week
    let applyOnHolidays: Bool // true if sweeping occurs even on holidays
    
    // Computed property to get user-friendly day name
    var dayName: String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[dayOfWeek - 1]
    }
    
    // Format times for display (12-hour format with AM/PM)
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let startDate = formatter.date(from: startTime),
              let endDate = formatter.date(from: endTime) else {
            return "\(startTime) - \(endTime)"
        }
        
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    // Return a text description of which weeks this applies to
    var weeksDescription: String {
        if weeksOfMonth.isEmpty {
            return "Every week"
        }
        
        let ordinals = ["1st", "2nd", "3rd", "4th", "5th"]
        let weekNames = weeksOfMonth.map { ordinals[$0 - 1] }
        return weekNames.joined(separator: " & ") + " weeks of the month"
    }
    
    // Check if this rule applies to the given date
    func appliesTo(date: Date) -> Bool {
        let calendar = Calendar.current
        
        // Check day of week
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday, etc.
        if weekday != dayOfWeek {
            return false
        }
        
        // Check week of month if specified
        if !weeksOfMonth.isEmpty {
            let weekOfMonth = calendar.component(.weekOfMonth, from: date)
            if !weeksOfMonth.contains(weekOfMonth) {
                return false
            }
        }
        
        // Check holiday
        // If the rule states it does not apply on holidays, and it is a holiday, then it does not apply.
        if !self.applyOnHolidays && SweepingRuleEngine.shared.isHoliday(date) {
            return false
        }
        
        // If applyOnHolidays is true, it applies regardless of holiday status.
        // If applyOnHolidays is false and it's NOT a holiday, it applies.
        return true
    }
}

/// Represents a street segment with sweeping rules
struct StreetSegment: Codable, Identifiable {
    let id: String
    let streetName: String
    let coordinates: [[Double]] // Array of [latitude, longitude] pairs
    let rules: [SweepingRule]
    
    // Computed property to convert coordinates to MKPolyline
    var polyline: MKPolyline {
        let points = coordinates.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
        return MKPolyline(coordinates: points, count: points.count)
    }
    
    // Get the nearest upcoming sweeping for this segment
    func nextSweeping(from referenceDate: Date = Date()) -> (Date?, SweepingRule?) {
        let calendar = Calendar.current
        var earliestNextSweepDate: Date? = nil
        var associatedRule: SweepingRule? = nil

        for rule in rules {
            // Start checking from tomorrow relative to the referenceDate
            guard let startDateToCheck = calendar.date(byAdding: .day, value: 1, to: referenceDate) else { continue }
            
            for dayOffset in 0..<180 { // Check for the next ~6 months
                guard let dateToCheck = calendar.date(byAdding: .day, value: dayOffset, to: startDateToCheck) else { continue }

                if rule.appliesTo(date: dateToCheck) {
                    // Construct the full sweeping date and time
                    let components = rule.startTime.split(separator: ":").map { Int($0) ?? 0 }
                    guard components.count == 2 else { continue }
                    
                    let hour = components[0]
                    let minute = components[1]
                    
                    if let sweepDateTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dateToCheck) {
                        if earliestNextSweepDate == nil || sweepDateTime < earliestNextSweepDate! {
                            earliestNextSweepDate = sweepDateTime
                            associatedRule = rule
                        }
                        // Since we found an applicable date for this rule,
                        // and we are iterating chronologically for this rule, this is the soonest for this rule.
                        // Break from dayOffset loop to check the next rule.
                        break
                    }
                }
            }
        }
        return (earliestNextSweepDate, associatedRule)
    }
    
    // Check if sweeping is scheduled for today
    func hasSweeperToday() -> Bool {
        let today = Date()
        return rules.contains { rule in
            rule.appliesTo(date: today)
        }
    }

    /// Color status for map display
    enum MapColorStatus: Equatable {
        case red       // Sweeping today
        case orange    // Sweeping tomorrow
        case yellow    // Sweeping within 2-3 days
        case green     // No sweeping soon
    }

    func mapColorStatus() -> MapColorStatus {
        if hasSweeperToday() { return .red }

        let cal = Calendar.current
        let today = Date()
        for dayOffset in 1...3 {
            guard let futureDate = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            if rules.contains(where: { $0.appliesTo(date: futureDate) }) {
                return dayOffset == 1 ? .orange : .yellow
            }
        }

        return .green
    }
}

/// Manager class for handling street sweeping data
class StreetSweepingDataManager {
    static let shared = StreetSweepingDataManager()
    
    private var allSegments: [StreetSegment] = []
    private var isLoaded = false
    private let dataFileName = "sweeping_data_sf.json"
    
    private init() {
        // Private initializer for singleton pattern
    }
    
    /// Load street sweeping data from the bundled JSON file
    /// The JSON file should be an array of StreetSegment objects.
    /// Example structure for sweeping_data_sf.json:
    /// [ 
    ///   { "id": "segment1", "streetName": "Main St", 
    ///     "coordinates": [[37.77,-122.41],[37.78,-122.42]], 
    ///     "rules": [ { "dayOfWeek": 2, "startTime": "09:00", "endTime": "11:00", "weeksOfMonth": [1,3], "applyOnHolidays": false } ] 
    ///   }, ...
    /// ]
    func loadData(completion: @escaping (Bool) -> Void) {
        guard !isLoaded else {
        completion(true)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            guard let url = Bundle.main.url(forResource: self.dataFileName, withExtension: nil) else {
                print("Error: \(self.dataFileName) not found in bundle.")
                // Fallback to sample data for UI testing if main file not found
                #if DEBUG
                print("Loading SAMPLE data as fallback.")
                self.loadSampleData()
                self.isLoaded = true
                DispatchQueue.main.async { completion(true) }
                #else
                DispatchQueue.main.async { completion(false) }
                #endif
                return
            }
            
            do {
                let jsonData = try Data(contentsOf: url)
                self.allSegments = try JSONDecoder().decode([StreetSegment].self, from: jsonData)
                self.isLoaded = true
                print("Successfully loaded \(self.allSegments.count) segments from \(self.dataFileName)")
                DispatchQueue.main.async { completion(true) }
            } catch {
                print("Error loading or decoding \(self.dataFileName): \(error)")
                // Fallback to sample data for UI testing if decoding fails
                #if DEBUG
                print("Loading SAMPLE data due to error: \(error.localizedDescription)")
                self.loadSampleData()
                self.isLoaded = true // Consider it loaded with samples for debug
                DispatchQueue.main.async { completion(true) }
                #else
                DispatchQueue.main.async { completion(false) }
                #endif
            }
        }
    }
    
    /// Get segments that are visible in the given map rect
    func segments(in mapRect: MKMapRect) -> [StreetSegment] {
        guard isLoaded else { return [] }
        // A simple AABB (Axis-Aligned Bounding Box) intersection check
        return allSegments.filter { segment in
            mapRect.intersects(segment.polyline.boundingMapRect)
        }
    }
    
    /// Find the segment whose polyline is closest to the given location.
    /// This is a simplified approach: it finds the segment with a point in its polyline closest to the location.
    /// For more accuracy, point-to-line-segment distance would be needed.
    func findSegment(near location: CLLocationCoordinate2D) -> StreetSegment? {
        guard isLoaded, !allSegments.isEmpty else { return nil }
        
        let targetMapPoint = MKMapPoint(location)
        var closestSegment: StreetSegment? = nil
        var minDistanceSquared: Double = Double.greatestFiniteMagnitude
        
        for segment in allSegments {
            // A quick check using the bounding box first can be an optimization for large datasets
            if !segment.polyline.boundingMapRect.contains(targetMapPoint) {
                // If not looking for exact containment, check distance even if not inside bounding box for proximity.
                // For simplicity here, we iterate all segments. Add a broader bounding box check if performance is an issue.
            }

            for pointCoordinate in segment.coordinates {
                let polylinePoint = CLLocationCoordinate2D(latitude: pointCoordinate[0], longitude: pointCoordinate[1])
                let mapPoint = MKMapPoint(polylinePoint)
                
                // Using squared distance to avoid sqrt, as we only need it for comparison
                let dx = targetMapPoint.x - mapPoint.x
                let dy = targetMapPoint.y - mapPoint.y
                let distanceSquared = dx * dx + dy * dy
                
                if distanceSquared < minDistanceSquared {
                    minDistanceSquared = distanceSquared
                    closestSegment = segment
                }
            }
        }
        
        // Optional: Add a threshold for max distance if you only want very close segments
        // For example: if sqrt(minDistanceSquared) > MAX_ACCEPTABLE_DISTANCE_IN_MAP_UNITS { return nil }
        
        return closestSegment
    }
    
    // MARK: - Private Methods
    
    private func loadSampleData() {
        // Create a few sample segments for testing UI
        let sampleRule1 = SweepingRule(
            dayOfWeek: 2, // Monday
            startTime: "09:00",
            endTime: "11:00",
            weeksOfMonth: [1, 3], // 1st and 3rd weeks
            applyOnHolidays: false
        )
        
        let sampleRule2 = SweepingRule(
            dayOfWeek: 4, // Wednesday
            startTime: "13:00",
            endTime: "15:00",
            weeksOfMonth: [], // Every week
            applyOnHolidays: true
        )
        
        // Sample coordinates for Market Street in SF (simplified)
        let marketStreetCoords = [
            [37.7932, -122.3964], // Near Embarcadero
            [37.7925, -122.3977],
            [37.7915, -122.3994],
            [37.7909, -122.4015]  // Towards downtown
        ]
        
        let segment1 = StreetSegment(
            id: "market-st-1",
            streetName: "Market Street",
            coordinates: marketStreetCoords,
            rules: [sampleRule1]
        )
        
        // Sample coordinates for Mission Street in SF (simplified)
        let missionStreetCoords = [
            [37.7885, -122.4018], // Near downtown
            [37.7873, -122.4031],
            [37.7861, -122.4042],
            [37.7850, -122.4060]  // Towards Mission District
        ]
        
        let segment2 = StreetSegment(
            id: "mission-st-1",
            streetName: "Mission Street",
            coordinates: missionStreetCoords,
            rules: [sampleRule2]
        )
        
        allSegments = [segment1, segment2]
    }
} 