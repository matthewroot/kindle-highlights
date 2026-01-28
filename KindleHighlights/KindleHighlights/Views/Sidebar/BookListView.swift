import SwiftUI

struct BookListView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Favorites", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                    .tag(SidebarSelection.favorites)
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
    }
}

#Preview {
    BookListView(selection: .constant(nil))
        .environmentObject(DatabaseManager())
        .frame(width: 250)
}
