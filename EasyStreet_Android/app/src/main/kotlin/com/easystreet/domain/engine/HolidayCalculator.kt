package com.easystreet.domain.engine

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.Month
import java.time.temporal.TemporalAdjusters
import java.util.concurrent.ConcurrentHashMap

object HolidayCalculator {

    private val cache = ConcurrentHashMap<Int, Set<LocalDate>>()

    fun isHoliday(date: LocalDate): Boolean {
        if (getHolidays(date.year).contains(date)) return true
        // Cross-year boundary: in December, check if next year's holidays
        // are observed in this year (e.g., Jan 1 2028 Sat → observed Dec 31 2027)
        if (date.monthValue == 12) {
            return getHolidays(date.year + 1).contains(date)
        }
        return false
    }

    fun getHolidays(year: Int): Set<LocalDate> {
        return cache.getOrPut(year) { computeHolidays(year) }
    }

    private fun computeHolidays(year: Int): Set<LocalDate> {
        val holidays = mutableSetOf<LocalDate>()

        // Fixed holidays with observed-date shifting
        holidays.add(observedDate(LocalDate.of(year, Month.JANUARY, 1)))    // New Year's Day
        holidays.add(observedDate(LocalDate.of(year, Month.JULY, 4)))       // Independence Day
        holidays.add(observedDate(LocalDate.of(year, Month.NOVEMBER, 11)))  // Veterans Day
        holidays.add(observedDate(LocalDate.of(year, Month.DECEMBER, 25)))  // Christmas Day

        // Floating holidays (always land on weekdays, no shifting needed)
        holidays.add(nthDayOfWeekInMonth(year, Month.JANUARY, DayOfWeek.MONDAY, 3))   // MLK Day
        holidays.add(nthDayOfWeekInMonth(year, Month.FEBRUARY, DayOfWeek.MONDAY, 3))  // Presidents' Day
        holidays.add(lastDayOfWeekInMonth(year, Month.MAY, DayOfWeek.MONDAY))          // Memorial Day
        holidays.add(nthDayOfWeekInMonth(year, Month.SEPTEMBER, DayOfWeek.MONDAY, 1)) // Labor Day
        holidays.add(nthDayOfWeekInMonth(year, Month.OCTOBER, DayOfWeek.MONDAY, 2))   // Indigenous Peoples' Day

        // Thanksgiving (4th Thursday of November)
        val thanksgiving = nthDayOfWeekInMonth(year, Month.NOVEMBER, DayOfWeek.THURSDAY, 4)
        holidays.add(thanksgiving)

        // Day after Thanksgiving (Friday)
        holidays.add(thanksgiving.plusDays(1))

        // NOTE: Juneteenth (June 19) is intentionally excluded —
        // SFMTA enforces sweeping on Juneteenth

        return holidays
    }

    private fun observedDate(date: LocalDate): LocalDate = when (date.dayOfWeek) {
        DayOfWeek.SATURDAY -> date.minusDays(1)  // Sat → Fri
        DayOfWeek.SUNDAY -> date.plusDays(1)      // Sun → Mon
        else -> date
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
