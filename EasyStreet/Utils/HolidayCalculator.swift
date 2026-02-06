import Foundation

/// Dynamically calculates SF public holidays for any year.
/// Replaces the previously hardcoded 2023 holiday list in SweepingRuleEngine.
class HolidayCalculator {

    private var cachedHolidays: [Int: [Date]] = [:]
    private var cachedHolidayStrings: [Int: Set<String>] = [:]

    private lazy var isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Returns all SF public holidays for the given year.
    /// SFMTA enforces sweeping on Juneteenth but suspends it the day after Thanksgiving.
    func holidays(for year: Int) -> [Date] {
        if let cached = cachedHolidays[year] { return cached }

        var result: [Date] = []

        // Fixed holidays (wrapped with observed-date logic for weekend shifts)
        result.append(observedDate(for: makeDate(year: year, month: 1, day: 1)))    // New Year's Day
        result.append(observedDate(for: makeDate(year: year, month: 7, day: 4)))    // Independence Day
        result.append(observedDate(for: makeDate(year: year, month: 11, day: 11)))  // Veterans Day
        result.append(observedDate(for: makeDate(year: year, month: 12, day: 25)))  // Christmas

        // Floating holidays
        result.append(nthWeekday(nth: 3, weekday: 2, month: 1, year: year))  // MLK Day (3rd Monday Jan)
        result.append(nthWeekday(nth: 3, weekday: 2, month: 2, year: year))  // Presidents' Day (3rd Monday Feb)
        result.append(lastWeekday(2, month: 5, year: year))                   // Memorial Day (last Monday May)
        result.append(nthWeekday(nth: 1, weekday: 2, month: 9, year: year))  // Labor Day (1st Monday Sep)
        result.append(nthWeekday(nth: 2, weekday: 2, month: 10, year: year)) // Indigenous Peoples' Day (2nd Monday Oct)
        result.append(nthWeekday(nth: 4, weekday: 5, month: 11, year: year)) // Thanksgiving (4th Thursday Nov)

        // Day after Thanksgiving (Friday after 4th Thursday in November)
        let thanksgiving = nthWeekday(nth: 4, weekday: 5, month: 11, year: year)
        if let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: thanksgiving) {
            result.append(dayAfter)
        }

        cachedHolidays[year] = result
        cachedHolidayStrings[year] = Set(result.map { isoFormatter.string(from: $0) })
        return result
    }

    /// Check whether a given date falls on any SF public holiday.
    func isHoliday(_ date: Date) -> Bool {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let currentYearHolidays = holidays(for: year)
        if currentYearHolidays.contains(where: { cal.isDate($0, inSameDayAs: date) }) { return true }
        // Check if next year's New Year's is observed in this year's December
        let month = cal.component(.month, from: date)
        if month == 12 {
            let nextYearHolidays = holidays(for: year + 1)
            return nextYearHolidays.contains(where: { cal.isDate($0, inSameDayAs: date) })
        }
        return false
    }

    // MARK: - Private Helpers

    /// Returns the observed date for a fixed holiday.
    /// Saturday -> Friday, Sunday -> Monday (per SFMTA convention).
    private func observedDate(for date: Date) -> Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        switch weekday {
        case 7: return cal.date(byAdding: .day, value: -1, to: date) ?? date // Sat -> Fri
        case 1: return cal.date(byAdding: .day, value: 1, to: date) ?? date  // Sun -> Mon
        default: return date
        }
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        guard let date = Calendar.current.date(from: c) else { return Date.distantPast }
        return date
    }

    /// Returns the nth occurrence of a weekday in a given month/year.
    /// weekday uses Calendar convention: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    private func nthWeekday(nth: Int, weekday: Int, month: Int, year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = nth
        guard let date = Calendar.current.date(from: components) else { return Date.distantPast }
        return date
    }

    /// Returns the last occurrence of a weekday in a given month/year.
    private func lastWeekday(_ weekday: Int, month: Int, year: Int) -> Date {
        let cal = Calendar.current
        // Get the last day of the month
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 0
        guard let lastDay = cal.date(from: components) else { return Date.distantPast }

        let lastDayWeekday = cal.component(.weekday, from: lastDay)
        var diff = lastDayWeekday - weekday
        if diff < 0 { diff += 7 }
        return cal.date(byAdding: .day, value: -diff, to: lastDay) ?? Date.distantPast
    }
}
