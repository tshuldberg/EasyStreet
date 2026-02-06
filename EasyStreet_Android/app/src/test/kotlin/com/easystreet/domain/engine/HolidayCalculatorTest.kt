package com.easystreet.domain.engine

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate

class HolidayCalculatorTest {

    @Test
    fun `new years day is a holiday`() {
        // Jan 1, 2026 is Thursday — no shift
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 1, 1)))
    }

    @Test
    fun `july 4th 2026 is saturday so observed on friday july 3`() {
        // Jul 4, 2026 is Saturday → observed on Friday Jul 3
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 7, 3)))
        // Jul 4 itself is NOT a holiday (it's the observed date that counts)
        assertFalse(HolidayCalculator.isHoliday(LocalDate.of(2026, 7, 4)))
    }

    @Test
    fun `christmas is a holiday`() {
        // Dec 25, 2026 is Friday — no shift
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
    fun `day after thanksgiving is a holiday`() {
        // 2025: Thanksgiving Nov 27 → day after Nov 28
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2025, 11, 28)))
        // 2026: Thanksgiving Nov 26 → day after Nov 27
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 11, 27)))
        // 2027: Thanksgiving Nov 25 → day after Nov 26
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2027, 11, 26)))
    }

    @Test
    fun `juneteenth is NOT a holiday -- SFMTA enforces sweeping`() {
        assertFalse(HolidayCalculator.isHoliday(LocalDate.of(2026, 6, 19)))
        assertFalse(HolidayCalculator.isHoliday(LocalDate.of(2027, 6, 19)))
    }

    @Test
    fun `regular day is not a holiday`() {
        assertFalse(HolidayCalculator.isHoliday(LocalDate.of(2026, 3, 15)))
    }

    @Test
    fun `works for different years`() {
        // 2025 Thanksgiving: Nov 27
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2025, 11, 27)))
        // 2027 Thanksgiving: Nov 25
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2027, 11, 25)))
    }

    @Test
    fun `labor day is first monday of september`() {
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2026, 9, 7)))
    }

    @Test
    fun `observed date shifting for christmas 2027 -- sunday to monday`() {
        // Dec 25, 2027 is Saturday → observed Friday Dec 24
        // Wait: Dec 25, 2027 is actually Saturday
        // Saturday → Friday Dec 24
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2027, 12, 24)))
        assertFalse(HolidayCalculator.isHoliday(LocalDate.of(2027, 12, 25)))
    }

    @Test
    fun `cross year boundary -- new years 2028 observed in dec 2027`() {
        // Jan 1, 2028 is Saturday → observed Friday Dec 31, 2027
        assertTrue(HolidayCalculator.isHoliday(LocalDate.of(2027, 12, 31)))
    }

    @Test
    fun `total holiday count is 11 per year`() {
        assertEquals(11, HolidayCalculator.getHolidays(2026).size)
        assertEquals(11, HolidayCalculator.getHolidays(2027).size)
        assertEquals(11, HolidayCalculator.getHolidays(2025).size)
    }
}
