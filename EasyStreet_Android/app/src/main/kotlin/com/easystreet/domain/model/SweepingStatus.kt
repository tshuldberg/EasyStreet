package com.easystreet.domain.model

import java.time.LocalDateTime

sealed class SweepingStatus {
    data object Safe : SweepingStatus()
    data class Today(val time: LocalDateTime, val streetName: String) : SweepingStatus()
    data class Imminent(val time: LocalDateTime, val streetName: String) : SweepingStatus()
    data class Upcoming(val time: LocalDateTime, val streetName: String) : SweepingStatus()
    data object NoData : SweepingStatus()
    data object Unknown : SweepingStatus()
}
