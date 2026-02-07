package com.easystreet.domain.model

import org.junit.Assert.*
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime

class SweepingRuleTest {

    @Test
    fun `appliesTo returns true for matching day and every week`() {
        val rule = SweepingRule(
            dayOfWeek = DayOfWeek.MONDAY,
            startTime = LocalTime.of(9, 0),
            endTime = LocalTime.of(11, 0),
            weekOfMonth = 0,
            appliesToHolidays = false,
        )
        assertTrue(rule.appliesTo(LocalDate.of(2026, 2, 9)))
    }

    @Test
    fun `appliesTo returns false for non-matching day`() {
        val rule = SweepingRule(
            dayOfWeek = DayOfWeek.MONDAY,
            startTime = LocalTime.of(9, 0),
            endTime = LocalTime.of(11, 0),
            weekOfMonth = 0,
            appliesToHolidays = false,
        )
        assertFalse(rule.appliesTo(LocalDate.of(2026, 2, 10)))
    }

    @Test
    fun `appliesTo respects specific week of month`() {
        val rule = SweepingRule(
            dayOfWeek = DayOfWeek.MONDAY,
            startTime = LocalTime.of(9, 0),
            endTime = LocalTime.of(11, 0),
            weekOfMonth = 1,
            appliesToHolidays = false,
        )
        assertTrue(rule.appliesTo(LocalDate.of(2026, 2, 2)))
        assertFalse(rule.appliesTo(LocalDate.of(2026, 2, 9)))
    }
}
