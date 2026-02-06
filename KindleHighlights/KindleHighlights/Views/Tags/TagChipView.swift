import SwiftUI

struct TagChipView: View {
    let tag: Tag
    var showRemoveButton: Bool = false
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(tag.name)
                .font(.caption)
                .foregroundStyle(.white)

            if showRemoveButton, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(tag.swiftUIColor)
        .clipShape(Capsule())
        .subtleShadow()
    }
}

#Preview {
    HStack {
        TagChipView(tag: Tag(id: 1, name: "Important", color: "#3B82F6"))
        TagChipView(tag: Tag(id: 2, name: "Review", color: "#22C55E"))
        TagChipView(
            tag: Tag(id: 3, name: "Philosophy", color: "#A855F7"),
            showRemoveButton: true,
            onRemove: {}
        )
    }
    .padding()
}
