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
                    SearchResultRowView(
                        highlight: highlight,
                        searchQuery: searchQuery,
                        onToggleFavorite: { onToggleFavorite(highlight) }
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
}

struct SearchResultRowView: View {
    let highlight: Highlight
    let searchQuery: String
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
                    Image(systemName: highlight.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(highlight.isFavorite ? .yellow : .secondary)
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
    SearchResultsView(
        searchQuery: "test",
        onToggleFavorite: { _ in }
    )
    .environmentObject(DatabaseManager())
    .frame(width: 500, height: 400)
}
