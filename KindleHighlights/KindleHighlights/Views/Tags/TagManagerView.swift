import SwiftUI

struct TagManagerView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @State private var tags: [Tag] = []
    @State private var editingTag: Tag?
    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#3B82F6"
    @State private var errorMessage: String?

    private let colorOptions = [
        "#3B82F6", "#22C55E", "#EAB308", "#F97316",
        "#EF4444", "#A855F7", "#EC4899", "#6B7280"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if tags.isEmpty && !isCreatingTag {
                ContentUnavailableView {
                    Label("No Tags", systemImage: "tag")
                } description: {
                    Text("Create tags to organize your highlights.")
                } actions: {
                    Button("Create Tag") {
                        isCreatingTag = true
                    }
                }
            } else {
                List {
                    ForEach(tags) { tag in
                        tagRow(for: tag)
                    }
                    .onDelete(perform: deleteTags)
                }
                .listStyle(.inset)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !tags.isEmpty || isCreatingTag {
                bottomBar
            }
        }
        .sheet(item: $editingTag) { tag in
            TagEditSheet(
                tag: tag,
                colorOptions: colorOptions,
                onSave: { name, color in
                    updateTag(tag, name: name, color: color)
                },
                onCancel: {
                    editingTag = nil
                }
            )
        }
        .onAppear {
            loadTags()
        }
        .navigationTitle("Manage Tags")
        .frame(minWidth: 300, minHeight: 200)
    }

    private func tagRow(for tag: Tag) -> some View {
        HStack {
            Circle()
                .fill(tag.swiftUIColor)
                .frame(width: 12, height: 12)

            Text(tag.name)

            Spacer()

            Button {
                editingTag = tag
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            if isCreatingTag {
                newTagForm
                    .padding()
            } else {
                HStack {
                    Button {
                        isCreatingTag = true
                    } label: {
                        Label("New Tag", systemImage: "plus")
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding()
            }
        }
        .background(.bar)
    }

    private var newTagForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Tag name", text: $newTagName)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Text("Color:")
                    .foregroundStyle(.secondary)

                ForEach(colorOptions, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if newTagColor == hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture {
                            newTagColor = hex
                        }
                }
            }

            HStack {
                Button("Cancel") {
                    isCreatingTag = false
                    newTagName = ""
                    newTagColor = "#3B82F6"
                }

                Spacer()

                Button("Create") {
                    createTag()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func loadTags() {
        do {
            tags = try databaseManager.getAllTags()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        do {
            try databaseManager.createTag(name: name, color: newTagColor)
            tags = try databaseManager.getAllTags()

            isCreatingTag = false
            newTagName = ""
            newTagColor = "#3B82F6"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateTag(_ tag: Tag, name: String, color: String) {
        do {
            try databaseManager.updateTag(id: tag.id, name: name, color: color)
            tags = try databaseManager.getAllTags()
            editingTag = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            do {
                try databaseManager.deleteTag(id: tag.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        loadTags()
    }
}

struct TagEditSheet: View {
    let tag: Tag
    let colorOptions: [String]
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var color: String

    init(tag: Tag, colorOptions: [String], onSave: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        self.tag = tag
        self.colorOptions = colorOptions
        self.onSave = onSave
        self.onCancel = onCancel
        self._name = State(initialValue: tag.name)
        self._color = State(initialValue: tag.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Tag")
                .font(.headline)

            TextField("Tag name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Text("Color:")
                    .foregroundStyle(.secondary)

                ForEach(colorOptions, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if color == hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture {
                            color = hex
                        }
                }
            }

            HStack {
                Button("Cancel", action: onCancel)

                Spacer()

                Button("Save") {
                    onSave(name.trimmingCharacters(in: .whitespaces), color)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

#Preview {
    TagManagerView()
        .environmentObject(DatabaseManager())
        .frame(width: 400, height: 300)
}
