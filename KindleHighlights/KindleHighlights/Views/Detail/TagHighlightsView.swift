import SwiftUI

struct TagHighlightsView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    let tag: Tag

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
                    Label("No Highlights", systemImage: "tag")
                } description: {
                    Text("No highlights have this tag yet.")
                }
            } else {
                List(highlights) { highlight in
                    VStack(alignment: .leading, spacing: 4) {
                        if let bookTitle = highlight.bookTitle {
                            Text(bookTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HighlightRowView(
                            highlight: highlight,
                            onToggleFavorite: { toggleFavorite(highlight) },
                            onTagsChanged: { loadHighlights() }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(tag.name)
        .task(id: tag.id) {
            await loadHighlightsAsync()
        }
    }

    private func loadHighlightsAsync() async {
        isLoading = true
        errorMessage = nil
        loadHighlights()
        isLoading = false
    }

    private func loadHighlights() {
        do {
            highlights = try databaseManager.getHighlights(forTag: tag.id)
        } catch {
            errorMessage = error.localizedDescription
        }
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
    TagHighlightsView(tag: Tag(id: 1, name: "Important", color: "#3B82F6"))
        .environmentObject(DatabaseManager())
        .frame(width: 500, height: 400)
}
