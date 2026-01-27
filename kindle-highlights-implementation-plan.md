# Kindle Highlights App - Implementation Plan

## Overview

A native macOS application for extracting, organizing, and browsing Kindle highlights. Built with Swift/SwiftUI, using SQLite for storage with Dropbox sync for portability.

## Data Source

**Input:** `My Clippings.txt` file from Kindle e-reader (transferred via USB)

**Sync cadence:** Monthly (or as needed)

**Format example:**
```
Book Title (Author Name)
- Your Highlight on Location 1234-1256 | Added on Monday, January 15, 2024 10:30:00 AM

The actual highlighted text goes here and can span
multiple lines.
==========
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  My Clippings   │────▶│  ImportService  │────▶│   SQLite DB     │
│     .txt        │     │  (parse/dedup)  │     │ (in Dropbox)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                                ┌─────────────────┐
                                                │   macOS App     │
                                                │  (SwiftUI)      │
                                                └─────────────────┘
```

## Tech Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| App Framework | Swift + SwiftUI | Native macOS, lightweight, no Electron |
| Database | SQLite + FTS5 | Single file, full-text search, Dropbox-friendly |
| Persistence Location | `~/Dropbox/Apps/KindleHighlights/highlights.db` | Cross-machine sync |

---

## Database Schema

```sql
-- Books table
CREATE TABLE books (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    title           TEXT NOT NULL,
    author          TEXT,
    kindle_title    TEXT NOT NULL UNIQUE,  -- exact string from clippings for dedup
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Highlights table
CREATE TABLE highlights (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    book_id          INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    content          TEXT NOT NULL,
    location         TEXT,                  -- "Location 1234-1256" or page
    date_highlighted DATETIME,              -- from clippings file
    date_imported    DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_favorite      BOOLEAN DEFAULT 0,
    content_hash     TEXT UNIQUE            -- SHA256(kindle_title + content) for dedup
);

-- Tags table
CREATE TABLE tags (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL UNIQUE,
    color      TEXT DEFAULT '#808080'       -- hex color for UI
);

-- Junction table for highlight-tag relationship
CREATE TABLE highlight_tags (
    highlight_id INTEGER NOT NULL REFERENCES highlights(id) ON DELETE CASCADE,
    tag_id       INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (highlight_id, tag_id)
);

-- Full-text search index
CREATE VIRTUAL TABLE highlights_fts USING fts5(
    content,
    content='highlights',
    content_rowid='id'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER highlights_ai AFTER INSERT ON highlights BEGIN
    INSERT INTO highlights_fts(rowid, content) VALUES (new.id, new.content);
END;

CREATE TRIGGER highlights_ad AFTER DELETE ON highlights BEGIN
    INSERT INTO highlights_fts(highlights_fts, rowid, content) VALUES('delete', old.id, old.content);
END;

CREATE TRIGGER highlights_au AFTER UPDATE ON highlights BEGIN
    INSERT INTO highlights_fts(highlights_fts, rowid, content) VALUES('delete', old.id, old.content);
    INSERT INTO highlights_fts(rowid, content) VALUES (new.id, new.content);
END;

-- Indexes
CREATE INDEX idx_highlights_book_id ON highlights(book_id);
CREATE INDEX idx_highlights_favorite ON highlights(is_favorite);
CREATE INDEX idx_highlight_tags_tag_id ON highlight_tags(tag_id);
```

---

## Project Structure

