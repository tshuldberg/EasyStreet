package com.easystreet.domain.model

data class LatLngPoint(val latitude: Double, val longitude: Double)

data class BoundingBox(
    val latMin: Double,
    val latMax: Double,
    val lngMin: Double,
    val lngMax: Double,
)

data class StreetSegment(
    val id: Long,
    val cnn: Int,
    val streetName: String,
    val coordinates: List<LatLngPoint>,
    val bounds: BoundingBox,
    val rules: List<SweepingRule>,
)
