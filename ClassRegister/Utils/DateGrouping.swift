import Foundation

enum DateGrouping {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func groupByLocalDay(
        _ records: [PhotoRecord],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [DayPhotoGroup] {
        let grouped = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.createdAt)
        }

        return grouped
            .map { dayStart, items in
                let sorted = items.sorted { $0.createdAt > $1.createdAt }
                return DayPhotoGroup(
                    dayStart: dayStart,
                    displayDate: displayDate(for: dayStart),
                    records: sorted
                )
            }
            .sorted { $0.dayStart > $1.dayStart }
    }

    static func displayDate(for date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
