import Foundation

enum DayGrouper {
    private static var calendar: Calendar {
        var value = Calendar.autoupdatingCurrent
        value.timeZone = .autoupdatingCurrent
        return value
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func dayInterval(for dayStart: Date) -> DateInterval {
        if let interval = calendar.dateInterval(of: .day, for: dayStart) {
            return interval
        }
        return DateInterval(start: dayStart, duration: 24 * 60 * 60)
    }

    static func displayString(for dayStart: Date) -> String {
        dayFormatter.timeZone = .autoupdatingCurrent
        return dayFormatter.string(from: dayStart)
    }
}
