import SwiftUI

// MARK: - Spacing System

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius

enum CornerRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
}

// MARK: - Semantic Colors

enum AppColor {
    static let accent = Color.accentColor
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    static let favorite = Color.orange
    static let favoriteGlow = Color.orange.opacity(0.4)
}

// MARK: - Shadow Styles

extension View {
    /// Subtle shadow for small elements like tags
    func subtleShadow() -> some View {
        self.shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
    }

    /// Medium shadow for cards and covers
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    /// Elevated shadow for floating elements
    func elevatedShadow() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Glass Background Modifier

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.md

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            }
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = CornerRadius.md) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}

// MARK: - Hover Highlight Modifier

struct HoverHighlight: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.sm
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    func hoverHighlight(cornerRadius: CGFloat = CornerRadius.sm) -> some View {
        modifier(HoverHighlight(cornerRadius: cornerRadius))
    }
}

// MARK: - Favorite Star View

struct FavoriteStarView: View {
    let isFavorite: Bool
    let action: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        }) {
            ZStack {
                // Glow effect for favorited items
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColor.favoriteGlow)
                        .blur(radius: 6)
                        .opacity(0.8)
                }

                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(isFavorite ? AppColor.favorite : .secondary)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Gradient Tag Background

extension Color {
    /// Creates a subtle gradient for tag backgrounds
    func tagGradient() -> LinearGradient {
        LinearGradient(
            colors: [self, self.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Quote Typography

extension View {
    /// Applies refined quote styling
    func quoteStyle() -> some View {
        self
            .font(.system(size: 14, weight: .regular, design: .serif))
            .lineSpacing(4)
    }
}
