import Foundation

enum ExportService {
    static func toMarkdown(
        highlights: [Highlight],
        title: String? = nil,
        groupByBook: Bool = false
    ) -> String {
        var lines: [String] = []

        if let title = title {
            lines.append("# \(title)")
            lines.append("")
        }

        lines.append("*Exported from Kindle Highlights on \(formattedDate(Date()))*")
        lines.append("")
        lines.append("---")
        lines.append("")

        if groupByBook {
            let grouped = Dictionary(grouping: highlights) { $0.bookTitle ?? "Unknown Book" }
            for (bookTitle, bookHighlights) in grouped.sorted(by: { $0.key < $1.key }) {
                lines.append("## \(bookTitle)")
                lines.append("")
                for highlight in bookHighlights {
                    lines.append(formatHighlight(highlight, includeBook: false))
                }
            }
        } else {
            for highlight in highlights {
                lines.append(formatHighlight(highlight, includeBook: false))
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func formatHighlight(_ highlight: Highlight, includeBook: Bool) -> String {
        var parts: [String] = []

        if highlight.isFavorite {
            parts.append("> \u{2B50} \(highlight.content)")
        } else {
            parts.append("> \(highlight.content)")
        }

        var metadata: [String] = []
        if includeBook, let bookTitle = highlight.bookTitle {
            metadata.append("*\(bookTitle)*")
        }
        if let location = highlight.location {
            metadata.append(location)
        }
        if let date = highlight.dateHighlighted {
            metadata.append(formattedDate(date))
        }

        if !metadata.isEmpty {
            parts.append(">")
            parts.append("> \u{2014} " + metadata.joined(separator: " | "))
        }

        parts.append("")
        return parts.joined(separator: "\n")
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
