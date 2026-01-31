import Foundation
import SQLite
import Combine

/// Manages all database operations for the Kindle Highlights app
@MainActor
class DatabaseManager: ObservableObject {
    private var db: Connection?

    @Published var books: [Book] = []
    @Published var tags: [Tag] = []
    @Published var isLoading = false
    @Published var error: DatabaseError?

    enum DatabaseError: LocalizedError {
        case connectionFailed(String)
        case queryFailed(String)
        case importFailed(String)

        var errorDescription: String? {
            switch self {
            case .connectionFailed(let message): return "Database connection failed: \(message)"
            case .queryFailed(let message): return "Query failed: \(message)"
            case .importFailed(let message): return "Import failed: \(message)"
            }
        }
    }

    init() {
        do {
            try connect()
            try loadBooks()
            try loadTags()
        } catch {
            self.error = .connectionFailed(error.localizedDescription)
        }
    }

    // MARK: - Connection

    private func connect() throws {
        let dbPath = Self.databasePath()

        // Ensure directory exists
        let directory = (dbPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        db = try Connection(dbPath)
        try Schema.createTables(db: db!)
    }

    static func databasePath() -> String {
        // Check for Dropbox location first
        let dropboxPath = NSString(string: "~/Dropbox/Apps/KindleHighlights/highlights.db").expandingTildeInPath
        if FileManager.default.fileExists(atPath: (dropboxPath as NSString).deletingLastPathComponent) {
            return dropboxPath
        }

        // Fall back to local Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("KindleHighlights", isDirectory: true)
        return appDirectory.appendingPathComponent("highlights.db").path
    }

    // MARK: - Books

    func loadBooks() throws {
        guard let db = db else { return }

        let query = Schema.books
            .select(Schema.books[*], Schema.highlights[Schema.Highlights.id].count)
            .join(.leftOuter, Schema.highlights, on: Schema.books[Schema.Books.id] == Schema.highlights[Schema.Highlights.bookId])
            .group(Schema.books[Schema.Books.id])
            .order(Schema.Books.createdAt.desc)

        books = try db.prepare(query).map { row in
            Book(
                id: row[Schema.Books.id],
                title: row[Schema.Books.title],
                author: row[Schema.Books.author],
                kindleTitle: row[Schema.Books.kindleTitle],
                createdAt: row[Schema.Books.createdAt],
                highlightCount: row[Schema.highlights[Schema.Highlights.id].count]
            )
        }
    }

    @discardableResult
    func createOrGetBook(title: String, author: String?, kindleTitle: String) throws -> Int64 {
        guard let db = db else { throw DatabaseError.connectionFailed("No connection") }

        // Try to find existing book
        let query = Schema.books.filter(Schema.Books.kindleTitle == kindleTitle)
        if let existingBook = try db.pluck(query) {
            return existingBook[Schema.Books.id]
        }

        // Create new book
        let insert = Schema.books.insert(
            Schema.Books.title <- title,
            Schema.Books.author <- author,
            Schema.Books.kindleTitle <- kindleTitle
        )
        return try db.run(insert)
    }

    func getBook(id: Int64) throws -> Book? {
        guard let db = db else { return nil }

        let query = Schema.books.filter(Schema.Books.id == id)
        guard let row = try db.pluck(query) else { return nil }

        return Book(
            id: row[Schema.Books.id],
            title: row[Schema.Books.title],
            author: row[Schema.Books.author],
            kindleTitle: row[Schema.Books.kindleTitle],
            createdAt: row[Schema.Books.createdAt]
        )
    }

    // MARK: - Highlights

    func getHighlights(forBook bookId: Int64) throws -> [Highlight] {
        guard let db = db else { return [] }

        let query = Schema.highlights
            .filter(Schema.Highlights.bookId == bookId)
            .order(Schema.Highlights.dateHighlighted.desc)

        return try db.prepare(query).map { row in
            Highlight(
                id: row[Schema.Highlights.id],
                bookId: row[Schema.Highlights.bookId],
                content: row[Schema.Highlights.content],
                location: row[Schema.Highlights.location],
                dateHighlighted: row[Schema.Highlights.dateHighlighted],
                dateImported: row[Schema.Highlights.dateImported],
                isFavorite: row[Schema.Highlights.isFavorite],
                contentHash: row[Schema.Highlights.contentHash]
            )
        }
    }

    func getAllHighlights() throws -> [Highlight] {
        guard let db = db else { return [] }

        let query = Schema.highlights
            .join(Schema.books, on: Schema.highlights[Schema.Highlights.bookId] == Schema.books[Schema.Books.id])
            .order(Schema.Highlights.dateHighlighted.desc)

        return try db.prepare(query).map { row in
            var highlight = Highlight(
                id: row[Schema.Highlights.id],
                bookId: row[Schema.Highlights.bookId],
                content: row[Schema.Highlights.content],
                location: row[Schema.Highlights.location],
                dateHighlighted: row[Schema.Highlights.dateHighlighted],
                dateImported: row[Schema.Highlights.dateImported],
                isFavorite: row[Schema.Highlights.isFavorite],
                contentHash: row[Schema.Highlights.contentHash]
            )
            highlight.bookTitle = row[Schema.Books.title]
            return highlight
        }
    }

    @discardableResult
    func createHighlight(bookId: Int64, content: String, location: String?, dateHighlighted: Date?, contentHash: String) throws -> Int64? {
        guard let db = db else { throw DatabaseError.connectionFailed("No connection") }

        // Check for duplicate via content hash
        let existingQuery = Schema.highlights.filter(Schema.Highlights.contentHash == contentHash)
        if try db.pluck(existingQuery) != nil {
            return nil // Already exists
        }

        let insert = Schema.highlights.insert(
            Schema.Highlights.bookId <- bookId,
            Schema.Highlights.content <- content,
            Schema.Highlights.location <- location,
            Schema.Highlights.dateHighlighted <- dateHighlighted,
            Schema.Highlights.contentHash <- contentHash
        )
        return try db.run(insert)
    }

    func toggleFavorite(highlightId: Int64) throws {
        guard let db = db else { return }

        let highlight = Schema.highlights.filter(Schema.Highlights.id == highlightId)
        guard let row = try db.pluck(highlight) else { return }

        let currentValue = row[Schema.Highlights.isFavorite]
        try db.run(highlight.update(Schema.Highlights.isFavorite <- !currentValue))
    }

    func getFavoriteHighlights() throws -> [Highlight] {
        guard let db = db else { return [] }

        let query = Schema.highlights
            .join(Schema.books, on: Schema.highlights[Schema.Highlights.bookId] == Schema.books[Schema.Books.id])
            .filter(Schema.highlights[Schema.Highlights.isFavorite] == true)
            .order(Schema.highlights[Schema.Highlights.dateHighlighted].desc)

        return try db.prepare(query).map { row in
            var highlight = Highlight(
                id: row[Schema.highlights[Schema.Highlights.id]],
                bookId: row[Schema.highlights[Schema.Highlights.bookId]],
                content: row[Schema.highlights[Schema.Highlights.content]],
                location: row[Schema.highlights[Schema.Highlights.location]],
                dateHighlighted: row[Schema.highlights[Schema.Highlights.dateHighlighted]],
                dateImported: row[Schema.highlights[Schema.Highlights.dateImported]],
                isFavorite: row[Schema.highlights[Schema.Highlights.isFavorite]],
                contentHash: row[Schema.highlights[Schema.Highlights.contentHash]]
            )
            highlight.bookTitle = row[Schema.books[Schema.Books.title]]
            return highlight
        }
    }

    // MARK: - Search

    func search(query searchQuery: String) throws -> [Highlight] {
        guard let db = db else { return [] }
        guard searchQuery.count >= 2 else { return [] }

        let ftsQuery = buildFTSQuery(searchQuery)

        let sql = """
            SELECT h.id, h.book_id, h.content, h.location, h.date_highlighted,
                   h.date_imported, h.is_favorite, h.content_hash,
                   b.title as book_title, b.author as book_author
            FROM highlights h
            JOIN books b ON h.book_id = b.id
            WHERE h.id IN (
                SELECT rowid FROM highlights_fts WHERE highlights_fts MATCH ?
            )
            UNION
            SELECT h.id, h.book_id, h.content, h.location, h.date_highlighted,
                   h.date_imported, h.is_favorite, h.content_hash,
                   b.title as book_title, b.author as book_author
            FROM highlights h
            JOIN books b ON h.book_id = b.id
            WHERE b.title LIKE ? ESCAPE '\\' OR b.author LIKE ? ESCAPE '\\'
            ORDER BY date_highlighted DESC
        """

        let likePattern = "%" + escapeLikePattern(searchQuery) + "%"

        var results: [Highlight] = []
        let statement = try db.prepare(sql)

        for row in try statement.run(ftsQuery, likePattern, likePattern) {
            var highlight = Highlight(
                id: row[0] as! Int64,
                bookId: row[1] as! Int64,
                content: row[2] as! String,
                location: row[3] as? String,
                dateHighlighted: (row[4] as? String).flatMap { DateFormatter.sqlite.date(from: $0) },
                dateImported: DateFormatter.sqlite.date(from: row[5] as! String) ?? Date(),
                isFavorite: (row[6] as! Int64) == 1,
                contentHash: row[7] as! String,
                bookTitle: row[8] as? String
            )
            highlight.bookAuthor = row[9] as? String
            results.append(highlight)
        }

        return results
    }

    private func buildFTSQuery(_ input: String) -> String {
        let words = input.split(separator: " ").map(String.init)
        let sanitized = words.compactMap { sanitizeFTSToken($0) }.filter { !$0.isEmpty }
        guard !sanitized.isEmpty else { return "\"\"" }
        return sanitized.map { "\($0)*" }.joined(separator: " ")
    }

    private func sanitizeFTSToken(_ token: String) -> String {
        let forbidden = CharacterSet(charactersIn: "\"*^():+-")
        return token.unicodeScalars.filter { !forbidden.contains($0) }.map(String.init).joined()
    }

    private func escapeLikePattern(_ pattern: String) -> String {
        pattern
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    // MARK: - Tags

    func loadTags() throws {
        tags = try getAllTags()
    }

    func getAllTags() throws -> [Tag] {
        guard let db = db else { return [] }

        let query = Schema.tags.order(Schema.Tags.name)
        return try db.prepare(query).map { row in
            Tag(
                id: row[Schema.Tags.id],
                name: row[Schema.Tags.name],
                color: row[Schema.Tags.color]
            )
        }
    }

    @discardableResult
    func createTag(name: String, color: String) throws -> Int64 {
        guard let db = db else { throw DatabaseError.connectionFailed("No connection") }

        let insert = Schema.tags.insert(
            Schema.Tags.name <- name,
            Schema.Tags.color <- color
        )
        let id = try db.run(insert)
        try loadTags()
        return id
    }

    func deleteTag(id: Int64) throws {
        guard let db = db else { return }

        let tag = Schema.tags.filter(Schema.Tags.id == id)
        try db.run(tag.delete())
        try loadTags()
    }

    func updateTag(id: Int64, name: String, color: String) throws {
        guard let db = db else { return }

        let tag = Schema.tags.filter(Schema.Tags.id == id)
        try db.run(tag.update(
            Schema.Tags.name <- name,
            Schema.Tags.color <- color
        ))
        try loadTags()
    }

    func addTag(_ tagId: Int64, toHighlight highlightId: Int64) throws {
        guard let db = db else { return }

        let insert = Schema.highlightTags.insert(or: .ignore,
            Schema.HighlightTags.highlightId <- highlightId,
            Schema.HighlightTags.tagId <- tagId
        )
        try db.run(insert)
    }

    func removeTag(_ tagId: Int64, fromHighlight highlightId: Int64) throws {
        guard let db = db else { return }

        let query = Schema.highlightTags
            .filter(Schema.HighlightTags.highlightId == highlightId)
            .filter(Schema.HighlightTags.tagId == tagId)
        try db.run(query.delete())
    }

    func getTags(forHighlight highlightId: Int64) throws -> [Tag] {
        guard let db = db else { return [] }

        let query = Schema.tags
            .join(Schema.highlightTags, on: Schema.tags[Schema.Tags.id] == Schema.highlightTags[Schema.HighlightTags.tagId])
            .filter(Schema.HighlightTags.highlightId == highlightId)

        return try db.prepare(query).map { row in
            Tag(
                id: row[Schema.Tags.id],
                name: row[Schema.Tags.name],
                color: row[Schema.Tags.color]
            )
        }
    }

    func getHighlights(forTag tagId: Int64) throws -> [Highlight] {
        guard let db = db else { return [] }

        let query = Schema.highlights
            .join(Schema.highlightTags, on: Schema.highlights[Schema.Highlights.id] == Schema.highlightTags[Schema.HighlightTags.highlightId])
            .join(Schema.books, on: Schema.highlights[Schema.Highlights.bookId] == Schema.books[Schema.Books.id])
            .filter(Schema.highlightTags[Schema.HighlightTags.tagId] == tagId)
            .order(Schema.highlights[Schema.Highlights.dateHighlighted].desc)

        return try db.prepare(query).map { row in
            var highlight = Highlight(
                id: row[Schema.highlights[Schema.Highlights.id]],
                bookId: row[Schema.highlights[Schema.Highlights.bookId]],
                content: row[Schema.highlights[Schema.Highlights.content]],
                location: row[Schema.highlights[Schema.Highlights.location]],
                dateHighlighted: row[Schema.highlights[Schema.Highlights.dateHighlighted]],
                dateImported: row[Schema.highlights[Schema.Highlights.dateImported]],
                isFavorite: row[Schema.highlights[Schema.Highlights.isFavorite]],
                contentHash: row[Schema.highlights[Schema.Highlights.contentHash]]
            )
            highlight.bookTitle = row[Schema.books[Schema.Books.title]]
            return highlight
        }
    }

    // MARK: - Import

    func importClippings(from url: URL) async throws -> ImportResult {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try await importClippings(content: content)
    }

    func importClippings(content: String) async throws -> ImportResult {
        isLoading = true
        defer { isLoading = false }

        let parsed = ImportService.parse(clippingsContent: content)

        var imported = 0
        var skipped = 0

        for highlight in parsed {
            do {
                let bookId = try createOrGetBook(
                    title: highlight.bookTitle,
                    author: highlight.author,
                    kindleTitle: highlight.kindleTitle
                )

                if let _ = try createHighlight(
                    bookId: bookId,
                    content: highlight.content,
                    location: highlight.location,
                    dateHighlighted: highlight.dateHighlighted,
                    contentHash: highlight.contentHash
                ) {
                    imported += 1
                } else {
                    skipped += 1 // Duplicate
                }
            } catch {
                skipped += 1
            }
        }

        try loadBooks()

        return ImportResult(imported: imported, skipped: skipped, total: parsed.count)
    }
}

struct ImportResult {
    let imported: Int
    let skipped: Int
    let total: Int
}

extension DateFormatter {
    static let sqlite: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
