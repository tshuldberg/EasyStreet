import Foundation
import MapKit
import CoreLocation

/// Thin data-access layer over street sweeping data.
/// Tries SQLite first; falls back to in-memory JSON if the DB is missing.
class StreetRepository {
    static let shared = StreetRepository()

    private let dataManager = StreetSweepingDataManager.shared
    private var useSQLite = false

    private init() {}

    /// Load the street sweeping dataset.
    func loadData(completion: @escaping (Bool) -> Void) {
        // Try opening SQLite database
        do {
            try DatabaseManager.shared.open()
            useSQLite = true
            print("StreetRepository: using SQLite backing store")
            completion(true)
        } catch {
            // Fall back to JSON in-memory data manager
            print("StreetRepository: SQLite unavailable (\(error.localizedDescription)), falling back to JSON")
            useSQLite = false
            dataManager.loadData(completion: completion)
        }
    }

    /// Return segments whose bounding rect intersects the given map rect.
    func segments(in mapRect: MKMapRect) -> [StreetSegment] {
        guard useSQLite else {
            return dataManager.segments(in: mapRect)
        }

        let topLeft = MKMapPoint(x: mapRect.minX, y: mapRect.minY).coordinate
        let bottomRight = MKMapPoint(x: mapRect.maxX, y: mapRect.maxY).coordinate

        let minLat = min(topLeft.latitude, bottomRight.latitude)
        let maxLat = max(topLeft.latitude, bottomRight.latitude)
        let minLon = min(topLeft.longitude, bottomRight.longitude)
        let maxLon = max(topLeft.longitude, bottomRight.longitude)

        let sql = """
            SELECT s.id, s.street_name, s.coordinates,
                   r.day_of_week, r.start_time, r.end_time, r.weeks_of_month, r.apply_on_holidays
            FROM street_segments s
            LEFT JOIN sweeping_rules r ON r.segment_id = s.id
            WHERE s.lat_max >= ? AND s.lat_min <= ?
              AND s.lng_max >= ? AND s.lng_min <= ?
            """

        var segmentMap: [String: (id: String, streetName: String, coordinates: [[Double]], rules: [SweepingRule])] = [:]

        do {
            try DatabaseManager.shared.query(sql, parameters: [minLat, maxLat, minLon, maxLon]) { stmt in
                let id = DatabaseManager.string(from: stmt, column: 0)
                let streetName = DatabaseManager.string(from: stmt, column: 1)
                let coordsJSON = DatabaseManager.string(from: stmt, column: 2)

                if segmentMap[id] == nil {
                    let coordinates = parseCoordinatesJSON(coordsJSON)
                    segmentMap[id] = (id: id, streetName: streetName, coordinates: coordinates, rules: [])
                }

                // Parse rule if present (LEFT JOIN may yield NULLs)
                let dayOfWeek = DatabaseManager.int(from: stmt, column: 3)
                if dayOfWeek > 0 {
                    let startTime = DatabaseManager.string(from: stmt, column: 4)
                    let endTime = DatabaseManager.string(from: stmt, column: 5)
                    let weeksJSON = DatabaseManager.string(from: stmt, column: 6)
                    let applyOnHolidays = DatabaseManager.int(from: stmt, column: 7) != 0

                    let weeksOfMonth = parseWeeksJSON(weeksJSON)
                    let rule = SweepingRule(
                        dayOfWeek: dayOfWeek,
                        startTime: startTime,
                        endTime: endTime,
                        weeksOfMonth: weeksOfMonth,
                        applyOnHolidays: applyOnHolidays
                    )
                    segmentMap[id]?.rules.append(rule)
                }
            }
        } catch {
            print("StreetRepository: SQLite query failed: \(error)")
            return []
        }

        return segmentMap.values.map { entry in
            StreetSegment(id: entry.id, streetName: entry.streetName,
                         coordinates: entry.coordinates, rules: entry.rules)
        }
    }

