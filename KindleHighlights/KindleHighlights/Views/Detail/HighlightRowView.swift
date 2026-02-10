import SwiftUI

struct HighlightRowView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    let highlight: Highlight
    let onToggleFavorite: () -> Void
    var onTagsChanged: (() -> Void)?
    var showBookTitle: Bool = false
    var searchTerms: [String] = []
    var externalTagPickerHighlightId: Binding<Int64?>?

    @State private var isExpanded = false
    @State private var showingTagPicker = false
    @State private var currentTags: [Tag] = []
    @State private var isHovered = false

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
        HStack(alignment: .top, spacing: 12) {
            // Favorite star
            FavoriteStarView(isFavorite: highlight.isFavorite, action: onToggleFavorite)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                // Book title (when shown)
                if showBookTitle, let bookTitle = highlight.bookTitle {
                    if searchTerms.isEmpty {
                        Text(bookTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(TextHighlighter.highlight(text: bookTitle, terms: searchTerms))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }

                // Quote content
                if searchTerms.isEmpty {
                    Text(displayContent)
                        .font(.system(size: 14, design: .serif))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                } else {
                    Text(TextHighlighter.highlight(text: displayContent, terms: searchTerms))
                        .font(.system(size: 14, design: .serif))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                }

                // Show more/less button
                if shouldTruncate {
                    Button(isExpanded ? "Show less" : "Show more") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColor.accent)
                }

                // Metadata row
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
                .foregroundStyle(.tertiary)

                // Tags row
                HStack(spacing: 6) {
                    Button {
                        showingTagPicker = true
                    } label: {
                        Image(systemName: "tag")
                            .font(.system(size: 11))
                            .foregroundStyle(isHovered ? .secondary : .tertiary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingTagPicker) {
                        TagPickerView(
                            highlightId: highlight.id,
                            currentTags: currentTags,
                            onTagsChanged: {
                                loadTags()
                                onTagsChanged?()
                            }
                        )
                    }

                    ForEach(currentTags) { tag in
                        TagChipView(tag: tag)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Copy Highlight") {
                Clipboard.copy(highlight.content)
            }
            Divider()
            Button(highlight.isFavorite ? "Unfavorite" : "Favorite") {
                onToggleFavorite()
            }
            Button("Add Tag...") {
                showingTagPicker = true
            }
        }
        .onAppear {
            loadTags()
        }
        .onChange(of: databaseManager.tags) {
            loadTags()
        }
        .onChange(of: externalTagPickerHighlightId?.wrappedValue) {
            if externalTagPickerHighlightId?.wrappedValue == highlight.id {
                showingTagPicker = true
                externalTagPickerHighlightId?.wrappedValue = nil
            }
        }
    }

    private func loadTags() {
        do {
            currentTags = try databaseManager.getTags(forHighlight: highlight.id)
        } catch {
            currentTags = []
        }
    }
}

#Preview {
    List {
        HighlightRowView(
            highlight: Highlight(
                id: 1,
                bookId: 1,
                content: "This is a short highlight that demonstrates the basic layout.",
                location: "Location 234-256",
                dateHighlighted: Date(),
                dateImported: Date(),
                isFavorite: false,
                contentHash: "abc123"
            ),
            onToggleFavorite: {}
        )

        HighlightRowView(
            highlight: Highlight(
                id: 2,
                bookId: 1,
                content: "This is a much longer highlight that should be truncated because it contains more than 300 characters. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit.",
                location: "Location 567-589",
                dateHighlighted: Date().addingTimeInterval(-86400 * 30),
                dateImported: Date(),
                isFavorite: true,
                contentHash: "def456"
            ),
            onToggleFavorite: {}
        )
    }
    .environmentObject(DatabaseManager())
    .frame(width: 500)
}
