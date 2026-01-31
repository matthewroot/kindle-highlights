import Foundation

struct Book: Identifiable, Hashable {
    let id: Int64
    let title: String
    let author: String?
    let kindleTitle: String
    let createdAt: Date

    var highlightCount: Int = 0
    var coverImagePath: String? = nil
}
