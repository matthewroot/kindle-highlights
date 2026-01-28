import SwiftUI

struct FavoritesListView: View {
    @EnvironmentObject var databaseManager: DatabaseManager

    @State private var highlights: [Highlight] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading favorites...")
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if highlights.isEmpty {
                ContentUnavailableView {
                    Label("No Favorites", systemImage: "star")
                } description: {
                    Text("Star highlights to add them to your favorites.")
                }
            } else {
                List(highlights) { highlight in
                    HighlightRowView(
                        highlight: highlight,
                        onToggleFavorite: { toggleFavorite(highlight) },
                        onTagsChanged: { loadFavoritesSync() },
                        showBookTitle: true
                    )
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Favorites")
        .task {
            await loadFavorites()
        }
    }

    private func loadFavorites() async {
        isLoading = true
        errorMessage = nil

        do {
            highlights = try databaseManager.getFavoriteHighlights()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func toggleFavorite(_ highlight: Highlight) {
        do {
            try databaseManager.toggleFavorite(highlightId: highlight.id)
            // Remove from local list since it's no longer a favorite
            highlights.removeAll { $0.id == highlight.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFavoritesSync() {
        do {
            highlights = try databaseManager.getFavoriteHighlights()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    FavoritesListView()
        .environmentObject(DatabaseManager())
        .frame(width: 500, height: 400)
}
