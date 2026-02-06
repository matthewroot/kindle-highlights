import SwiftUI

struct FavoritesListView: View {
    @EnvironmentObject var databaseManager: DatabaseManager

    @State private var highlights: [Highlight] = []
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var selectedHighlightId: Int64?
    @State private var tagPickerHighlightId: Int64?

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
                    Label("No Favorites", systemImage: "star")
                } description: {
                    Text("Star highlights to add them to your favorites.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(highlights) { highlight in
                            HighlightRowView(
                                highlight: highlight,
                                onToggleFavorite: { toggleFavorite(highlight) },
                                onTagsChanged: { loadFavoritesSync() },
                                showBookTitle: true,
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
                    .padding(.vertical, Spacing.md)
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
        .navigationTitle("Favorites")
        .navigationSubtitle("\(highlights.count) highlight\(highlights.count == 1 ? "" : "s")")
        .task {
            loadFavoritesSync()
            hasLoaded = true
        }
    }

    private func toggleFavorite(_ highlight: Highlight) {
        do {
            try databaseManager.toggleFavorite(highlightId: highlight.id)
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
