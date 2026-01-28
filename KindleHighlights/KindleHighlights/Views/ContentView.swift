import SwiftUI

struct ContentView: View {
    @EnvironmentObject var databaseManager: DatabaseManager

    var body: some View {
        NavigationSplitView {
            Text("Books Sidebar")
                .frame(minWidth: 200)
        } detail: {
            Text("Select a book to view highlights")
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

#Preview {
    ContentView()
        .environmentObject(DatabaseManager())
}
