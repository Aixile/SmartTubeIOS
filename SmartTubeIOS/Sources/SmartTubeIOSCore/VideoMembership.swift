import Foundation

public extension Video {
    static let membersOnlyBadge = "Members only"

    /// Based on explicit membership metadata, not a guess from the title or price.
    /// The canonical badge is persisted by Video's existing Codable representation.
    var isMembersOnly: Bool { badges.contains(Self.membersOnlyBadge) }
}

enum VideoMembershipParser {
    static func badges(in renderer: [String: Any], existing: [String] = []) -> [String] {
        // Restrict inspection to badge/metadata areas. Titles, channel names and
        // menu actions mentioning membership must never classify a public video.
        let areas = ["badges", "thumbnailOverlays", "header", "metadata", "contentImage", "thumbnailViewModel"]
        guard areas.contains(where: { containsMembership(renderer[$0] as Any) }) else { return existing }
        return existing.contains(Video.membersOnlyBadge) ? existing : existing + [Video.membersOnlyBadge]
    }

    private static func containsMembership(_ value: Any, depth: Int = 0) -> Bool {
        guard depth < 16 else { return false }
        if let values = value as? [Any] {
            return values.contains { containsMembership($0, depth: depth + 1) }
        }
        guard let dict = value as? [String: Any] else { return false }
        if dict["thumbnailOverlayMembershipBadgeRenderer"] != nil { return true }
        for key in ["style", "badgeStyle", "iconType"] {
            if let signal = dict[key] as? String,
                signal.contains("MEMBERS_ONLY") || signal.contains("MEMBERSHIP") || signal == "SPONSOR_ONLY"
            {
                return true
            }
        }
        for key in ["label", "text", "simpleText", "content"] {
            if let label = dict[key] as? String, isMembershipLabel(label) { return true }
        }
        return dict.contains { key, child in
            // Metadata also contains the title and uploader. Ignore both.
            guard
                !["title", "primaryText", "ownerBadges", "ownerText", "navigationEndpoint", "commandRuns"].contains(key)
            else { return false }
            if key == "lines", let lines = child as? [Any] {
                return lines.dropFirst().contains { containsMembership($0, depth: depth + 1) }
            }
            if key == "metadataRows", let rows = child as? [Any] {
                return rows.dropFirst().contains { containsMembership($0, depth: depth + 1) }
            }
            return containsMembership(child, depth: depth + 1)
        }
    }

    private static func isMembershipLabel(_ label: String) -> Bool {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "-", with: " ")
        return ["members only", "member only", "members first", "member exclusive"].contains(normalized)
    }
}
