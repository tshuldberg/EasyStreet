package com.easystreet.domain.engine

import com.easystreet.domain.model.SweepingRule
import com.easystreet.domain.model.SweepingStatus
import org.junit.Assert.*
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDateTime
import java.time.LocalTime

class SweepingRuleEngineTest {

    private val engine = SweepingRuleEngine

    private fun mondayRule(start: Int = 9, end: Int = 11, week: Int = 0) = SweepingRule(
        dayOfWeek = DayOfWeek.MONDAY,
        startTime = LocalTime.of(start, 0),
        endTime = LocalTime.of(end, 0),
        weekOfMonth = week,
        appliesToHolidays = false,
    )

    @Test
    fun `safe when no rules`() {
        val status = engine.getStatus(emptyList(), "Test St", LocalDateTime.of(2026, 2, 9, 8, 0))
        assertTrue(status is SweepingStatus.NoData)
    }

    @Test
    fun `safe when sweeping already passed today`() {
        val status = engine.getStatus(
            listOf(mondayRule()),
            "Market St",
            LocalDateTime.of(2026, 2, 9, 12, 0),
        )
        assertTrue(status is SweepingStatus.Safe || status is SweepingStatus.Upcoming)
    }

    @Test
    fun `today when sweeping is later today, more than 1 hour away`() {
        val status = engine.getStatus(
            listOf(mondayRule()),
            "Market St",
            LocalDateTime.of(2026, 2, 9, 7, 0),
        )
        assertTrue(status is SweepingStatus.Today)
    }

    @Test
    fun `imminent when sweeping is less than 1 hour away`() {
        val status = engine.getStatus(
            listOf(mondayRule()),
            "Market St",
            LocalDateTime.of(2026, 2, 9, 8, 30),
        )
        assertTrue(status is SweepingStatus.Imminent)
    }

    @Test
    fun `activeNow when sweeping is in progress`() {
        val status = engine.getStatus(
            listOf(mondayRule()),
            "Market St",
            LocalDateTime.of(2026, 2, 9, 10, 0),
        )
        assertTrue(status is SweepingStatus.ActiveNow)
    }

    @Test
    fun `upcoming when sweeping is on a different day`() {
        val status = engine.getStatus(
            listOf(mondayRule()),
            "Market St",
            LocalDateTime.of(2026, 2, 10, 10, 0),
        )
        assertTrue(status is SweepingStatus.Upcoming)
    }

    @Test
    fun `getNextSweepingTime returns correct next occurrence`() {
        val next = engine.getNextSweepingTime(
            listOf(mondayRule()),
            LocalDateTime.of(2026, 2, 10, 10, 0),
        )
        assertNotNull(next)
        // Feb 16 is Presidents' Day — skipped since appliesToHolidays=false
        assertEquals(LocalDateTime.of(2026, 2, 23, 9, 0), next)
    }

    @Test
    fun `getNextSweepingTime returns today if sweeping hasnt started yet`() {
        val next = engine.getNextSweepingTime(
            listOf(mondayRule()),
            LocalDateTime.of(2026, 2, 9, 7, 0),
        )
        assertEquals(LocalDateTime.of(2026, 2, 9, 9, 0), next)
    }

    @Test
    fun `5th week rule found within 180 day scan range`() {
        // 5th-week-only rule (week 5) — these are rare
        val rule = SweepingRule(
            dayOfWeek = DayOfWeek.MONDAY,
            startTime = LocalTime.of(9, 0),
            endTime = LocalTime.of(11, 0),
            weekOfMonth = 5,
            appliesToHolidays = false,
        )
        // Starting from Jan 1 2026, a month with 5 Mondays:
        // March 2026 has 5 Mondays (2,9,16,23,30) — Mar 30 is 5th week
        val next = engine.getNextSweepingTime(
            listOf(rule),
            LocalDateTime.of(2026, 1, 1, 0, 0),
        )
        assertNotNull(next)
    }
}
