package com.easystreet.domain.model

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime
import java.time.temporal.WeekFields
import java.util.Locale

data class SweepingRule(
    val dayOfWeek: DayOfWeek,
    val startTime: LocalTime,
    val endTime: LocalTime,
    val weekOfMonth: Int, // 0 = every week, 1-5 = specific week
    val appliesToHolidays: Boolean,
) {
    fun appliesTo(date: LocalDate, isHoliday: Boolean = false): Boolean {
        if (date.dayOfWeek != dayOfWeek) return false

        if (weekOfMonth != 0) {
            val weekFields = WeekFields.of(Locale.US)
            val week = date.get(weekFields.weekOfMonth())
            if (week != weekOfMonth) return false
        }

        if (!appliesToHolidays && isHoliday) return false

        return true
    }
}
