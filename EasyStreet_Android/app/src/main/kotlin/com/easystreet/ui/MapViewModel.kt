package com.easystreet.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.easystreet.data.db.StreetDao
import com.easystreet.data.db.StreetDatabase
import com.easystreet.data.prefs.ParkingPreferences
import com.easystreet.data.repository.ParkingRepository
import com.easystreet.data.repository.StreetRepository
import com.easystreet.domain.engine.SweepingRuleEngine
import com.easystreet.domain.model.StreetSegment
import com.easystreet.domain.model.SweepingStatus
import com.easystreet.notification.NotificationScheduler
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDateTime

class MapViewModel(application: Application) : AndroidViewModel(application) {

    private val streetDb = StreetDatabase(application)
    private val streetDao = StreetDao(streetDb)
    private val streetRepo = StreetRepository(streetDao)

    private val parkingPrefs = ParkingPreferences(application)
    val parkingRepo = ParkingRepository(parkingPrefs)

    private val _visibleSegments = MutableStateFlow<List<StreetSegment>>(emptyList())
    val visibleSegments: StateFlow<List<StreetSegment>> = _visibleSegments.asStateFlow()

    private val _sweepingStatus = MutableStateFlow<SweepingStatus>(SweepingStatus.NoData)
    val sweepingStatus: StateFlow<SweepingStatus> = _sweepingStatus.asStateFlow()

    private var viewportJob: Job? = null

    /**
     * Called when the map camera moves. Debounces by 300ms.
     */
    fun onViewportChanged(latMin: Double, latMax: Double, lngMin: Double, lngMax: Double) {
        viewportJob?.cancel()
        viewportJob = viewModelScope.launch {
            delay(300)
            val segments = streetRepo.getSegmentsInViewport(latMin, latMax, lngMin, lngMax)
            _visibleSegments.value = segments
        }
    }

    /**
     * Park the car at the given location.
     */
    fun parkCar(lat: Double, lng: Double) {
        viewModelScope.launch {
            val segment = streetRepo.findNearestSegment(lat, lng)
            val streetName = segment?.streetName ?: "Unknown Street"

            parkingRepo.parkCar(lat, lng, streetName)

            if (segment != null) {
                evaluateAndSchedule(segment, streetName)
            } else {
                _sweepingStatus.value = SweepingStatus.NoData
            }
        }
    }

    /**
     * Update parked car location after pin drag.
     */
    fun updateParkingLocation(lat: Double, lng: Double) {
        viewModelScope.launch {
            val segment = streetRepo.findNearestSegment(lat, lng)
            val streetName = segment?.streetName ?: "Unknown Street"

            parkingRepo.updateLocation(lat, lng, streetName)

            if (segment != null) {
                evaluateAndSchedule(segment, streetName)
            } else {
                _sweepingStatus.value = SweepingStatus.NoData
                NotificationScheduler.cancel(getApplication())
            }
        }
    }

    /**
     * Clear parking state.
     */
    fun clearParking() {
        parkingRepo.clearParking()
        _sweepingStatus.value = SweepingStatus.NoData
        NotificationScheduler.cancel(getApplication())
    }

    private fun evaluateAndSchedule(segment: StreetSegment, streetName: String) {
        val now = LocalDateTime.now()
        val status = SweepingRuleEngine.getStatus(segment.rules, streetName, now)
        _sweepingStatus.value = status

        val nextTime = SweepingRuleEngine.getNextSweepingTime(segment.rules, now)
        if (nextTime != null) {
            NotificationScheduler.schedule(getApplication(), nextTime, streetName)
        }
    }
}
