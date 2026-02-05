package com.easystreet.domain.engine

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.Month
import java.time.temporal.TemporalAdjusters

object HolidayCalculator {

    fun isHoliday(date: LocalDate): Boolean {
        return getHolidays(date.year).contains(date)
    }

    fun getHolidays(year: Int): Set<LocalDate> {
        return setOf(
            // Fixed holidays
            LocalDate.of(year, Month.JANUARY, 1),    // New Year's Day
            LocalDate.of(year, Month.JUNE, 19),       // Juneteenth
            LocalDate.of(year, Month.JULY, 4),        // Independence Day
            LocalDate.of(year, Month.NOVEMBER, 11),   // Veterans Day
            LocalDate.of(year, Month.DECEMBER, 25),   // Christmas Day

            // Floating holidays
            nthDayOfWeekInMonth(year, Month.JANUARY, DayOfWeek.MONDAY, 3),   // MLK Day
            nthDayOfWeekInMonth(year, Month.FEBRUARY, DayOfWeek.MONDAY, 3),  // Presidents' Day
            nthDayOfWeekInMonth(year, Month.SEPTEMBER, DayOfWeek.MONDAY, 1), // Labor Day
            nthDayOfWeekInMonth(year, Month.OCTOBER, DayOfWeek.MONDAY, 2),   // Indigenous Peoples' Day
            nthDayOfWeekInMonth(year, Month.NOVEMBER, DayOfWeek.THURSDAY, 4), // Thanksgiving

            // Memorial Day = last Monday of May
            lastDayOfWeekInMonth(year, Month.MAY, DayOfWeek.MONDAY),
        )
    }

    private fun nthDayOfWeekInMonth(
        year: Int,
        month: Month,
        dayOfWeek: DayOfWeek,
        n: Int,
    ): LocalDate {
        val first = LocalDate.of(year, month, 1)
            .with(TemporalAdjusters.firstInMonth(dayOfWeek))
        return first.plusWeeks((n - 1).toLong())
    }

    private fun lastDayOfWeekInMonth(
        year: Int,
        month: Month,
        dayOfWeek: DayOfWeek,
    ): LocalDate {
        return LocalDate.of(year, month, 1)
            .with(TemporalAdjusters.lastInMonth(dayOfWeek))
    }
}
