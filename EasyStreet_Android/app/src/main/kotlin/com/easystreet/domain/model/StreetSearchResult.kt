package com.easystreet.domain.model

data class StreetSearchResult(
    val streetName: String,
    val centerLat: Double,
    val centerLng: Double,
    val segmentCount: Int,
)
