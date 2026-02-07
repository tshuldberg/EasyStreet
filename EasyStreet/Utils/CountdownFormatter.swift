import Foundation

struct CountdownFormatter {
    /// Formats a time interval into a human-readable countdown string.
    /// - Parameters:
    ///   - interval: Seconds until sweep starts. Negative means sweep has started or passed.
    ///   - sweepDuration: Duration of the sweep in seconds. Used to detect in-progress vs completed.
    /// - Returns: Formatted countdown string.
    static func format(interval: TimeInterval, sweepDuration: TimeInterval = 0) -> String {
        // interval <= 0: sweep has started or passed
        if interval <= 0 {
            // If we're within the sweep duration window, it's in progress
            if sweepDuration > 0 && abs(interval) < sweepDuration {
                return "Sweeping in progress"
            } else if interval == 0 {
                return "Sweeping in progress"
            } else {
                return "Sweep completed"
            }
        }

        let totalSeconds = Int(interval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if totalSeconds >= 86400 {
            // > 24 hours: show days + hours
            return "\(days)d \(hours)h remaining"
        } else if totalSeconds >= 3600 {
            // 1-24 hours: show hours + minutes
            return "\(hours)h \(minutes)m remaining"
        } else {
            // < 1 hour: show minutes + seconds
            return "\(minutes)m \(seconds)s remaining"
        }
    }
}
