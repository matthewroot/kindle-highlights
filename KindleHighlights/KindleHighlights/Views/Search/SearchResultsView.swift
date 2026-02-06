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

    private var searchTerms: [String] {
        searchQuery.split(separator: " ").map(String.init).filter { $0.count >= 2 }
    }

    var body: some View {
        Group {
            if isSearching {
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { highlight in
                            HighlightRowView(
                                highlight: highlight,
                                onToggleFavorite: { onToggleFavorite(highlight) },
                                onTagsChanged: { performSearchSync() },
                                showBookTitle: true,
                                searchTerms: searchTerms,
                                externalTagPickerHighlightId: $tagPickerHighlightId
                            )
                            .padding(.horizontal, Spacing.lg)

                            if highlight.id != results.last?.id {
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

        do {
            try await Task.sleep(for: .milliseconds(200))
        } catch {
            return // Task was cancelled by a new keystroke
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
