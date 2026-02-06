import SwiftUI

struct BookListView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @Binding var selection: SidebarSelection?

    @State private var showingTagManager = false
    @State private var isHoveringTagsHeader = false

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Favorites", systemImage: "star.fill")
                    .foregroundStyle(AppColor.favorite)
                    .tag(SidebarSelection.favorites)
            }

            if !databaseManager.tags.isEmpty {
                Section {
                    ForEach(databaseManager.tags) { tag in
                        Label {
                            Text(tag.name)
                        } icon: {
                            Circle()
                                .fill(tag.swiftUIColor.tagGradient())
                                .frame(width: 10, height: 10)
                        }
                        .tag(SidebarSelection.tag(tag))
                    }
                } header: {
                    HStack(spacing: Spacing.xs) {
                        Text("Tags")

                        Button {
                            showingTagManager = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .opacity(isHoveringTagsHeader ? 1 : 0)

                        Spacer()
                    }
                    .onHover { hovering in
                        isHoveringTagsHeader = hovering
                    }
                }
            }

            Section("Books") {
                ForEach(databaseManager.books) { book in
                    BookRowView(book: book)
                        .tag(SidebarSelection.book(book))
                        .contextMenu {
                            Button(book.coverImagePath != nil ? "Refresh Cover" : "Fetch Cover") {
                                Task { await databaseManager.fetchCover(for: book) }
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Library")
        .sheet(isPresented: $showingTagManager) {
            TagManagerSheet()
                .environmentObject(databaseManager)
        }
    }
}

/// Wraps TagManagerView in a sheet with a close button
struct TagManagerSheet: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TagManagerView()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .frame(minWidth: 350, minHeight: 300)
    }
}

#Preview {
    BookListView(selection: .constant(nil))
        .environmentObject(DatabaseManager())
        .frame(width: 250)
}
