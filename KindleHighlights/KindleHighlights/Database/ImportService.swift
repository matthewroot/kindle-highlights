import Foundation
import CryptoKit

/// Parses Kindle "My Clippings.txt" files into structured highlight data
enum ImportService {
    /// Entry delimiter in My Clippings.txt
    private static let entryDelimiter = "=========="

    /// Regex patterns for parsing
    /// Uses greedy match (.+) to capture the last parenthetical group as author
    private static let titleAuthorPattern = #"^(.+)\(([^)]+)\)$"#
    private static let titleOnlyPattern = #"^(.+)$"#
    private static let highlightPattern = #"- Your Highlight on"#
    private static let notePattern = #"- Your Note on"#
    private static let bookmarkPattern = #"- Your Bookmark on"#
    private static let locationPattern = #"(?:Location|location)\s+(\d+(?:-\d+)?)"#
    private static let pagePattern = #"(?:Page|page)\s+(\d+)"#
    private static let datePattern = #"Added on\s+(.+)$"#

    /// Parses the entire clippings file content
    static func parse(clippingsContent: String) -> [ParsedHighlight] {
        let entries = clippingsContent.components(separatedBy: entryDelimiter)

        return entries.compactMap { entry -> ParsedHighlight? in
            parseEntry(entry.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Parses a single clipping entry
    private static func parseEntry(_ entry: String) -> ParsedHighlight? {
        let lines = entry.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return nil }

        let titleLine = lines[0]
        let metadataLine = lines[1]

        // Skip notes and bookmarks
        if metadataLine.contains("Your Note on") || metadataLine.contains("Your Bookmark on") {
            return nil
        }

        // Must be a highlight
        guard metadataLine.contains("Your Highlight on") else { return nil }

        // Parse title and author
        let (title, author, kindleTitle) = parseTitleAuthor(titleLine)

        // Parse location
        let location = parseLocation(metadataLine)

        // Parse date
        let dateHighlighted = parseDate(metadataLine)

        // Extract content (everything after metadata line)
        let content = lines.dropFirst(2).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !content.isEmpty else { return nil }

        // Generate content hash for deduplication
        let contentHash = generateHash(kindleTitle: kindleTitle, content: content)

        return ParsedHighlight(
            bookTitle: title,
            author: author,
            kindleTitle: kindleTitle,
            content: content,
            location: location,
            dateHighlighted: dateHighlighted,
            contentHash: contentHash
        )
    }

    /// Parses the title/author line
    /// Finds the last parenthetical group to handle nested parentheses like "Title (Author Name (Editor))"
    private static func parseTitleAuthor(_ line: String) -> (title: String, author: String?, kindleTitle: String) {
        let kindleTitle = line

        // Must end with closing parenthesis
        guard line.hasSuffix(")") else {
            return (line, nil, kindleTitle)
        }

        // Find the last opening parenthesis
        guard let lastOpenParen = line.lastIndex(of: "(") else {
            return (line, nil, kindleTitle)
        }

        // Find the matching closing parenthesis (first ) after the last ()
        let searchRange = line.index(after: lastOpenParen)..<line.endIndex
        guard let matchingCloseParen = line[searchRange].firstIndex(of: ")") else {
            return (line, nil, kindleTitle)
        }

        // Extract author (content between last open paren and its matching close paren)
        let authorStartIndex = line.index(after: lastOpenParen)
        let author = String(line[authorStartIndex..<matchingCloseParen]).trimmingCharacters(in: .whitespaces)

        // Extract title (everything before the last opening paren)
        let title = String(line[..<lastOpenParen]).trimmingCharacters(in: .whitespaces)

        guard !author.isEmpty, !title.isEmpty else {
            return (line, nil, kindleTitle)
        }

        return (title, author, kindleTitle)
    }

    /// Parses location from metadata line
    private static func parseLocation(_ line: String) -> String? {
        // Try location pattern first
        if let regex = try? NSRegularExpression(pattern: locationPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return "Location \(line[range])"
        }

        // Try page pattern
        if let regex = try? NSRegularExpression(pattern: pagePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return "Page \(line[range])"
        }

        return nil
    }

    /// Parses the date from metadata line
    private static func parseDate(_ line: String) -> Date? {
        if let regex = try? NSRegularExpression(pattern: datePattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            let dateString = String(line[range])
            return parseKindleDateString(dateString)
        }
        return nil
    }

    /// Parses Kindle's date format
    private static func parseKindleDateString(_ dateString: String) -> Date? {
        let formatters = [
            "EEEE, MMMM d, yyyy h:mm:ss a",     // Monday, January 15, 2024 10:30:00 AM
            "EEEE, d MMMM yyyy HH:mm:ss",        // Monday, 15 January 2024 10:30:00
            "EEEE, MMMM d, yyyy, h:mm a",        // Monday, January 15, 2024, 10:30 AM
            "EEEE, d MMMM yyyy, HH:mm"           // Monday, 15 January 2024, 10:30
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    /// Generates a SHA256 hash for deduplication
    private static func generateHash(kindleTitle: String, content: String) -> String {
        let combined = kindleTitle + content
        let data = Data(combined.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Represents a parsed highlight from My Clippings.txt
struct ParsedHighlight {
    let bookTitle: String
    let author: String?
    let kindleTitle: String
    let content: String
    let location: String?
    let dateHighlighted: Date?
    let contentHash: String
}