    /// Find the segment closest to a coordinate.
    func findSegment(near location: CLLocationCoordinate2D) -> StreetSegment? {
        guard useSQLite else {
            return dataManager.findSegment(near: location)
        }

        let radius = 0.005
        let minLat = location.latitude - radius
        let maxLat = location.latitude + radius
        let minLon = location.longitude - radius
        let maxLon = location.longitude + radius

        let sql = """
            SELECT s.id, s.street_name, s.coordinates,
                   r.day_of_week, r.start_time, r.end_time, r.weeks_of_month, r.apply_on_holidays
            FROM street_segments s
            LEFT JOIN sweeping_rules r ON r.segment_id = s.id
            WHERE s.lat_max >= ? AND s.lat_min <= ?
              AND s.lng_max >= ? AND s.lng_min <= ?
            """

        var segmentMap: [String: (id: String, streetName: String, coordinates: [[Double]], rules: [SweepingRule])] = [:]

        do {
            try DatabaseManager.shared.query(sql, parameters: [minLat, maxLat, minLon, maxLon]) { stmt in
                let id = DatabaseManager.string(from: stmt, column: 0)
                let streetName = DatabaseManager.string(from: stmt, column: 1)
                let coordsJSON = DatabaseManager.string(from: stmt, column: 2)

                if segmentMap[id] == nil {
                    let coordinates = parseCoordinatesJSON(coordsJSON)
                    segmentMap[id] = (id: id, streetName: streetName, coordinates: coordinates, rules: [])
                }

                let dayOfWeek = DatabaseManager.int(from: stmt, column: 3)
                if dayOfWeek > 0 {
                    let startTime = DatabaseManager.string(from: stmt, column: 4)
                    let endTime = DatabaseManager.string(from: stmt, column: 5)
                    let weeksJSON = DatabaseManager.string(from: stmt, column: 6)
                    let applyOnHolidays = DatabaseManager.int(from: stmt, column: 7) != 0

                    let rule = SweepingRule(
                        dayOfWeek: dayOfWeek, startTime: startTime, endTime: endTime,
                        weeksOfMonth: parseWeeksJSON(weeksJSON), applyOnHolidays: applyOnHolidays
                    )
                    segmentMap[id]?.rules.append(rule)
                }
            }
        } catch {
            print("StreetRepository: findSegment SQLite query failed: \(error)")
            return nil
        }

        let targetMapPoint = MKMapPoint(location)
        var closestSegment: StreetSegment?
        var minDistSq = Double.greatestFiniteMagnitude

        for entry in segmentMap.values {
            for coord in entry.coordinates {
                let pt = MKMapPoint(CLLocationCoordinate2D(latitude: coord[0], longitude: coord[1]))
                let dx = targetMapPoint.x - pt.x
                let dy = targetMapPoint.y - pt.y
                let distSq = dx * dx + dy * dy
                if distSq < minDistSq {
                    minDistSq = distSq
                    closestSegment = StreetSegment(
                        id: entry.id, streetName: entry.streetName,
                        coordinates: entry.coordinates, rules: entry.rules
                    )
                }
            }
        }

        return closestSegment
    }

    /// O(1) lookup by segment ID.
    func segment(byID id: String) -> StreetSegment? {
        guard useSQLite else {
            return dataManager.segment(byID: id)
        }

        let sql = """
            SELECT s.id, s.street_name, s.coordinates,
                   r.day_of_week, r.start_time, r.end_time, r.weeks_of_month, r.apply_on_holidays
            FROM street_segments s
            LEFT JOIN sweeping_rules r ON r.segment_id = s.id
            WHERE s.id = ?
            """

        var result: StreetSegment?
        var rules: [SweepingRule] = []
        var segInfo: (id: String, streetName: String, coordinates: [[Double]])?

        do {
            try DatabaseManager.shared.query(sql, parameters: [id]) { stmt in
                if segInfo == nil {
                    let segID = DatabaseManager.string(from: stmt, column: 0)
                    let streetName = DatabaseManager.string(from: stmt, column: 1)
                    let coordsJSON = DatabaseManager.string(from: stmt, column: 2)
                    segInfo = (id: segID, streetName: streetName, coordinates: parseCoordinatesJSON(coordsJSON))
                }

                let dayOfWeek = DatabaseManager.int(from: stmt, column: 3)
                if dayOfWeek > 0 {
                    let startTime = DatabaseManager.string(from: stmt, column: 4)
                    let endTime = DatabaseManager.string(from: stmt, column: 5)
                    let weeksJSON = DatabaseManager.string(from: stmt, column: 6)
                    let applyOnHolidays = DatabaseManager.int(from: stmt, column: 7) != 0

                    rules.append(SweepingRule(
                        dayOfWeek: dayOfWeek, startTime: startTime, endTime: endTime,
                        weeksOfMonth: parseWeeksJSON(weeksJSON), applyOnHolidays: applyOnHolidays
                    ))
                }
            }
        } catch {
            print("StreetRepository: segment(byID:) SQLite query failed: \(error)")
            return nil
        }

        if let info = segInfo {
            result = StreetSegment(id: info.id, streetName: info.streetName,
                                  coordinates: info.coordinates, rules: rules)
        }

        return result
    }

    // MARK: - Private Helpers

    private func parseCoordinatesJSON(_ json: String) -> [[Double]] {
        guard let data = json.data(using: .utf8),
              let coords = try? JSONSerialization.jsonObject(with: data) as? [[Double]] else {
            return []
        }
        return coords
    }

    private func parseWeeksJSON(_ json: String) -> [Int] {
        guard let data = json.data(using: .utf8),
              let weeks = try? JSONSerialization.jsonObject(with: data) as? [Int] else {
            return []
        }
        return weeks
    }
}
