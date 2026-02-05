package com.easystreet.data.repository

import com.easystreet.data.db.StreetDao
import com.easystreet.domain.model.StreetSegment
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class StreetRepository(private val dao: StreetDao) {

    suspend fun getSegmentsInViewport(
        latMin: Double,
        latMax: Double,
        lngMin: Double,
        lngMax: Double,
    ): List<StreetSegment> = withContext(Dispatchers.IO) {
        dao.getSegmentsInViewport(latMin, latMax, lngMin, lngMax)
    }

    suspend fun findNearestSegment(lat: Double, lng: Double): StreetSegment? =
        withContext(Dispatchers.IO) {
            dao.findNearestSegment(lat, lng)
        }
}
