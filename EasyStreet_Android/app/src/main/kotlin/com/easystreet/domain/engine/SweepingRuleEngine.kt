package com.easystreet.domain.engine

import com.easystreet.domain.model.SweepingRule
import com.easystreet.domain.model.SweepingStatus
import java.time.Duration
import java.time.LocalDateTime

object SweepingRuleEngine {

    fun getStatus(
        rules: List<SweepingRule>,
        streetName: String,
        at: LocalDateTime,
    ): SweepingStatus {
        if (rules.isEmpty()) return SweepingStatus.NoData

        val today = at.toLocalDate()
        val isHoliday = HolidayCalculator.isHoliday(today)

        val todayRules = rules.filter { it.appliesTo(today, isHoliday) }

        for (rule in todayRules) {
            val sweepStart = today.atTime(rule.startTime)
            val sweepEnd = today.atTime(rule.endTime)

            if (at >= sweepEnd) continue

            // Sweeping is actively in progress
            if (at >= sweepStart) {
                return SweepingStatus.ActiveNow(sweepStart, streetName)
            }

            val timeUntil = Duration.between(at, sweepStart)
            return if (timeUntil.toMinutes() < 60) {
                SweepingStatus.Imminent(sweepStart, streetName)
            } else {
                SweepingStatus.Today(sweepStart, streetName)
            }
        }

        val nextTime = getNextSweepingTime(rules, at)
        return if (nextTime != null) {
            SweepingStatus.Upcoming(nextTime, streetName)
        } else {
            SweepingStatus.Safe
        }
    }

    fun getNextSweepingTime(
        rules: List<SweepingRule>,
        after: LocalDateTime,
    ): LocalDateTime? {
        var earliest: LocalDateTime? = null

        for (rule in rules) {
            val today = after.toLocalDate()
            val todaySweepStart = today.atTime(rule.startTime)
            if (todaySweepStart > after && rule.appliesTo(today, HolidayCalculator.isHoliday(today))) {
                if (earliest == null || todaySweepStart < earliest) {
                    earliest = todaySweepStart
                }
                continue
            }

            for (dayOffset in 1L..180L) {
                val date = today.plusDays(dayOffset)
                if (rule.appliesTo(date, HolidayCalculator.isHoliday(date))) {
                    val sweepTime = date.atTime(rule.startTime)
                    if (earliest == null || sweepTime < earliest) {
                        earliest = sweepTime
                    }
                    break
                }
            }
        }

        return earliest
    }
}
