import Foundation

struct Highlight: Identifiable, Hashable {
    let id: Int64
    let bookId: Int64
    let content: String
    let location: String?
    let dateHighlighted: Date?
    let dateImported: Date
    var isFavorite: Bool
    let contentHash: String

    // Joined data
    var bookTitle: String?
    var tags: [Tag] = []
}
