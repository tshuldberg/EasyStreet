import Foundation
import MapKit
import CoreLocation

/// Thin data-access layer over street sweeping data.
/// Tries SQLite first; falls back to in-memory JSON if the DB is missing.
class StreetRepository {
    static let shared = StreetRepository()

    private let dataManager = StreetSweepingDataManager.shared
    private var useSQLite = false
    private(set) var dataSourceInfo: String?
    private(set) var dataBuildDate: String?
    private static let cacheLimit = 1000
    private var coordinateCache: [String: [[Double]]] = [:]

    private init() {}

    /// Load the street sweeping dataset.
    func loadData(completion: @escaping (Bool) -> Void) {
        // Try opening SQLite database
        do {
            try DatabaseManager.shared.open()
            useSQLite = true
            var count = 0
            try? DatabaseManager.shared.query("SELECT COUNT(*) FROM street_segments") { stmt in
                count = DatabaseManager.int(from: stmt, column: 0)
            }
            #if DEBUG
            print("[EasyStreet] StreetRepository: using SQLite backing store (\(count) segments)")
            #endif
            dataSourceInfo = DatabaseManager.shared.metadataValue(for: "csv_source")
            dataBuildDate = DatabaseManager.shared.metadataValue(for: "build_date")
            DispatchQueue.main.async { completion(true) }
        } catch {
            // Fall back to JSON in-memory data manager
            #if DEBUG
            print("[EasyStreet] StreetRepository: SQLite unavailable (\(error.localizedDescription)), falling back to JSON")
            #endif
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

        #if DEBUG
        print("[EasyStreet] segments(in:) bbox: lat[\(minLat)...\(maxLat)], lon[\(minLon)...\(maxLon)]")
        #endif

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
                    let coordinates = coordinateCache[id] ?? parseCoordinatesJSON(coordsJSON)
                    if coordinateCache[id] == nil {
                        if coordinateCache.count >= StreetRepository.cacheLimit {
                            coordinateCache.removeAll()
                        }
                        coordinateCache[id] = coordinates
                    }
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
            #if DEBUG
            print("[EasyStreet] StreetRepository: SQLite query failed: \(error)")
            #endif
            return []
        }

        #if DEBUG
        print("[EasyStreet] segments(in:) returned \(segmentMap.count) segments")

        // Log sample coordinate details for first 3 segments
        for entry in segmentMap.values.prefix(3) {
            print("[EasyStreet]   sample: id=\(entry.id), coords=\(entry.coordinates.count), rules=\(entry.rules.count)")
        }
        #endif

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
            #if DEBUG
            print("StreetRepository: findSegment SQLite query failed: \(error)")
            #endif
            return nil
        }

        let targetMapPoint = MKMapPoint(location)
        var closestSegment: StreetSegment?
        var minDistSq = Double.greatestFiniteMagnitude

        for entry in segmentMap.values {
            for coord in entry.coordinates {
                guard coord.count >= 2 else { continue }
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
            #if DEBUG
            print("StreetRepository: segment(byID:) SQLite query failed: \(error)")
            #endif
            return nil
        }

        if let info = segInfo {
            result = StreetSegment(id: info.id, streetName: info.streetName,
                                  coordinates: info.coordinates, rules: rules)
        }

        return result
    }

    /// Search streets by name for offline address lookup.
    func searchStreets(query: String, limit: Int = 10) -> [(streetName: String, coordinate: CLLocationCoordinate2D)] {
        guard useSQLite, !query.isEmpty else { return [] }

        let sql = """
            SELECT street_name,
                   AVG((lat_min + lat_max) / 2.0) AS avg_lat,
                   AVG((lng_min + lng_max) / 2.0) AS avg_lng
            FROM street_segments
            WHERE street_name LIKE ?
            GROUP BY street_name
            ORDER BY street_name
            LIMIT ?
            """

        var results: [(streetName: String, coordinate: CLLocationCoordinate2D)] = []

        do {
            try DatabaseManager.shared.query(sql, parameters: ["%\(query)%", limit]) { stmt in
                let name = DatabaseManager.string(from: stmt, column: 0)
                let lat = DatabaseManager.double(from: stmt, column: 1)
                let lng = DatabaseManager.double(from: stmt, column: 2)
                results.append((streetName: name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)))
            }
        } catch {
            #if DEBUG
            print("[EasyStreet] StreetRepository: searchStreets failed: \(error)")
            #endif
        }

        return results
    }

    // MARK: - Private Helpers

    func parseCoordinatesJSON(_ json: String) -> [[Double]] {
        guard let data = json.data(using: .utf8),
              let coords = try? JSONSerialization.jsonObject(with: data) as? [[Double]] else {
            return []
        }
        return coords
    }

    func parseWeeksJSON(_ json: String) -> [Int] {
        guard let data = json.data(using: .utf8),
              let weeks = try? JSONSerialization.jsonObject(with: data) as? [Int] else {
            return []
        }
        return weeks
    }
}
