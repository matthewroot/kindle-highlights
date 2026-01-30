import SwiftUI

struct HighlightListView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    let book: Book

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
                    Label("No Highlights", systemImage: "text.quote")
                } description: {
                    Text("This book has no highlights yet.")
                }
            } else {
                List(selection: $selectedHighlightId) {
                    ForEach(highlights) { highlight in
                        HighlightRowView(
                            highlight: highlight,
                            onToggleFavorite: { toggleFavorite(highlight) },
                            externalTagPickerHighlightId: $tagPickerHighlightId
                        )
                        .tag(highlight.id)
                    }
                }
                .listStyle(.plain)
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
        .navigationTitle(book.title)
        .navigationSubtitle("\(highlights.count) highlight\(highlights.count == 1 ? "" : "s")\(book.author.map { " · \($0)" } ?? "")")
        .task(id: book.id) {
            loadHighlights()
        }
    }

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
