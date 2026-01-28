import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    let searchQuery: String
    let onToggleFavorite: (Highlight) -> Void

    @State private var results: [Highlight] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isSearching {
                ProgressView("Searching...")
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if results.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("No highlights match \"\(searchQuery)\"")
                }
            } else {
                List(results) { highlight in
                    HighlightRowView(
                        highlight: highlight,
                        onToggleFavorite: { onToggleFavorite(highlight) },
                        onTagsChanged: { performSearchSync() },
                        showBookTitle: true
                    )
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search Results")
        .navigationSubtitle("\(results.count) result\(results.count == 1 ? "" : "s")")
        .task(id: searchQuery) {
            await performSearch()
        }
    }

    private func performSearch() async {
        guard !searchQuery.isEmpty else {
            results = []
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            results = try databaseManager.search(query: searchQuery)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    private func performSearchSync() {
        guard !searchQuery.isEmpty else {
            results = []
            return
        }
        do {
            results = try databaseManager.search(query: searchQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SearchResultsView(
        searchQuery: "test",
        onToggleFavorite: { _ in }
    )
    .environmentObject(DatabaseManager())
    .frame(width: 500, height: 400)
}
