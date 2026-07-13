import Foundation

enum TimerFormatting {
    static func countdown(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(ceil(duration)))
        if totalSeconds > 60 * 60 {
            return hoursMinutesSeconds(totalSeconds)
        }

        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d : %02d", minutes, seconds)
    }

    static func entryDuration(_ duration: TimeInterval) -> String {
        hoursMinutesSeconds(max(0, Int(duration.rounded())))
    }

    static func duration(from digits: String) -> TimeInterval {
        let rawDigits = String(digits.suffix(6))
        let padded = String(repeating: "0", count: max(0, 6 - rawDigits.count)) + rawDigits
        let hours = Int(padded.prefix(2)) ?? 0
        let minutes = Int(padded.dropFirst(2).prefix(2)) ?? 0
        let seconds = Int(padded.suffix(2)) ?? 0
        return TimeInterval(hours * 60 * 60 + minutes * 60 + seconds)
    }

    static func digits(for duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = min(totalSeconds / 3600, 99)
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d%02d%02d", hours, minutes, seconds)
    }

    static func readableDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        var parts: [String] = []

        if hours > 0 {
            parts.append("\(hours) hr")
        }
        if minutes > 0 {
            parts.append("\(minutes) min")
        }
        if seconds > 0 || parts.isEmpty {
            parts.append("\(seconds) sec")
        }

        return parts.joined(separator: " ")
    }

    static func timerPosition(from digits: String) -> Int? {
        guard !digits.isEmpty,
              digits.allSatisfy(\.isNumber),
              let value = Int(digits),
              (1...100).contains(value) else {
            return nil
        }
        return value
    }

    private static func hoursMinutesSeconds(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d : %02d : %02d", hours, minutes, seconds)
    }
}
