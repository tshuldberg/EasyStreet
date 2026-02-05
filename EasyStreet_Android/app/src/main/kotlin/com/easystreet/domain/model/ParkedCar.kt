package com.easystreet.domain.model

import java.time.Instant

data class ParkedCar(
    val latitude: Double,
    val longitude: Double,
    val streetName: String,
    val timestamp: Instant,
)
