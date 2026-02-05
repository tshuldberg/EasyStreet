package com.easystreet.data.repository

import com.easystreet.data.prefs.ParkingPreferences
import com.easystreet.domain.model.ParkedCar
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Instant

class ParkingRepository(private val prefs: ParkingPreferences) {

    private val _parkedCar = MutableStateFlow(prefs.load())
    val parkedCar: StateFlow<ParkedCar?> = _parkedCar.asStateFlow()

    fun parkCar(latitude: Double, longitude: Double, streetName: String) {
        val car = ParkedCar(latitude, longitude, streetName, Instant.now())
        prefs.save(car)
        _parkedCar.value = car
    }

    fun updateLocation(latitude: Double, longitude: Double, streetName: String) {
        val current = _parkedCar.value ?: return
        val updated = current.copy(latitude = latitude, longitude = longitude, streetName = streetName)
        prefs.save(updated)
        _parkedCar.value = updated
    }

    fun clearParking() {
        prefs.clear()
        _parkedCar.value = null
    }
}
