import Foundation

struct DayPhotoGroup: Identifiable {
    let dayStart: Date
    let displayDate: String
    let records: [PhotoRecord]

    var id: Date { dayStart }
}
