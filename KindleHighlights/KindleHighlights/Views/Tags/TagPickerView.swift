import SwiftUI

struct TagPickerView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    let highlightId: Int64
    let currentTags: [Tag]
    var onTagsChanged: () -> Void

    @State private var allTags: [Tag] = []
    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#3B82F6"
    @State private var errorMessage: String?

    private let colorOptions = [
        "#3B82F6", "#22C55E", "#EAB308", "#F97316",
        "#EF4444", "#A855F7", "#EC4899", "#6B7280"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Tags")
                .font(.headline)

            if allTags.isEmpty && !isCreatingTag {
                Text("No tags yet. Create one to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(allTags) { tag in
                        tagButton(for: tag)
                    }
                }
            }

            Divider()

            if isCreatingTag {
                newTagForm
            } else {
                Button {
                    isCreatingTag = true
                } label: {
                    Label("New Tag", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.accent)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 280)
        .onAppear {
            loadTags()
        }
    }

    private func tagButton(for tag: Tag) -> some View {
        let isSelected = currentTags.contains(where: { $0.id == tag.id })

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                toggleTag(tag, isCurrentlySelected: isSelected)
            }
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(tag.name)
                    .lineLimit(1)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(tag.swiftUIColor.tagGradient())
                    .opacity(isSelected ? 1.0 : 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var newTagForm: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField("Tag name", text: $newTagName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            HStack(spacing: 6) {
                ForEach(colorOptions, id: \.self) { hex in
                    colorCircle(hex: hex)
                }
            }

            HStack {
                Button("Cancel") {
                    isCreatingTag = false
                    newTagName = ""
                    newTagColor = "#3B82F6"
                }
                .buttonStyle(.plain)
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

    private func colorCircle(hex: String) -> some View {
        Circle()
            .fill((Color(hex: hex) ?? .gray).tagGradient())
            .frame(width: 22, height: 22)
            .overlay {
                if newTagColor == hex {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .scaleEffect(newTagColor == hex ? 1.1 : 1.0)
            .subtleShadow()
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    newTagColor = hex
                }
            }
    }

    private func loadTags() {
        do {
            allTags = try databaseManager.getAllTags()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleTag(_ tag: Tag, isCurrentlySelected: Bool) {
        do {
            if isCurrentlySelected {
                try databaseManager.removeTag(tag.id, fromHighlight: highlightId)
            } else {
                try databaseManager.addTag(tag.id, toHighlight: highlightId)
            }
            onTagsChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        do {
            let tagId = try databaseManager.createTag(name: name, color: newTagColor)
            allTags = try databaseManager.getAllTags()

            // Auto-add the new tag to this highlight
            try databaseManager.addTag(tagId, toHighlight: highlightId)
            onTagsChanged()

            // Reset form
            isCreatingTag = false
            newTagName = ""
            newTagColor = "#3B82F6"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    TagPickerView(
        highlightId: 1,
        currentTags: [Tag(id: 1, name: "Important", color: "#3B82F6")],
        onTagsChanged: {}
    )
    .environmentObject(DatabaseManager())
}
