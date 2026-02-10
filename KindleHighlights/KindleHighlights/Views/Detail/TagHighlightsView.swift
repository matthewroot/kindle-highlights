import SwiftUI

struct TagHighlightsView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    let tag: Tag

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
                    Label("No Highlights", systemImage: "tag")
                } description: {
                    Text("No highlights have this tag yet.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Tag header
                        HStack(spacing: 8) {
                            Circle()
                                .fill(tag.swiftUIColor)
                                .frame(width: 12, height: 12)
                            Text(tag.name)
                                .font(.headline)
                            Spacer()
                            Text("\(highlights.count) highlight\(highlights.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.horizontal, 20)

                        ForEach(highlights) { highlight in
                            HighlightRowView(
                                highlight: highlight,
                                onToggleFavorite: { toggleFavorite(highlight) },
                                onTagsChanged: { loadHighlights() },
                                showBookTitle: true,
                                externalTagPickerHighlightId: $tagPickerHighlightId
                            )
                            .padding(.horizontal, 12)

                            if highlight.id != highlights.last?.id {
                                Divider()
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 20)
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
        .navigationTitle(tag.name)
        .task(id: tag.id) {
            loadHighlights()
            hasLoaded = true
        }
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
