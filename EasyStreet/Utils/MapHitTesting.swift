import MapKit

struct MapHitTesting {

    /// Perpendicular distance from a point to a line segment, in meters.
    static func perpendicularDistance(from point: MKMapPoint, toLineFrom a: MKMapPoint, to b: MKMapPoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSq = dx * dx + dy * dy

        guard lengthSq > 0 else {
            return point.distance(to: a)
        }

        var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSq
        t = max(0, min(1, t))

        let projection = MKMapPoint(x: a.x + t * dx, y: a.y + t * dy)
        return point.distance(to: projection)
    }

    /// Priority for color subtitles: lower number = more urgent.
    private static func colorPriority(_ subtitle: String?) -> Int {
        switch subtitle {
        case "red": return 0
        case "orange": return 1
        case "yellow": return 2
        case "green": return 3
        default: return 4
        }
    }

    /// Find the closest polyline overlay to a given map point within a threshold.
    ///
    /// When multiple polylines overlap (e.g., L/R sides of the same street with
    /// identical coordinates), prefers the one with the most urgent color
    /// (red > orange > yellow > green) so the detail popup matches what the user sees.
    static func findClosestPolyline(
        tapMapPoint: MKMapPoint,
        overlays: [MKOverlay],
        thresholdMeters: Double
    ) -> MKPolyline? {
        // Collect (polyline, minDistance) for all candidates within threshold
        var candidates: [(polyline: MKPolyline, distance: Double)] = []

        for overlay in overlays {
            guard let polyline = overlay as? MKPolyline else { continue }
            let pointCount = polyline.pointCount
            guard pointCount >= 2 else { continue }
            let points = polyline.points()

            var minDist = Double.greatestFiniteMagnitude
            for i in 0..<(pointCount - 1) {
                let dist = perpendicularDistance(from: tapMapPoint, toLineFrom: points[i], to: points[i + 1])
                if dist < minDist {
                    minDist = dist
                }
            }

            if minDist < thresholdMeters {
                candidates.append((polyline, minDist))
            }
        }

        guard !candidates.isEmpty else { return nil }

        // Find the minimum distance
        let bestDistance = candidates.map(\.distance).min()!

        // Collect all polylines within 5 meters of the best (handles overlapping L/R sides)
        let tolerance = 5.0
        let nearCandidates = candidates.filter { $0.distance <= bestDistance + tolerance }

        // Among near-equal candidates, prefer the most urgent color
        return nearCandidates.min(by: { colorPriority($0.polyline.subtitle) < colorPriority($1.polyline.subtitle) })?.polyline
    }
}
