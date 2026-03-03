import Foundation
import SwiftData

@Model
final class PhotoRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var fileName: String

    init(id: UUID = UUID(), createdAt: Date, fileName: String) {
        self.id = id
        self.createdAt = createdAt
        self.fileName = fileName
    }
}
