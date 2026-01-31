import SwiftUI

struct HighlightListView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    let book: Book

    @State private var highlights: [Highlight] = []
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var selectedHighlightId: Int64?
    @State private var tagPickerHighlightId: Int64?

    private var currentBook: Book {
        databaseManager.books.first(where: { $0.id == book.id }) ?? book
    }

    private var isFetchingCover: Bool {
        databaseManager.coverFetchingBookIds.contains(book.id)
    }

    var body: some View {
        Group {
            if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if hasLoaded && highlights.isEmpty {
                ContentUnavailableView {
                    Label("No Highlights", systemImage: "text.quote")
                } description: {
                    Text("This book has no highlights yet.")
                }
            } else {
                List(selection: $selectedHighlightId) {
                    Section {
                        HStack(spacing: 12) {
                            BookCoverView(book: currentBook, size: .large, isFetching: isFetchingCover)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentBook.title)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                if let author = currentBook.author {
                                    Text(author)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Text("\(highlights.count) highlight\(highlights.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()
                        }
                        .padding(.bottom, 12)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 16))

                        Divider()
                            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                            .listRowSeparator(.hidden)
                    }

                    ForEach(highlights) { highlight in
                        HighlightRowView(
                            highlight: highlight,
                            onToggleFavorite: { toggleFavorite(highlight) },
                            externalTagPickerHighlightId: $tagPickerHighlightId
                        )
                        .tag(highlight.id)
                        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .onKeyPress("f") {
                    guard let id = selectedHighlightId,
                          let highlight = highlights.first(where: { $0.id == id }) else {
                        return .ignored
                    }
                    toggleFavorite(highlight)
                    return .handled
                }
                .onKeyPress("t") {
                    guard let id = selectedHighlightId else { return .ignored }
                    tagPickerHighlightId = id
                    return .handled
                }
                .onKeyPress("c", phases: .down) { press in
                    guard press.modifiers.contains(.command),
                          let id = selectedHighlightId,
                          let highlight = highlights.first(where: { $0.id == id }) else {
                        return .ignored
                    }
                    Clipboard.copy(highlight.content)
                    return .handled
                }
            }
        }
        .navigationTitle("")
        .task(id: book.id) {
            loadHighlights()
        }
    }

    private func loadHighlights() {
        errorMessage = nil
        do {
            highlights = try databaseManager.getHighlights(forBook: book.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        hasLoaded = true
    }

    private func toggleFavorite(_ highlight: Highlight) {
        do {
            try databaseManager.toggleFavorite(highlightId: highlight.id)
            if let index = highlights.firstIndex(where: { $0.id == highlight.id }) {
                highlights[index].isFavorite.toggle()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    HighlightListView(book: Book(
        id: 1,
        title: "Sample Book",
        author: "Sample Author",
        kindleTitle: "Sample Book (Sample Author)",
        createdAt: Date(),
        highlightCount: 5
    ))
    .environmentObject(DatabaseManager())
    .frame(width: 500, height: 400)
}
