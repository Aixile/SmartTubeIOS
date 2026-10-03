import Foundation

extension InnerTubeAPI {
    /// Modern WEB lockups keep duration/live state in thumbnail badges rather
    /// than the legacy lengthText/metadataBadgeRenderer fields.
    func thumbnailBadgeMetadata(_ thumbnail: [String: Any]?) -> (duration: TimeInterval?, isLive: Bool) {
        var texts: [String] = []
        func walk(_ value: Any, depth: Int = 0) {
            guard depth < 12 else { return }
            if let items = value as? [Any] {
                for item in items { walk(item, depth: depth + 1) }
            } else if let dict = value as? [String: Any] {
                for key in ["text", "label", "style", "iconType"] {
                    if let text = dict[key] as? String { texts.append(text) }
                }
                for child in dict.values { walk(child, depth: depth + 1) }
            }
        }
        walk(thumbnail?["overlays"] as Any)
        let duration = texts.first { text in
            let parts = text.split(separator: ":", omittingEmptySubsequences: false)
            return (2...3).contains(parts.count) && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
        }.flatMap { parseDuration($0) }
        let isLive = texts.contains { ["LIVE", "LIVE_NOW", "BADGE_STYLE_TYPE_LIVE_NOW"].contains($0.uppercased()) }
        return (duration, isLive)
    }
}
