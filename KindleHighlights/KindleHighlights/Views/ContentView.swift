import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @State private var selection: SidebarSelection?
    @State private var searchText = ""
    @State private var isImporting = false
    @State private var showingImportResult = false
    @State private var importResult: ImportResult?
    @State private var importError: String?
    @State private var isDropTargeted = false

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var hasContent: Bool {
        selection != nil || isSearching
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search highlights")
        .frame(minWidth: 700, minHeight: 500)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.blue, lineWidth: 3)
                    .background(.blue.opacity(0.1))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.largeTitle)
                            Text("Drop My Clippings.txt to Import")
                                .font(.headline)
                        }
                        .foregroundStyle(.blue)
                    }
                    .allowsHitTesting(false)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import Complete", isPresented: $showingImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = importResult {
                Text("Imported \(result.imported) new highlight\(result.imported == 1 ? "" : "s"). \(result.skipped) skipped (duplicates or errors).")
            }
        }
        .alert("Import Error", isPresented: .init(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = importError {
                Text(error)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .importClippings)) { _ in
            isImporting = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportMarkdown)) { _ in
            exportCurrentView()
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            if databaseManager.books.isEmpty {
                EmptyStateView(
                    title: "No Books",
                    message: "Import your Kindle clippings to get started.",
                    systemImage: "books.vertical",
                    action: { isImporting = true },
                    actionTitle: "Import Clippings"
                )
            } else {
                BookListView(selection: $selection)
            }
        }
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isImporting = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import My Clippings.txt (Cmd+I)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportCurrentView()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export to Markdown (Cmd+E)")
                .disabled(!hasContent)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if databaseManager.isLoading {
            ProgressView("Loading...")
        } else if isSearching {
            SearchResultsView(
                searchQuery: searchText,
                onToggleFavorite: { highlight in
                    toggleFavorite(highlight)
                }
            )
        } else if let selection = selection {
            switch selection {
            case .favorites:
                FavoritesListView()
            case .book(let book):
                HighlightListView(book: book)
            case .tag(let tag):
                TagHighlightsView(tag: tag)
            }
        } else {
            EmptyStateView(
                title: "Select a Book",
                message: "Choose a book from the sidebar to view its highlights.",
                systemImage: "text.quote"
            )
        }
    }

    // MARK: - Import

    private func toggleFavorite(_ highlight: Highlight) {
        do {
            try databaseManager.toggleFavorite(highlightId: highlight.id)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Need to access security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Could not access the selected file."
                return
            }

            // Read file content synchronously while we have security access
            let content: String
            do {
                content = try String(contentsOf: url, encoding: .utf8)
            } catch {
                url.stopAccessingSecurityScopedResource()
                importError = error.localizedDescription
                return
            }

            url.stopAccessingSecurityScopedResource()

            performImport(content: content)

        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, error in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                DispatchQueue.main.async {
                    importError = "Could not read the dropped file."
                }
                return
            }

            guard url.pathExtension.lowercased() == "txt" else {
                DispatchQueue.main.async {
                    importError = "Please drop a .txt file (My Clippings.txt from your Kindle)."
                }
                return
            }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                DispatchQueue.main.async {
                    performImport(content: content)
                }
            } catch {
                DispatchQueue.main.async {
                    importError = error.localizedDescription
                }
            }
        }
    }

    private func performImport(content: String) {
        Task {
            do {
                let result = try await databaseManager.importClippings(content: content)
                importResult = result
                showingImportResult = true

                if result.imported > 0 {
                    selection = nil
                }
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    // MARK: - Export

    private func exportCurrentView() {
        Task {
            let (highlights, title) = gatherExportData()
            guard !highlights.isEmpty else { return }

            let groupByBook = selection == nil || {
                if case .book = selection { return false }
                return true
            }()

            let markdown = ExportService.toMarkdown(
                highlights: highlights,
                title: title,
                groupByBook: groupByBook
            )

            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType.plainText]
            panel.nameFieldStringValue = sanitizeFilename(title ?? "kindle-highlights") + ".md"
            panel.title = "Export Highlights"

            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try markdown.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    importError = error.localizedDescription
                }
            }
        }
    }

    private func gatherExportData() -> ([Highlight], String?) {
        if isSearching {
            let results = (try? databaseManager.search(query: searchText)) ?? []
            return (results, "Search Results: \(searchText)")
        }

        guard let selection = selection else { return ([], nil) }

        switch selection {
        case .favorites:
            let highlights = (try? databaseManager.getFavoriteHighlights()) ?? []
            return (highlights, "Favorites")
        case .book(let book):
            let highlights = (try? databaseManager.getHighlights(forBook: book.id)) ?? []
            return (highlights, "\(book.title)\(book.author.map { " by \($0)" } ?? "")")
        case .tag(let tag):
            let highlights = (try? databaseManager.getHighlights(forTag: tag.id)) ?? []
            return (highlights, "Tag: \(tag.name)")
        }
    }

    private func sanitizeFilename(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        return name.unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
    }
}

#Preview {
    ContentView()
        .environmentObject(DatabaseManager())
}
