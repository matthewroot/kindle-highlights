import AppKit

/// In-memory cache for book cover images, backed by disk
final class CoverImageCache {
    static let shared = CoverImageCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {}

    func image(for filename: String) -> NSImage? {
        let key = filename as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let filePath = CoverService.coversDirectory.appendingPathComponent(filename)
        guard let image = NSImage(contentsOf: filePath) else {
            return nil
        }

        cache.setObject(image, forKey: key)
        return image
    }

    func set(_ image: NSImage, for filename: String) {
        cache.setObject(image, forKey: filename as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}
