import XCTest
@testable import KindleHighlights

final class ParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func testParsesSingleHighlight() {
        let content = """
        The Great Gatsby (F. Scott Fitzgerald)
        - Your Highlight on Location 234-256 | Added on Monday, January 15, 2024 10:30:00 AM

        So we beat on, boats against the current, borne back ceaselessly into the past.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].bookTitle, "The Great Gatsby")
        XCTAssertEqual(results[0].author, "F. Scott Fitzgerald")
        XCTAssertEqual(results[0].kindleTitle, "The Great Gatsby (F. Scott Fitzgerald)")
        XCTAssertEqual(results[0].content, "So we beat on, boats against the current, borne back ceaselessly into the past.")
        XCTAssertEqual(results[0].location, "Location 234-256")
        XCTAssertNotNil(results[0].dateHighlighted)
        XCTAssertFalse(results[0].contentHash.isEmpty)
    }

    func testParsesMultipleHighlights() {
        let content = """
        Book One (Author One)
        - Your Highlight on Location 100-110 | Added on Monday, January 15, 2024 10:30:00 AM

        First highlight content.
        ==========
        Book Two (Author Two)
        - Your Highlight on Location 200-210 | Added on Tuesday, January 16, 2024 11:30:00 AM

        Second highlight content.
        ==========
        Book One (Author One)
        - Your Highlight on Location 150-160 | Added on Wednesday, January 17, 2024 12:30:00 PM

        Third highlight from same book.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].bookTitle, "Book One")
        XCTAssertEqual(results[1].bookTitle, "Book Two")
        XCTAssertEqual(results[2].bookTitle, "Book One")
    }

    // MARK: - Multi-line Content

    func testParsesMultilineContent() {
        let content = """
        Test Book (Test Author)
        - Your Highlight on Location 100-110 | Added on Monday, January 15, 2024 10:30:00 AM

        This is a highlight
        that spans multiple
        lines of text.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].content, "This is a highlight\nthat spans multiple\nlines of text.")
    }

    // MARK: - Missing Author

    func testParsesMissingAuthor() {
        let content = """
        Book Without Author
        - Your Highlight on Location 100-110 | Added on Monday, January 15, 2024 10:30:00 AM

        Some highlight content.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].bookTitle, "Book Without Author")
        XCTAssertNil(results[0].author)
        XCTAssertEqual(results[0].kindleTitle, "Book Without Author")
    }

    // MARK: - Page Numbers

    func testParsesPageNumber() {
        let content = """
        Test Book (Test Author)
        - Your Highlight on page 42 | Added on Monday, January 15, 2024 10:30:00 AM

        Highlight with page number.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].location, "Page 42")
    }

    func testParsesLocationWithPage() {
        let content = """
        Test Book (Test Author)
        - Your Highlight on Page 100 | Location 1234-1256 | Added on Monday, January 15, 2024 10:30:00 AM

        Highlight with both page and location.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        // Should prefer location over page when both present
        XCTAssertEqual(results[0].location, "Location 1234-1256")
    }

    // MARK: - Skip Notes and Bookmarks

    func testSkipsNotes() {
        let content = """
        Test Book (Test Author)
        - Your Note on Location 100 | Added on Monday, January 15, 2024 10:30:00 AM

        This is a note, not a highlight.
        ==========
        Test Book (Test Author)
        - Your Highlight on Location 200 | Added on Monday, January 15, 2024 11:30:00 AM

        This is an actual highlight.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].content, "This is an actual highlight.")
    }

    func testSkipsBookmarks() {
        let content = """
        Test Book (Test Author)
        - Your Bookmark on Location 100 | Added on Monday, January 15, 2024 10:30:00 AM


        ==========
        Test Book (Test Author)
        - Your Highlight on Location 200 | Added on Monday, January 15, 2024 11:30:00 AM

        This is an actual highlight.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].content, "This is an actual highlight.")
    }

    // MARK: - Truncated Highlights

    func testHandlesTruncatedHighlights() {
        let content = """
        Test Book (Test Author)
        - Your Highlight on Location 100-150 | Added on Monday, January 15, 2024 10:30:00 AM

        This is a very long highlight that Amazon has truncated because it exceeded their limit [...]
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].content.hasSuffix("[...]"))
    }

    // MARK: - Deduplication Hash

    func testGeneratesUniqueHashForDifferentContent() {
        let content = """
        Same Book (Same Author)
        - Your Highlight on Location 100 | Added on Monday, January 15, 2024 10:30:00 AM

        First highlight content.
        ==========
        Same Book (Same Author)
        - Your Highlight on Location 200 | Added on Monday, January 15, 2024 11:30:00 AM

        Second highlight content.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 2)
        XCTAssertNotEqual(results[0].contentHash, results[1].contentHash)
    }

    func testGeneratesSameHashForIdenticalContent() {
        let content = """
        Test Book (Test Author)
        - Your Highlight on Location 100 | Added on Monday, January 15, 2024 10:30:00 AM

        Duplicate content.
        ==========
        Test Book (Test Author)
        - Your Highlight on Location 100 | Added on Tuesday, January 16, 2024 11:30:00 AM

        Duplicate content.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 2)
        // Same book title + same content = same hash (even if dates differ)
        XCTAssertEqual(results[0].contentHash, results[1].contentHash)
    }

    // MARK: - Edge Cases

    func testHandlesEmptyContent() {
        let content = """
        Test Book (Test Author)
        - Your Highlight on Location 100 | Added on Monday, January 15, 2024 10:30:00 AM


        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 0) // Empty highlights should be skipped
    }

    func testHandlesMalformedEntry() {
        let content = """
        This is not a valid entry
        ==========
        Test Book (Test Author)
        - Your Highlight on Location 100 | Added on Monday, January 15, 2024 10:30:00 AM

        Valid highlight.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].content, "Valid highlight.")
    }

    func testHandlesAuthorWithParentheses() {
        let content = """
        Some Book Title (Author Name (Editor))
        - Your Highlight on Location 100 | Added on Monday, January 15, 2024 10:30:00 AM

        Highlight content.
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        // The regex matches the last parenthetical group as author
        XCTAssertEqual(results[0].author, "Editor")
    }

    func testHandlesSpecialCharactersInContent() {
        let content = """
        Test Book (Test Author)
        - Your Highlight on Location 100 | Added on Monday, January 15, 2024 10:30:00 AM

        Content with "quotes" and 'apostrophes' and special chars: é, ñ, —, …
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].content.contains("quotes"))
        XCTAssertTrue(results[0].content.contains("é"))
        XCTAssertTrue(results[0].content.contains("—"))
    }

    func testHandlesEmptyFile() {
        let content = ""

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 0)
    }

    func testHandlesFileWithOnlyDelimiters() {
        let content = """
        ==========
        ==========
        ==========
        """

        let results = ImportService.parse(clippingsContent: content)

        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Date Parsing

    func testParsesVariousDateFormats() {
        // Test the primary format
        let content1 = """
        Test Book (Test Author)
        - Your Highlight on Location 100 | Added on Monday, January 15, 2024 10:30:00 AM

        Content.
        ==========
        """

        let results1 = ImportService.parse(clippingsContent: content1)
        XCTAssertNotNil(results1[0].dateHighlighted)

        // Verify the parsed date components
        if let date = results1[0].dateHighlighted {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            XCTAssertEqual(components.year, 2024)
            XCTAssertEqual(components.month, 1)
            XCTAssertEqual(components.day, 15)
            XCTAssertEqual(components.hour, 10)
            XCTAssertEqual(components.minute, 30)
        }
    }
}
