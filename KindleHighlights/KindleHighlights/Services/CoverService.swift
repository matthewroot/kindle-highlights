import Foundation

/// Fetches and manages book cover images from Open Library
enum CoverService {
    private struct SearchResponse: Decodable {
        let docs: [SearchDoc]
    }

    private struct SearchDoc: Decodable {
        let cover_i: Int?
    }

    static var coversDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("KindleHighlights/covers", isDirectory: true)
    }

    static func fetchCover(title: String, author: String?) async -> String? {
        do {
            var queryParts = title
            if let author {
                queryParts += " " + author
            }

            guard let encoded = queryParts.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let searchURL = URL(string: "https://openlibrary.org/search.json?q=\(encoded)&limit=1&fields=cover_i") else {
                return nil
            }

            let (data, _) = try await URLSession.shared.data(from: searchURL)
            let response = try JSONDecoder().decode(SearchResponse.self, from: data)

            guard let coverId = response.docs.first?.cover_i else {
                return nil
            }

            guard let coverURL = URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg") else {
                return nil
            }

            let (imageData, _) = try await URLSession.shared.data(from: coverURL)

            // Ensure covers directory exists
            try FileManager.default.createDirectory(at: coversDirectory, withIntermediateDirectories: true)

            let filename = "\(coverId).jpg"
            let filePath = coversDirectory.appendingPathComponent(filename)
            try imageData.write(to: filePath)

            return filename
        } catch {
            return nil
        }
    }

    static func deleteCover(filename: String) {
        let filePath = coversDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: filePath)
    }
}