```
KindleHighlights/
├── KindleHighlights.xcodeproj
├── KindleHighlights/
│   ├── App/
│   │   └── KindleHighlightsApp.swift       -- App entry point, window config
│   ├── Models/
│   │   ├── Book.swift                      -- Book struct
│   │   ├── Highlight.swift                 -- Highlight struct
│   │   └── Tag.swift                       -- Tag struct
│   ├── Database/
│   │   ├── DatabaseManager.swift           -- SQLite connection, CRUD operations
│   │   ├── Schema.swift                    -- Schema creation/migration
│   │   └── ImportService.swift             -- Clippings parser + import logic
│   ├── Views/
│   │   ├── ContentView.swift               -- Main NavigationSplitView layout
│   │   ├── Sidebar/
│   │   │   ├── BookListView.swift          -- List of books
│   │   │   └── BookRowView.swift           -- Single book row
│   │   ├── Detail/
│   │   │   ├── HighlightListView.swift     -- Highlights for selected book
│   │   │   └── HighlightRowView.swift      -- Single highlight row
│   │   ├── Tags/
│   │   │   ├── TagChipView.swift           -- Tag pill/chip component
│   │   │   ├── TagPickerView.swift         -- Popover for adding tags
│   │   │   └── TagManagerView.swift        -- CRUD for tags (in Preferences)
│   │   ├── Search/
│   │   │   └── SearchResultsView.swift     -- Global search results
│   │   └── Components/
│   │       ├── FavoriteButton.swift        -- Star toggle
│   │       └── EmptyStateView.swift        -- Onboarding/empty states
│   ├── ViewModels/
│   │   ├── BookListViewModel.swift
│   │   ├── HighlightListViewModel.swift
│   │   └── SearchViewModel.swift
│   └── Resources/
│       └── Assets.xcassets
└── KindleHighlightsTests/
    ├── ParserTests.swift                   -- Test clippings parsing
    └── DatabaseTests.swift                 -- Test CRUD operations
```

---

## Clippings Parser Specification

### Entry Types in `My Clippings.txt`

| Type | Indicator | Action |
|------|-----------|--------|
| Highlight | `- Your Highlight on` | Parse and store |
| Note | `- Your Note on` | Skip (or store separately, future enhancement) |
| Bookmark | `- Your Bookmark on` | Skip |

### Parsing Logic

1. Split file by `==========` delimiter
2. For each entry:
   - Line 1: Book title and author (parse with regex: `^(.+?)\s*\(([^)]+)\)$`)
   - Line 2: Metadata (type, location, date)
   - Lines 3+: Content (may be multi-line)
3. Skip if type is Note or Bookmark
4. Compute `content_hash = SHA256(kindle_title + content)`
5. Return structured `ParsedHighlight` object

### Edge Cases

- **Truncated highlights:** Amazon truncates long highlights, ending with `[...]`. Store as-is.
- **Deleted highlights:** Leave tombstone entries in clippings. Dedup hash prevents re-import.
- **Missing author:** Some books have no author in parentheses. Author field nullable.
- **Page numbers vs locations:** Some books use `on page 42` instead of `Location`. Parse both.

### ParsedHighlight Struct

```swift
struct ParsedHighlight {
    let bookTitle: String       // "Book Title"
    let author: String?         // "Author Name" or nil
    let kindleTitle: String     // "Book Title (Author Name)" - raw string for dedup
    let content: String
    let location: String?       // "Location 1234-1256" or "page 42"
    let dateHighlighted: Date?
}
```

---

## Core Features

### MVP (Phase 1-2)

| Feature | Description |
|---------|-------------|
| Import | File picker or drag-drop `My Clippings.txt`, parse and dedupe |
| Book List | Sidebar showing all books, sorted by most recent highlight |
| Highlight View | Scrollable list of highlights for selected book |
| Favorites | Toggle star on highlights, filter to show favorites only |
| Basic Search | Full-text search across all highlight content |

### Post-MVP (Phase 3)

| Feature | Description |
|---------|-------------|
| Tags | Create tags with colors, assign multiple tags per highlight |
| Tag Filtering | Filter sidebar/highlights by tag |
| Export | Export selected highlights to Markdown |
| Keyboard Shortcuts | Navigate with arrows, `f` to favorite, `t` to tag, `Cmd+F` to search |
| Sort Options | Sort highlights by location (reading order) or date |

---

## UI Specifications

