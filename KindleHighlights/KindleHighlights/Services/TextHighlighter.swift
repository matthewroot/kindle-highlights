import Foundation
import SwiftUI

/// Utility for highlighting search terms in text using AttributedString
enum TextHighlighter {
    static func highlight(text: String, terms: [String]) -> AttributedString {
        var attributed = AttributedString(text)
        guard !text.isEmpty else { return attributed }

        for term in terms where !term.isEmpty {
            var searchStart = text.startIndex
            let lowerText = text.lowercased()
            let lowerTerm = term.lowercased()

            while let range = lowerText.range(of: lowerTerm, range: searchStart..<lowerText.endIndex) {
                let attrRange = AttributedString.Index(range.lowerBound, within: attributed)
                let attrEnd = AttributedString.Index(range.upperBound, within: attributed)

                if let attrRange, let attrEnd {
                    attributed[attrRange..<attrEnd].backgroundColor = .yellow.opacity(0.3)
                    attributed[attrRange..<attrEnd].font = .body.bold()
                }

                searchStart = range.upperBound
            }
        }

        return attributed
    }
}
