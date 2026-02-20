import SwiftUI

enum CoverSize {
    case small
    case large

    var width: CGFloat {
        switch self {
        case .small: return 44
        case .large: return 90
        }
    }

    var height: CGFloat {
        switch self {
        case .small: return 66
        case .large: return 135
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return CornerRadius.sm
        case .large: return CornerRadius.md
        }
    }
}

struct BookCoverView: View {
    let book: Book
    let size: CoverSize
    var isFetching: Bool = false

    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        coverContent
            .cardShadow()
    }

    @ViewBuilder
    private var coverContent: some View {
        if let coverPath = book.coverImagePath,
           let nsImage = CoverImageCache.shared.image(for: coverPath) {
            // Actual cover image
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
                .overlay {
                    // Subtle gradient overlay for depth
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    // Inner highlight
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
        } else if isFetching {
            // Shimmer loading state
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .fill(.quaternary)
                .frame(width: size.width, height: size.height)
                .overlay {
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerPhase * (size.width + 40) - 20)
                        .mask(RoundedRectangle(cornerRadius: size.cornerRadius))
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        shimmerPhase = 1
                    }
                }
        } else {
            // Placeholder with icon
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color(nsColor: .systemGray).opacity(0.3), Color(nsColor: .systemGray).opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.width, height: size.height)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .font(size == .small ? .system(size: 16) : .system(size: 28))
                        .foregroundStyle(.tertiary)
                }
        }
    }
}
