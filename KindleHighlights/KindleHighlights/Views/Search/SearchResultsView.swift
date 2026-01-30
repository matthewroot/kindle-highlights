import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    let searchQuery: String
    let onToggleFavorite: (Highlight) -> Void

    @State private var results: [Highlight] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var selectedHighlightId: Int64?
    @State private var tagPickerHighlightId: Int64?

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
                List(selection: $selectedHighlightId) {
                    ForEach(results) { highlight in
                        HighlightRowView(
                            highlight: highlight,
                            onToggleFavorite: { onToggleFavorite(highlight) },
                            onTagsChanged: { performSearchSync() },
                            showBookTitle: true,
                            externalTagPickerHighlightId: $tagPickerHighlightId
                        )
                        .tag(highlight.id)
                    }
                }
                .listStyle(.plain)
                .onKeyPress("f") {
                    guard let id = selectedHighlightId,
                          let highlight = results.first(where: { $0.id == id }) else {
                        return .ignored
                    }
                    onToggleFavorite(highlight)
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
                          let highlight = results.first(where: { $0.id == id }) else {
                        return .ignored
                    }
                    Clipboard.copy(highlight.content)
                    return .handled
                }
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
