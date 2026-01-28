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
                    FavoriteHighlightRowView(
                        highlight: highlight,
                        onToggleFavorite: { toggleFavorite(highlight) }
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
}

/// A highlight row that shows the book title for context
struct FavoriteHighlightRowView: View {
    let highlight: Highlight
    let onToggleFavorite: () -> Void

    @State private var isExpanded = false

    private var shouldTruncate: Bool {
        highlight.content.count > 300
    }

    private var displayContent: String {
        if shouldTruncate && !isExpanded {
            return String(highlight.content.prefix(300)) + "..."
        }
        return highlight.content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggleFavorite) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    if let bookTitle = highlight.bookTitle {
                        Text(bookTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }

                    Text(displayContent)
                        .font(.body)
                        .textSelection(.enabled)

                    if shouldTruncate {
                        Button(isExpanded ? "Show less" : "Show more") {
                            withAnimation {
                                isExpanded.toggle()
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }

                    HStack(spacing: 8) {
                        if let location = highlight.location {
                            Text(location)
                        }

                        if let date = highlight.dateHighlighted {
                            Text("·")
                            Text(date, style: .date)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    FavoritesListView()
        .environmentObject(DatabaseManager())
        .frame(width: 500, height: 400)
}
