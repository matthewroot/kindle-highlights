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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Hero book header
                        bookHeader
                            .padding(.horizontal, Spacing.xl)
                            .padding(.top, Spacing.lg)
                            .padding(.bottom, Spacing.xl)

                        Divider()
                            .padding(.horizontal, Spacing.xl)

                        // Highlights list
                        ForEach(highlights) { highlight in
                            HighlightRowView(
                                highlight: highlight,
                                onToggleFavorite: { toggleFavorite(highlight) },
                                externalTagPickerHighlightId: $tagPickerHighlightId
                            )
                            .padding(.horizontal, Spacing.lg)

                            if highlight.id != highlights.last?.id {
                                Divider()
                                    .padding(.leading, Spacing.xxl + Spacing.xl)
                                    .padding(.trailing, Spacing.xl)
                            }
                        }
                    }
                    .padding(.bottom, Spacing.xl)
                }
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

    // MARK: - Book Header

    private var bookHeader: some View {
        HStack(spacing: Spacing.lg) {
            // Book cover with enhanced styling
            BookCoverView(book: currentBook, size: .large, isFetching: isFetchingCover)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(currentBook.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(3)

                if let author = currentBook.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                    .frame(height: Spacing.xs)

                // Highlight count badge
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "text.quote")
                        .font(.caption)
                    Text("\(highlights.count) highlight\(highlights.count == 1 ? "" : "s")")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background {
                    Capsule()
                        .fill(.quaternary)
                }
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .glassBackground(cornerRadius: CornerRadius.lg)
    }

    // MARK: - Actions

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
