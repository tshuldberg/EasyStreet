package com.easystreet.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.easystreet.data.db.DatabaseInitException
import com.easystreet.data.db.StreetDao
import com.easystreet.data.db.StreetDatabase
import com.easystreet.data.prefs.ParkingPreferences
import com.easystreet.data.repository.ParkingRepository
import com.easystreet.data.repository.StreetRepository
import com.easystreet.domain.engine.SweepingRuleEngine
import com.easystreet.data.network.ConnectivityObserver
import com.easystreet.domain.model.StreetSegment
import com.easystreet.domain.model.SweepingStatus
import com.easystreet.notification.NotificationScheduler
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDateTime

class MapViewModel(application: Application) : AndroidViewModel(application) {

    private val streetDb: StreetDatabase
    private val streetDao: StreetDao
    private val streetRepo: StreetRepository

    private val parkingPrefs = ParkingPreferences(application)
    val parkingRepo = ParkingRepository(parkingPrefs)

    private val _visibleSegments = MutableStateFlow<List<StreetSegment>>(emptyList())
    val visibleSegments: StateFlow<List<StreetSegment>> = _visibleSegments.asStateFlow()

    private val _sweepingStatus = MutableStateFlow<SweepingStatus>(SweepingStatus.NoData)
    val sweepingStatus: StateFlow<SweepingStatus> = _sweepingStatus.asStateFlow()

    private val _selectedSegment = MutableStateFlow<StreetSegment?>(null)
    val selectedSegment: StateFlow<StreetSegment?> = _selectedSegment.asStateFlow()

    private val _dbError = MutableStateFlow<String?>(null)
    val dbError: StateFlow<String?> = _dbError.asStateFlow()

    private val connectivityObserver = ConnectivityObserver(application)
    val isOnline: StateFlow<Boolean> = connectivityObserver.isOnline
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000L), true)

    private val _searchResults = MutableStateFlow<List<com.easystreet.domain.model.StreetSearchResult>>(emptyList())
    val searchResults: StateFlow<List<com.easystreet.domain.model.StreetSearchResult>> = _searchResults.asStateFlow()

    private var searchJob: Job? = null

    fun searchStreets(query: String) {
        searchJob?.cancel()
        if (query.isBlank()) {
            _searchResults.value = emptyList()
            return
        }
        searchJob = viewModelScope.launch {
            delay(200) // debounce
            val results = streetRepo.searchStreets(query)
            _searchResults.value = results
        }
    }

    fun clearSearch() {
        searchJob?.cancel()
        _searchResults.value = emptyList()
    }

    val notificationLeadMinutes: Int
        get() = parkingPrefs.notificationLeadMinutes

    private var viewportJob: Job? = null

    init {
        streetDb = StreetDatabase(application)
        streetDao = StreetDao(streetDb)
        streetRepo = StreetRepository(streetDao)

        // Eagerly verify database access
        viewModelScope.launch {
            try {
                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                    streetDb.database // triggers lazy init
                }
            } catch (e: DatabaseInitException) {
                _dbError.value = "Unable to load street data. Please reinstall the app."
            }
        }
    }

    /**
     * Called when the map camera moves. Debounces by 300ms.
     */
    fun onViewportChanged(latMin: Double, latMax: Double, lngMin: Double, lngMax: Double) {
        if (_dbError.value != null) return
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

    fun onStreetTapped(segment: StreetSegment) {
        _selectedSegment.value = segment
    }

    fun dismissStreetSheet() {
        _selectedSegment.value = null
    }

    fun updateNotificationLeadMinutes(minutes: Int) {
        parkingPrefs.notificationLeadMinutes = minutes
        // Re-schedule with new lead time if parked
        val car = parkingRepo.parkedCar.value ?: return
        viewModelScope.launch {
            val segment = streetRepo.findNearestSegment(car.latitude, car.longitude) ?: return@launch
            evaluateAndSchedule(segment, car.streetName)
        }
    }

    private fun evaluateAndSchedule(segment: StreetSegment, streetName: String) {
        val now = LocalDateTime.now()
        val status = SweepingRuleEngine.getStatus(segment.rules, streetName, now)
        _sweepingStatus.value = status

        val nextTime = SweepingRuleEngine.getNextSweepingTime(segment.rules, now)
        if (nextTime != null) {
            NotificationScheduler.schedule(
                getApplication(),
                nextTime,
                streetName,
                parkingPrefs.notificationLeadMinutes,
            )
        }
    }
}
