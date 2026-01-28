import SwiftUI

struct HighlightListView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    let book: Book

    @State private var highlights: [Highlight] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading highlights...")
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if highlights.isEmpty {
                ContentUnavailableView {
                    Label("No Highlights", systemImage: "text.quote")
                } description: {
                    Text("This book has no highlights yet.")
                }
            } else {
                List(highlights) { highlight in
                    HighlightRowView(
                        highlight: highlight,
                        onToggleFavorite: { toggleFavorite(highlight) }
                    )
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(book.title)
        .navigationSubtitle(book.author ?? "")
        .task(id: book.id) {
            await loadHighlights()
        }
    }

    private func loadHighlights() async {
        isLoading = true
        errorMessage = nil

        do {
            highlights = try databaseManager.getHighlights(forBook: book.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func toggleFavorite(_ highlight: Highlight) {
        do {
            try databaseManager.toggleFavorite(highlightId: highlight.id)
            // Update local state
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
