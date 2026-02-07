package com.easystreet.data.db

import com.easystreet.domain.model.BoundingBox
import com.easystreet.domain.model.LatLngPoint
import com.easystreet.domain.model.StreetSearchResult
import com.easystreet.domain.model.StreetSegment
import com.easystreet.domain.model.SweepingRule
import org.json.JSONArray
import java.time.DayOfWeek
import java.time.LocalTime

class StreetDao(private val db: StreetDatabase) {

    fun getSegmentsInViewport(
        latMin: Double,
        latMax: Double,
        lngMin: Double,
        lngMax: Double,
    ): List<StreetSegment> {
        val segments = mutableListOf<StreetSegment>()

        val cursor = db.database.rawQuery(
            """
            SELECT id, cnn, street_name, latitude_min, latitude_max,
                   longitude_min, longitude_max, coordinates
            FROM street_segments
            WHERE latitude_max >= ? AND latitude_min <= ?
              AND longitude_max >= ? AND longitude_min <= ?
            """.trimIndent(),
            arrayOf(
                latMin.toString(),
                latMax.toString(),
                lngMin.toString(),
                lngMax.toString(),
            ),
        )

        cursor.use {
            while (it.moveToNext()) {
                val segmentId = it.getLong(0)
                val cnn = it.getInt(1)
                val streetName = it.getString(2)
                val latMinDb = it.getDouble(3)
                val latMaxDb = it.getDouble(4)
                val lngMinDb = it.getDouble(5)
                val lngMaxDb = it.getDouble(6)
                val coordsJson = it.getString(7)

                val coordinates = parseCoordinates(coordsJson)
                val rules = getRulesForSegment(segmentId)

                segments.add(
                    StreetSegment(
                        id = segmentId.toString(),
                        cnn = cnn,
                        streetName = streetName,
                        coordinates = coordinates,
                        bounds = BoundingBox(latMinDb, latMaxDb, lngMinDb, lngMaxDb),
                        rules = rules,
                    )
                )
            }
        }

        return segments
    }

    fun findNearestSegment(lat: Double, lng: Double, radiusDeg: Double = 0.005): StreetSegment? {
        val segments = getSegmentsInViewport(
            lat - radiusDeg, lat + radiusDeg,
            lng - radiusDeg, lng + radiusDeg,
        )

        return segments.minByOrNull { segment ->
            segment.coordinates.minOf { point ->
                val dlat = point.latitude - lat
                val dlng = point.longitude - lng
                dlat * dlat + dlng * dlng
            }
        }
    }

    fun searchStreetsByName(query: String, limit: Int = 20): List<StreetSearchResult> {
        val results = mutableListOf<StreetSearchResult>()

        val cursor = db.database.rawQuery(
            """
            SELECT street_name,
                   AVG((latitude_min + latitude_max) / 2.0) AS avg_lat,
                   AVG((longitude_min + longitude_max) / 2.0) AS avg_lng,
                   COUNT(*) AS segment_count
            FROM street_segments
            WHERE street_name LIKE ?
            GROUP BY street_name
            ORDER BY street_name
            LIMIT ?
            """.trimIndent(),
            arrayOf("%$query%", limit.toString()),
        )

        cursor.use {
            while (it.moveToNext()) {
                results.add(
                    StreetSearchResult(
                        streetName = it.getString(0),
                        centerLat = it.getDouble(1),
                        centerLng = it.getDouble(2),
                        segmentCount = it.getInt(3),
                    )
                )
            }
        }

        return results
    }

    private fun getRulesForSegment(segmentId: Long): List<SweepingRule> {
        val rules = mutableListOf<SweepingRule>()

        val cursor = db.database.rawQuery(
            "SELECT day_of_week, start_time, end_time, week_of_month, holidays_observed FROM sweeping_rules WHERE segment_id = ?",
            arrayOf(segmentId.toString()),
        )

        cursor.use {
            while (it.moveToNext()) {
                val dayInt = it.getInt(0)
                val startStr = it.getString(1)
                val endStr = it.getString(2)
                val weekOfMonth = it.getInt(3)
                val holidays = it.getInt(4)

                rules.add(
                    SweepingRule(
                        dayOfWeek = DayOfWeek.of(dayInt),
                        startTime = LocalTime.parse(startStr),
                        endTime = LocalTime.parse(endStr),
                        weekOfMonth = weekOfMonth,
                        appliesToHolidays = holidays == 1,
                    )
                )
            }
        }

        return rules
    }

    private fun parseCoordinates(json: String): List<LatLngPoint> {
        val array = JSONArray(json)
        val points = mutableListOf<LatLngPoint>()
        for (i in 0 until array.length()) {
            val point = array.getJSONArray(i)
            points.add(LatLngPoint(point.getDouble(0), point.getDouble(1)))
        }
        return points
    }
}
