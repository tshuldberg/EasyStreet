package com.easystreet.data.prefs

import android.content.Context
import android.content.SharedPreferences
import com.easystreet.domain.model.ParkedCar
import java.time.Instant

class ParkingPreferences(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("parking", Context.MODE_PRIVATE)

    fun save(car: ParkedCar) {
        prefs.edit()
            .putFloat(KEY_LAT, car.latitude.toFloat())
            .putFloat(KEY_LNG, car.longitude.toFloat())
            .putString(KEY_STREET, car.streetName)
            .putLong(KEY_TIMESTAMP, car.timestamp.toEpochMilli())
            .apply()
    }

    fun load(): ParkedCar? {
        if (!prefs.contains(KEY_LAT)) return null

        return ParkedCar(
            latitude = prefs.getFloat(KEY_LAT, 0f).toDouble(),
            longitude = prefs.getFloat(KEY_LNG, 0f).toDouble(),
            streetName = prefs.getString(KEY_STREET, "") ?: "",
            timestamp = Instant.ofEpochMilli(prefs.getLong(KEY_TIMESTAMP, 0L)),
        )
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val KEY_LAT = "lat"
        private const val KEY_LNG = "lng"
        private const val KEY_STREET = "street"
        private const val KEY_TIMESTAMP = "timestamp"
    }
}
