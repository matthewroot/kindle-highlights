import SwiftUI

struct TagManagerView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @State private var tags: [Tag] = []
    @State private var editingTag: Tag?
    @State private var deletingTag: Tag?
    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#3B82F6"
    @State private var errorMessage: String?
    @State private var hoveredTagId: Int64?

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
        .alert("Delete Tag", isPresented: .init(
            get: { deletingTag != nil },
            set: { if !$0 { deletingTag = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                deletingTag = nil
            }
            Button("Delete", role: .destructive) {
                if let tag = deletingTag {
                    deleteTag(tag)
                }
            }
        } message: {
            if let tag = deletingTag {
                Text("Are you sure you want to delete \"\(tag.name)\"? This will remove it from all highlights.")
            }
        }
        .onAppear {
            loadTags()
        }
        .navigationTitle("Manage Tags")
        .frame(minWidth: 300, minHeight: 200)
    }

    private func tagRow(for tag: Tag) -> some View {
        let isHovered = hoveredTagId == tag.id

        return HStack(spacing: Spacing.md) {
            Circle()
                .fill(tag.swiftUIColor.tagGradient())
                .frame(width: 14, height: 14)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
                .subtleShadow()

            Text(tag.name)
                .font(.system(size: 14))

            Spacer()

            HStack(spacing: Spacing.sm) {
                Button {
                    editingTag = tag
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)

                Button {
                    deletingTag = tag
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredTagId = hovering ? tag.id : nil
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            if isCreatingTag {
                newTagForm
                    .padding(Spacing.lg)
            } else {
                HStack {
                    Button {
                        isCreatingTag = true
                    } label: {
                        Label("New Tag", systemImage: "plus")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColor.accent)

                    Spacer()
                }
                .padding(Spacing.lg)
            }
        }
        .background(.bar)
    }

    private var newTagForm: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField("Tag name", text: $newTagName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            HStack(spacing: 6) {
                ForEach(colorOptions, id: \.self) { hex in
                    colorCircle(hex: hex, selectedColor: $newTagColor)
                }
            }

            HStack {
                Button("Cancel") {
                    isCreatingTag = false
                    newTagName = ""
                    newTagColor = "#3B82F6"
                }
                .font(.system(size: 12))

                Spacer()

                Button("Create") {
                    createTag()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func colorCircle(hex: String, selectedColor: Binding<String>) -> some View {
        Circle()
            .fill((Color(hex: hex) ?? .gray).tagGradient())
            .frame(width: 24, height: 24)
            .overlay {
                if selectedColor.wrappedValue == hex {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .scaleEffect(selectedColor.wrappedValue == hex ? 1.1 : 1.0)
            .subtleShadow()
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedColor.wrappedValue = hex
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

    private func deleteTag(_ tag: Tag) {
        do {
            try databaseManager.deleteTag(id: tag.id)
            loadTags()
            deletingTag = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Edit Tag")
                .font(.headline)

            TextField("Tag name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            HStack(spacing: 6) {
                ForEach(colorOptions, id: \.self) { hex in
                    Circle()
                        .fill((Color(hex: hex) ?? .gray).tagGradient())
                        .frame(width: 24, height: 24)
                        .overlay {
                            if color == hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        }
                        .scaleEffect(color == hex ? 1.1 : 1.0)
                        .subtleShadow()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                color = hex
                            }
                        }
                }
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .font(.system(size: 12))

                Spacer()

                Button("Save") {
                    onSave(name.trimmingCharacters(in: .whitespaces), color)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 320)
    }
}

#Preview {
    TagManagerView()
        .environmentObject(DatabaseManager())
        .frame(width: 400, height: 300)
}
