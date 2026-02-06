import Foundation

/// Dynamically calculates SF public holidays for any year.
/// Replaces the previously hardcoded 2023 holiday list in SweepingRuleEngine.
class HolidayCalculator {

    /// Returns all 11 SF public holidays for the given year.
    func holidays(for year: Int) -> [Date] {
        var result: [Date] = []

        // Fixed holidays
        result.append(makeDate(year: year, month: 1, day: 1))    // New Year's Day
        result.append(makeDate(year: year, month: 6, day: 19))   // Juneteenth
        result.append(makeDate(year: year, month: 7, day: 4))    // Independence Day
        result.append(makeDate(year: year, month: 11, day: 11))  // Veterans Day
        result.append(makeDate(year: year, month: 12, day: 25))  // Christmas

        // Floating holidays
        result.append(nthWeekday(nth: 3, weekday: 2, month: 1, year: year))  // MLK Day (3rd Monday Jan)
        result.append(nthWeekday(nth: 3, weekday: 2, month: 2, year: year))  // Presidents' Day (3rd Monday Feb)
        result.append(lastWeekday(2, month: 5, year: year))                   // Memorial Day (last Monday May)
        result.append(nthWeekday(nth: 1, weekday: 2, month: 9, year: year))  // Labor Day (1st Monday Sep)
        result.append(nthWeekday(nth: 2, weekday: 2, month: 10, year: year)) // Indigenous Peoples' Day (2nd Monday Oct)
        result.append(nthWeekday(nth: 4, weekday: 5, month: 11, year: year)) // Thanksgiving (4th Thursday Nov)

        return result
    }

    /// Check whether a given date falls on any SF public holiday.
    func isHoliday(_ date: Date) -> Bool {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        return holidays(for: year).contains { cal.isDate($0, inSameDayAs: date) }
    }

    // MARK: - Private Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return Calendar.current.date(from: c)!
    }

    /// Returns the nth occurrence of a weekday in a given month/year.
    /// weekday uses Calendar convention: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    private func nthWeekday(nth: Int, weekday: Int, month: Int, year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = nth
        return Calendar.current.date(from: components)!
    }

    /// Returns the last occurrence of a weekday in a given month/year.
    private func lastWeekday(_ weekday: Int, month: Int, year: Int) -> Date {
        let cal = Calendar.current
        // Get the last day of the month
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 0
        let lastDay = cal.date(from: components)!

        let lastDayWeekday = cal.component(.weekday, from: lastDay)
        var diff = lastDayWeekday - weekday
        if diff < 0 { diff += 7 }
        return cal.date(byAdding: .day, value: -diff, to: lastDay)!
    }
}
