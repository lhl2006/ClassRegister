import Foundation

struct PhotoSnapshot: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let fileName: String
}
