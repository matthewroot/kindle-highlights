import SwiftUI

struct BookListView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @Binding var selection: SidebarSelection?

    @State private var tags: [Tag] = []

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Favorites", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                    .tag(SidebarSelection.favorites)
            }

            if !tags.isEmpty {
                Section("Tags") {
                    ForEach(tags) { tag in
                        Label {
                            Text(tag.name)
                        } icon: {
                            Circle()
                                .fill(tag.swiftUIColor)
                                .frame(width: 10, height: 10)
                        }
                        .tag(SidebarSelection.tag(tag))
                    }
                }
            }

            Section("Books") {
                ForEach(databaseManager.books) { book in
                    BookRowView(book: book)
                        .tag(SidebarSelection.book(book))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Library")
        .onAppear {
            loadTags()
        }
    }

    private func loadTags() {
        do {
            tags = try databaseManager.getAllTags()
        } catch {
            tags = []
        }
    }
}

#Preview {
    BookListView(selection: .constant(nil))
        .environmentObject(DatabaseManager())
        .frame(width: 250)
}
