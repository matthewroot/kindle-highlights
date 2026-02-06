import SwiftUI

struct BookRowView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    let book: Book

    private var isFetchingCover: Bool {
        databaseManager.coverFetchingBookIds.contains(book.id)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            BookCoverView(book: book, size: .small, isFetching: isFetchingCover)

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                if let author = book.author {
                    Text(author)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(book.highlightCount) highlight\(book.highlightCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    List {
        BookRowView(book: Book(
            id: 1,
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            kindleTitle: "The Great Gatsby (F. Scott Fitzgerald)",
            createdAt: Date(),
            highlightCount: 12
        ))
        BookRowView(book: Book(
            id: 2,
            title: "A Very Long Book Title That Might Wrap",
            author: "Some Author",
            kindleTitle: "A Very Long Book Title That Might Wrap (Some Author)",
            createdAt: Date(),
            highlightCount: 1
        ))
        BookRowView(book: Book(
            id: 3,
            title: "Book Without Author",
            author: nil,
            kindleTitle: "Book Without Author",
            createdAt: Date(),
            highlightCount: 5
        ))
    }
    .frame(width: 250)
    .environmentObject(DatabaseManager())
}
