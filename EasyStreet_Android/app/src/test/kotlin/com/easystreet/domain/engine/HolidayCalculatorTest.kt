package com.easystreet.domain.engine

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate

class HolidayCalculatorTest {

    @Test
    fun `new years day is a holiday`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 1, 1)))
    }

    @Test
    fun `july 4th is a holiday`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 7, 4)))
    }

    @Test
    fun `christmas is a holiday`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 12, 25)))
    }

    @Test
    fun `mlk day is third monday of january`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 1, 19)))
        assertFalse(HolidayCalculator.isHoliday(LocalDate.of(2026, 1, 12)))
    }

    @Test
    fun `thanksgiving is fourth thursday of november`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 11, 26)))
    }

    @Test
    fun `regular day is not a holiday`() {
        assertFalse(HolidayCalculator.isHoliday(LocalDate.of(2026, 3, 15)))
    }

    @Test
    fun `works for different years`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2025, 11, 27)))
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2027, 11, 25)))
    }

    @Test
    fun `labor day is first monday of september`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 9, 7)))
    }
}
