import SwiftUI

struct HighlightRowView: View {
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
                    Image(systemName: highlight.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(highlight.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
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
    .frame(width: 500)
}
