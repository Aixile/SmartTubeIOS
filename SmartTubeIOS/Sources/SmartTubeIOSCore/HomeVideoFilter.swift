import Foundation

/// Refinements of the recommendation videos already loaded, preserving YouTube order by default.
public struct HomeVideoFilter: Codable, Equatable, Sendable {
    public typealias Kind = ChannelVideoFilter.Kind
    public typealias WatchStatus = ChannelVideoFilter.WatchStatus
    public typealias Duration = ChannelVideoFilter.Duration

    public enum UploadDate: String, Codable, CaseIterable, Sendable {
        case all = "Any upload date"
        case day = "Last 24 hours"
        case week = "Last 7 days"
        case month = "Last 30 days"

        private static let secondsPerDay: TimeInterval = 24 * 60 * 60

        func includes(_ date: Date?, now: Date) -> Bool {
            guard self != .all else { return true }
            guard let date else { return false }
            let days: Double
            switch self {
            case .all: return true
            case .day: days = 1
            case .week: days = 7
            case .month: days = 30
            }
            let age = now.timeIntervalSince(date)
            return age >= 0 && age <= days * Self.secondsPerDay
        }
    }

    public enum Sort: String, Codable, CaseIterable, Sendable {
        case recommended = "Recommended order"
        case newest = "Newest first"
        case views = "Most viewed"
        case shortest = "Shortest first"
        case longest = "Longest first"
    }

    public enum Grouping: String, Codable, CaseIterable, Sendable {
        case none = "No grouping"
        case channel = "Channel"
        case type = "Video type"
    }

    public var kind: Kind = .all
    public var watchStatus: WatchStatus = .all
    public var duration: Duration = .all
    public var uploadDate: UploadDate = .all
    public var sort: Sort = .recommended
    public var grouping: Grouping = .none
    public var query = ""

    public init() {}

    public var activeLabels: [String] {
        var labels: [String] = []
        if kind != .all { labels.append(kind.rawValue) }
        if watchStatus != .all { labels.append(watchStatus.rawValue) }
        if duration != .all { labels.append(duration.rawValue) }
        if uploadDate != .all { labels.append(uploadDate.rawValue) }
        if sort != .recommended { labels.append(sort.rawValue) }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { labels.append("Search: \(trimmed)") }
        if grouping != .none { labels.append("Grouped by \(grouping.rawValue.lowercased())") }
        return labels
    }

    public var activeCount: Int { activeLabels.count - (grouping == .none ? 0 : 1) }
    public var isActive: Bool { activeCount > 0 || grouping != .none }

    public func groups(in videos: [Video]) -> [HomeVideoGroup] {
        guard grouping != .none else { return [HomeVideoGroup(id: "all", title: nil, videos: videos)] }
        var order: [String] = []
        var titles: [String: String] = [:]
        var grouped: [String: [Video]] = [:]
        for video in videos {
            let id: String
            let title: String
            switch grouping {
            case .none: continue
            case .channel:
                title = video.channelTitle.isEmpty ? "Unknown channel" : video.channelTitle
                id = "channel:\(video.channelId.flatMap { $0.isEmpty ? nil : $0 } ?? title)"
            case .type:
                let kind: Kind = video.isLive || video.isUpcoming ? .live : (video.isShort ? .shorts : .videos)
                id = "type:\(kind.rawValue)"
                title = kind.rawValue
            }
            if grouped[id] == nil {
                order.append(id)
                titles[id] = title
            }
            grouped[id, default: []].append(video)
        }
        return order.map { HomeVideoGroup(id: $0, title: titles[$0], videos: grouped[$0] ?? []) }
    }

    public func apply(
        to videos: [Video], settings: AppSettings, watchedVideoIDs: Set<String> = [], now: Date = Date()
    ) -> [Video] {
        var common = ChannelVideoFilter()
        common.kind = kind
        common.watchStatus = watchStatus
        common.duration = duration
        let candidates = common.apply(
            to: videos, hideShorts: settings.hideShorts,
            watchedThreshold: settings.hideWatchedThreshold, watchedVideoIDs: watchedVideoIDs)
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        var seen = Set<String>()
        let matches = candidates.filter { video in
            guard seen.insert(video.id).inserted else { return false }
            if kind != .live {
                if settings.hideLiveShorts && video.isLive && video.isShort { return false }
                if settings.hideVideoPremieres && video.isUpcoming { return false }
            }
            if watchStatus == .all && settings.hideWatchedVideos
                && (watchedVideoIDs.contains(video.id) || video.isWatched(threshold: settings.hideWatchedThreshold))
            {
                return false
            }
            return uploadDate.includes(video.publishedAt, now: now)
                && words.allSatisfy {
                    video.title.localizedStandardContains($0) || video.channelTitle.localizedStandardContains($0)
                }
        }
        guard sort != .recommended else { return matches }
        return matches.enumerated().sorted { left, right in
            let lhs = sortValue(left.element)
            let rhs = sortValue(right.element)
            guard let lhs else { return rhs == nil && left.offset < right.offset }
            guard let rhs else { return true }
            if lhs == rhs { return left.offset < right.offset }
            return sort == .shortest ? lhs < rhs : lhs > rhs
        }.map(\.element)
    }

    private func sortValue(_ video: Video) -> Double? {
        switch sort {
        case .recommended: return nil
        case .newest: return video.publishedAt?.timeIntervalSince1970
        case .views: return video.viewCount.map(Double.init)
        case .shortest, .longest: return video.duration
        }
    }
}

public struct HomeVideoGroup: Identifiable, Sendable {
    public let id: String
    public let title: String?
    public let videos: [Video]
}
