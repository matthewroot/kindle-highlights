import Foundation
import SQLite

/// Database schema definitions and table structures
enum Schema {
    // MARK: - Tables

    static let books = Table("books")
    static let highlights = Table("highlights")
    static let tags = Table("tags")
    static let highlightTags = Table("highlight_tags")

    // MARK: - Books Columns

    enum Books {
        static let id = Expression<Int64>("id")
        static let title = Expression<String>("title")
        static let author = Expression<String?>("author")
        static let kindleTitle = Expression<String>("kindle_title")
        static let createdAt = Expression<Date>("created_at")
    }

    // MARK: - Highlights Columns

    enum Highlights {
        static let id = Expression<Int64>("id")
        static let bookId = Expression<Int64>("book_id")
        static let content = Expression<String>("content")
        static let location = Expression<String?>("location")
        static let dateHighlighted = Expression<Date?>("date_highlighted")
        static let dateImported = Expression<Date>("date_imported")
        static let isFavorite = Expression<Bool>("is_favorite")
        static let contentHash = Expression<String>("content_hash")
    }

    // MARK: - Tags Columns

    enum Tags {
        static let id = Expression<Int64>("id")
        static let name = Expression<String>("name")
        static let color = Expression<String>("color")
    }

    // MARK: - HighlightTags Columns

    enum HighlightTags {
        static let highlightId = Expression<Int64>("highlight_id")
        static let tagId = Expression<Int64>("tag_id")
    }

    // MARK: - Schema Version

    static let currentVersion = 1

    // MARK: - Create Tables

    static func createTables(db: Connection) throws {
        // Books table
        try db.run(books.create(ifNotExists: true) { t in
            t.column(Books.id, primaryKey: .autoincrement)
            t.column(Books.title)
            t.column(Books.author)
            t.column(Books.kindleTitle, unique: true)
            t.column(Books.createdAt, defaultValue: Date())
        })

        // Highlights table
        try db.run(highlights.create(ifNotExists: true) { t in
            t.column(Highlights.id, primaryKey: .autoincrement)
            t.column(Highlights.bookId, references: books, Books.id)
            t.column(Highlights.content)
            t.column(Highlights.location)
            t.column(Highlights.dateHighlighted)
            t.column(Highlights.dateImported, defaultValue: Date())
            t.column(Highlights.isFavorite, defaultValue: false)
            t.column(Highlights.contentHash, unique: true)
        })

        // Tags table
        try db.run(tags.create(ifNotExists: true) { t in
            t.column(Tags.id, primaryKey: .autoincrement)
            t.column(Tags.name, unique: true)
            t.column(Tags.color, defaultValue: "#808080")
        })

        // Highlight-Tags junction table
        try db.run(highlightTags.create(ifNotExists: true) { t in
            t.column(HighlightTags.highlightId, references: highlights, Highlights.id)
            t.column(HighlightTags.tagId, references: tags, Tags.id)
            t.primaryKey(HighlightTags.highlightId, HighlightTags.tagId)
        })

        // Create indexes
        try db.run(highlights.createIndex(Highlights.bookId, ifNotExists: true))
        try db.run(highlights.createIndex(Highlights.isFavorite, ifNotExists: true))
        try db.run(highlightTags.createIndex(HighlightTags.tagId, ifNotExists: true))

        // Create FTS5 virtual table for full-text search
        try db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS highlights_fts USING fts5(
                content,
                content='highlights',
                content_rowid='id'
            )
        """)

        // Create triggers to keep FTS in sync
        try db.execute("""
            CREATE TRIGGER IF NOT EXISTS highlights_ai AFTER INSERT ON highlights BEGIN
                INSERT INTO highlights_fts(rowid, content) VALUES (new.id, new.content);
            END
        """)

        try db.execute("""
            CREATE TRIGGER IF NOT EXISTS highlights_ad AFTER DELETE ON highlights BEGIN
                INSERT INTO highlights_fts(highlights_fts, rowid, content) VALUES('delete', old.id, old.content);
            END
        """)

        try db.execute("""
            CREATE TRIGGER IF NOT EXISTS highlights_au AFTER UPDATE ON highlights BEGIN
                INSERT INTO highlights_fts(highlights_fts, rowid, content) VALUES('delete', old.id, old.content);
                INSERT INTO highlights_fts(rowid, content) VALUES (new.id, new.content);
            END
        """)
    }
}
