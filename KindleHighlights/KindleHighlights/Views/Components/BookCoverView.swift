import SwiftUI

enum CoverSize {
    case small
    case large

    var width: CGFloat {
        switch self {
        case .small: return 40
        case .large: return 80
        }
    }

    var height: CGFloat {
        switch self {
        case .small: return 60
        case .large: return 120
        }
    }
}

struct BookCoverView: View {
    let book: Book
    let size: CoverSize
    var isFetching: Bool = false

    @State private var shimmerOpacity: Double = 0.3

    var body: some View {
        if let coverPath = book.coverImagePath,
           let nsImage = CoverImageCache.shared.image(for: coverPath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if isFetching {
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(width: size.width, height: size.height)
                .opacity(shimmerOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        shimmerOpacity = 0.7
                    }
                }
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(width: size.width, height: size.height)
                .overlay {
                    Image(systemName: "book.closed")
                        .font(size == .small ? .caption : .title3)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
