package com.easystreet.data.prefs

import android.content.Context
import android.content.SharedPreferences
import com.easystreet.domain.model.ParkedCar
import java.time.Instant

class ParkingPreferences(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("parking", Context.MODE_PRIVATE)

    var notificationLeadMinutes: Int
        get() = prefs.getInt(KEY_NOTIFICATION_LEAD, 60)
        set(value) { prefs.edit().putInt(KEY_NOTIFICATION_LEAD, value).apply() }

    fun save(car: ParkedCar) {
        prefs.edit()
            .putLong(KEY_LAT, car.latitude.toRawBits())
            .putLong(KEY_LNG, car.longitude.toRawBits())
            .putString(KEY_STREET, car.streetName)
            .putLong(KEY_TIMESTAMP, car.timestamp.toEpochMilli())
            .apply()
    }

    fun load(): ParkedCar? {
        if (!prefs.contains(KEY_LAT)) return null

        val latitude = try {
            Double.fromBits(prefs.getLong(KEY_LAT, 0L))
        } catch (_: ClassCastException) {
            // Migration from old Float storage
            @Suppress("DEPRECATION")
            prefs.getFloat(KEY_LAT, 0f).toDouble()
        }

        val longitude = try {
            Double.fromBits(prefs.getLong(KEY_LNG, 0L))
        } catch (_: ClassCastException) {
            @Suppress("DEPRECATION")
            prefs.getFloat(KEY_LNG, 0f).toDouble()
        }

        return ParkedCar(
            latitude = latitude,
            longitude = longitude,
            streetName = prefs.getString(KEY_STREET, "") ?: "",
            timestamp = Instant.ofEpochMilli(prefs.getLong(KEY_TIMESTAMP, 0L)),
        )
    }

    fun clear() {
        val leadMinutes = notificationLeadMinutes
        prefs.edit().clear().apply()
        notificationLeadMinutes = leadMinutes
    }

    companion object {
        private const val KEY_LAT = "lat"
        private const val KEY_LNG = "lng"
        private const val KEY_STREET = "street"
        private const val KEY_TIMESTAMP = "timestamp"
        private const val KEY_NOTIFICATION_LEAD = "notification_lead_minutes"
    }
}
