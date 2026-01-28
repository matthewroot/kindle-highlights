import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var action: (() -> Void)?
    var actionTitle: String?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let action = action, let actionTitle = actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("No Books") {
    EmptyStateView(
        title: "No Books",
        message: "Import your Kindle clippings to get started.",
        systemImage: "books.vertical",
        action: {},
        actionTitle: "Import Clippings"
    )
}

#Preview("Select a Book") {
    EmptyStateView(
        title: "Select a Book",
        message: "Choose a book from the sidebar to view its highlights.",
        systemImage: "text.quote"
    )
}
