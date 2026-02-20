import SwiftUI

struct TagChipView: View {
    let tag: Tag
    var showRemoveButton: Bool = false
    var onRemove: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.system(size: 11, weight: .medium))
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
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(tag.swiftUIColor.tagGradient())
                .overlay {
                    // Subtle inner highlight
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .subtleShadow()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
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
