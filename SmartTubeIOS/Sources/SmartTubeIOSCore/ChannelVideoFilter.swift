import Foundation

/// Local refinements of the channel videos already returned by YouTube.
public struct ChannelVideoFilter: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Codable, Sendable {
        case all = "All"
        case videos = "Videos"
        case shorts = "Shorts"
        case live = "Live / upcoming"
    }

    public enum Access: String, CaseIterable, Sendable {
        case all = "All videos"
        case regular = "Regular"
        case members = "Members only"
    }

    public enum WatchStatus: String, CaseIterable, Codable, Sendable {
        case all = "Any watch status"
        case unwatched = "Unwatched"
        case watched = "Watched"
    }

    public enum Duration: String, CaseIterable, Codable, Sendable {
        case all = "Any duration"
        case short = "Under 4 minutes"
        case medium = "4–20 minutes"
        case long = "Over 20 minutes"

        private static let shortLimit: TimeInterval = 4 * 60
        private static let longLimit: TimeInterval = 20 * 60

        func includes(_ duration: TimeInterval?) -> Bool {
            if self == .all { return true }
            guard let duration else { return false }
            switch self {
            case .all: return true
            case .short: return duration < Self.shortLimit
            case .medium: return duration >= Self.shortLimit && duration <= Self.longLimit
            case .long: return duration > Self.longLimit
            }
        }
    }

    public enum Sort: String, CaseIterable, Sendable {
        case channel = "Channel order"
        case newest = "Newest first"
        case oldest = "Oldest first"
        case views = "Most viewed"
    }

    public var kind: Kind = .all
    public var access: Access = .all
    public var watchStatus: WatchStatus = .all
    public var duration: Duration = .all
    public var sort: Sort = .channel
    public var query = ""

    public init() {}

    public var activeCount: Int {
        [kind != .all, access != .all, watchStatus != .all, duration != .all, sort != .channel]
            .filter { $0 }.count
    }

    public var isActive: Bool { activeCount > 0 || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public func apply(
        to videos: [Video], hideShorts: Bool, watchedThreshold: Double, watchedVideoIDs: Set<String> = []
    ) -> [Video] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        let filtered = videos.filter { video in
            if kind == .all && hideShorts && video.isShort { return false }
            switch kind {
            case .all: break
            case .videos: if video.isShort || video.isLive || video.isUpcoming { return false }
            case .shorts: if !video.isShort { return false }
            case .live: if !video.isLive && !video.isUpcoming { return false }
            }
            switch access {
            case .all: break
            case .regular: if video.isMembersOnly { return false }
            case .members: if !video.isMembersOnly { return false }
            }
            let watched = watchedVideoIDs.contains(video.id) || video.isWatched(threshold: watchedThreshold)
            switch watchStatus {
            case .all: break
            case .unwatched: if watched { return false }
            case .watched: if !watched { return false }
            }
            return duration.includes(video.duration) && words.allSatisfy { video.title.localizedStandardContains($0) }
        }
        // Keep source order for equal/unknown metadata; unknown values always go last.
        return filtered.enumerated().sorted { left, right in
            let lhs: Double?
            let rhs: Double?
            switch sort {
            case .channel: return left.offset < right.offset
            case .newest, .oldest:
                lhs = left.element.publishedAt?.timeIntervalSince1970
                rhs = right.element.publishedAt?.timeIntervalSince1970
            case .views:
                lhs = left.element.viewCount.map(Double.init)
                rhs = right.element.viewCount.map(Double.init)
            }
            guard let lhs else { return rhs == nil && left.offset < right.offset }
            guard let rhs else { return true }
            if lhs == rhs { return left.offset < right.offset }
            return sort == .oldest ? lhs < rhs : lhs > rhs
        }.map(\.element)
    }
}