### Main Window Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  [Search: Cmd+F]                              [Import] [Settings]│
├──────────────────┬──────────────────────────────────────────────┤
│                  │                                              │
│  BOOKS           │  HIGHLIGHTS                                  │
│  ─────────────   │  ──────────────────────────────────────────  │
│                  │                                              │
│  📚 Book One     │  ┌────────────────────────────────────────┐  │
│     12 highlights│  │ ☆ "Quote text here..."                 │  │
│                  │  │   Location 234 · Jan 15, 2024          │  │
│  📚 Book Two     │  │   [tag1] [tag2]                        │  │
│     8 highlights │  └────────────────────────────────────────┘  │
│                  │                                              │
│  📚 Book Three   │  ┌────────────────────────────────────────┐  │
│     24 highlights│  │ ★ "Another quote..."                   │  │
│                  │  │   Location 567 · Jan 20, 2024          │  │
│  ───────────────│  │   [tag1] [+]                            │  │
│  Filters:        │  └────────────────────────────────────────┘  │
│  ☐ Favorites     │                                              │
│  ☐ Tag: [    ▼]  │                                              │
│                  │                                              │
└──────────────────┴──────────────────────────────────────────────┘
```

### Highlight Row Components

- **Favorite star:** Clickable toggle (filled/unfilled)
- **Content:** Highlight text (truncate with "..." if >3 lines, expand on click)
- **Metadata:** Location + date in muted text
- **Tags:** Horizontal stack of colored chips + "+" button to add

### Color Palette (Suggested Tag Colors)

```
Blue:    #3B82F6
Green:   #22C55E
Yellow:  #EAB308
Orange:  #F97316
Red:     #EF4444
Purple:  #A855F7
Pink:    #EC4899
Gray:    #6B7280
```

---

## Build Order

### Phase 1: Data Layer
1. [ ] Create Xcode project with SwiftUI lifecycle
2. [ ] Implement `DatabaseManager` with SQLite.swift or raw SQLite3
3. [ ] Create schema initialization and migration logic
4. [ ] Implement `ImportService` clippings parser
5. [ ] Write unit tests for parser edge cases

### Phase 2: Core UI
6. [ ] Build `ContentView` with NavigationSplitView
7. [ ] Implement `BookListView` and `BookRowView`
8. [ ] Implement `HighlightListView` and `HighlightRowView`
9. [ ] Wire up book selection → highlight display
10. [ ] Add Import button with file picker
11. [ ] Test full import → display flow

### Phase 3: Features
12. [ ] Add favorite toggle functionality
13. [ ] Implement favorites filter in sidebar
14. [ ] Build full-text search with FTS5
15. [ ] Create `SearchResultsView`

### Phase 4: Tags
16. [ ] Implement `Tag` model and CRUD in DatabaseManager
17. [ ] Build `TagManagerView` for Preferences
18. [ ] Create `TagChipView` and `TagPickerView`
19. [ ] Wire up tag assignment to highlights
20. [ ] Add tag filtering

### Phase 5: Polish
21. [ ] Add keyboard shortcuts
22. [ ] Implement drag-drop import
23. [ ] Add export to Markdown
24. [ ] Empty states and onboarding
25. [ ] App icon and final UI polish

---

## Configuration

### First Launch
1. Check for `~/Dropbox/Apps/KindleHighlights/` directory
2. If exists, use `highlights.db` there
3. If not, prompt user to select database location
4. Store selected path in UserDefaults

### Settings/Preferences
- Database location (with "Move Database" option)
- Tag management
- Default sort order

---

## Future Enhancements (Out of Scope for MVP)

- [ ] read.amazon.com scraper as alternative import method
- [ ] Notes support (separate from highlights)
- [ ] Spaced repetition / random highlight surfacing
- [ ] iOS companion app
- [ ] Obsidian/Markdown vault sync
- [ ] Book cover images (fetch from Open Library API)
- [ ] Reading statistics (highlights per month, etc.)
