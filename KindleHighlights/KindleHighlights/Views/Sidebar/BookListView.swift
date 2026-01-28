import SwiftUI

struct BookListView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @Binding var selectedBook: Book?

    var body: some View {
        List(databaseManager.books, selection: $selectedBook) { book in
            BookRowView(book: book)
                .tag(book)
        }
        .listStyle(.sidebar)
        .navigationTitle("Books")
    }
}

#Preview {
    BookListView(selectedBook: .constant(nil))
        .environmentObject(DatabaseManager())
        .frame(width: 250)
}
