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
        holidaysObserved = false,
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
        // Feb 16 is Presidents' Day — skipped since holidaysObserved=false
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
}
