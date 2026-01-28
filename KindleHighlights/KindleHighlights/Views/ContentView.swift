import SwiftUI

struct ContentView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @State private var selection: SidebarSelection?
    @State private var searchText = ""
    @State private var isImporting = false
    @State private var showingImportResult = false
    @State private var importResult: ImportResult?
    @State private var importError: String?

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search highlights")
        .frame(minWidth: 700, minHeight: 500)
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
                .help("Import My Clippings.txt")
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
            }
        } else {
            EmptyStateView(
                title: "Select a Book",
                message: "Choose a book from the sidebar to view its highlights.",
                systemImage: "text.quote"
            )
        }
    }

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

            // Process content asynchronously
            Task {
                do {
                    let result = try await databaseManager.importClippings(content: content)
                    importResult = result
                    showingImportResult = true

                    // Clear selection if we imported new books
                    if result.imported > 0 {
                        selection = nil
                    }
                } catch {
                    importError = error.localizedDescription
                }
            }

        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DatabaseManager())
}
