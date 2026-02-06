import SwiftUI

// MARK: - Spacing System

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Corner Radius

enum CornerRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
}

// MARK: - Semantic Colors

enum AppColor {
    static let accent = Color.accentColor
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    static let favorite = Color.yellow
}

// MARK: - Shadow Modifiers

extension View {
    func subtleShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}
