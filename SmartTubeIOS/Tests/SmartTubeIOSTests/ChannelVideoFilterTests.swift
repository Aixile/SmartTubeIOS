import Foundation
import Testing

@testable import SmartTubeIOSCore

private extension InnerTubeAPI {
    func membershipGroupsForTesting(_ data: Data) throws -> (VideoGroup, VideoGroup) {
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return (
            try parseVideoGroup(from: json, title: nil, includeMembersOnly: true),
            try parseVideoGroup(from: json, title: nil)
        )
    }
}

@Suite("Channel video filters")
struct ChannelVideoFilterTests {
    private let videos = [
        Video(
            id: "regular", title: "Swift café tour", channelTitle: "Creator", duration: 240, viewCount: 20,
            publishedAt: Date(timeIntervalSince1970: 100), watchProgress: 0.95),
        Video(
            id: "member", title: "Swift bonus", channelTitle: "Creator", duration: 1201, viewCount: 10,
            publishedAt: Date(timeIntervalSince1970: 200), badges: [Video.membersOnlyBadge]),
        Video(id: "short", title: "Quick tour", channelTitle: "Creator", duration: 30, isShort: true),
        Video(id: "live", title: "Live lesson", channelTitle: "Creator", isLive: true),
        Video(id: "upcoming", title: "Next lesson", channelTitle: "Creator", isUpcoming: true),
    ]

    private func ids(_ filter: ChannelVideoFilter, hideShorts: Bool = false) -> [String] {
        filter.apply(to: videos, hideShorts: hideShorts, watchedThreshold: 0.9).map(\.id)
    }

    @Test("Membership, duration, watched status and title search compose")
    func combined() {
        var filter = ChannelVideoFilter()
        filter.access = .regular
        filter.kind = .videos
        filter.duration = .medium
        filter.watchStatus = .watched
        filter.query = "  CAFE swift "
        #expect(ids(filter) == ["regular"])
        filter.access = .members
        #expect(ids(filter).isEmpty)
        filter = ChannelVideoFilter()
        filter.access = .members
        #expect(ids(filter) == ["member"])
    }

    @Test("Explicit Shorts overrides Hide Shorts; normal videos exclude live and upcoming")
    func kinds() {
        var filter = ChannelVideoFilter()
        #expect(!ids(filter, hideShorts: true).contains("short"))
        filter.kind = .shorts
        #expect(ids(filter, hideShorts: true) == ["short"])
        filter.kind = .videos
        #expect(ids(filter) == ["regular", "member"])
        filter.kind = .live
        #expect(ids(filter) == ["live", "upcoming"])
    }

    @Test("Sorting keeps unknown metadata last and equal values in channel order")
    func sorting() {
        var filter = ChannelVideoFilter()
        filter.sort = .newest
        #expect(ids(filter) == ["member", "regular", "short", "live", "upcoming"])
        filter.sort = .oldest
        #expect(ids(filter) == ["regular", "member", "short", "live", "upcoming"])
        filter.sort = .views
        #expect(ids(filter) == ["regular", "member", "short", "live", "upcoming"])
    }

    @Test("Duration boundaries do not overlap and unknown durations do not falsely match")
    func durations() {
        #expect(ChannelVideoFilter.Duration.short.includes(239))
        #expect(!ChannelVideoFilter.Duration.short.includes(240))
        #expect(ChannelVideoFilter.Duration.medium.includes(240))
        #expect(ChannelVideoFilter.Duration.medium.includes(1200))
        #expect(!ChannelVideoFilter.Duration.long.includes(1200))
        #expect(ChannelVideoFilter.Duration.long.includes(1201))
        #expect(!ChannelVideoFilter.Duration.short.includes(nil))
    }

    @Test("Local history marks watched videos even when YouTube omits progress")
    func localHistory() {
        var filter = ChannelVideoFilter()
        filter.watchStatus = .watched
        let result = filter.apply(to: videos, hideShorts: false, watchedThreshold: 0.9, watchedVideoIDs: ["member"])
        #expect(result.map(\.id) == ["regular", "member"])
    }
}

@Suite("Channel membership metadata")
struct ChannelMembershipTests {
    @Test(
        "Channel listings preserve membership badges across renderer formats",
        arguments: [
            "videoRenderer", "gridVideoRenderer", "compactVideoRenderer", "playlistVideoRenderer", "reelItemRenderer",
            "tileRenderer", "lockupViewModel",
        ])
    func rendererMembership(kind: String) async throws {
        let api = InnerTubeAPI()
        let badge: [String: Any] = [
            "metadataBadgeRenderer": ["style": "BADGE_STYLE_TYPE_MEMBERS_ONLY", "label": "會員專屬"]
        ]
        var renderer: [String: Any] = [
            "videoId": "member", "title": ["simpleText": "Bonus"], "badges": [badge],
        ]
        if kind == "tileRenderer" {
            renderer["contentType"] = "TILE_CONTENT_TYPE_VIDEO"
            renderer["onSelectCommand"] = ["watchEndpoint": ["videoId": "member"]]
        }
        if kind == "lockupViewModel" {
            renderer["rendererContext"] = [
                "commandContext": ["onTap": ["innertubeCommand": ["watchEndpoint": ["videoId": "member"]]]]
            ]
        }
        let json: [String: Any] = ["contents": [[kind: renderer]]]
        let (group, homeGroup) = try await api.membershipGroupsForTesting(JSONSerialization.data(withJSONObject: json))
        let video = try #require(group.videos.first)
        #expect(video.isMembersOnly)
        #expect(try JSONDecoder().decode(Video.self, from: JSONEncoder().encode(video)).isMembersOnly)
        #expect(homeGroup.videos.isEmpty)
    }

    @Test("Titles and uploader names mentioning membership do not turn regular videos into paid videos")
    func falsePositives() {
        let renderer: [String: Any] = [
            "title": ["simpleText": "Members only"],
            "ownerBadges": [["metadataBadgeRenderer": ["label": "Members only"]]],
            "metadata": [
                "lockupMetadataViewModel": [
                    "title": ["content": "Members only"],
                    "metadata": [
                        "contentMetadataViewModel": [
                            "metadataRows": [
                                ["metadataParts": [["text": ["content": "Members only"]]]]
                            ]
                        ]
                    ],
                ]
            ],
        ]
        #expect(VideoMembershipParser.badges(in: renderer).isEmpty)
        #expect(!Video(id: "regular", title: "Members only", channelTitle: "Creator").isMembersOnly)
    }

    @Test("Modern thumbnail badge labels preserve membership without relying on English titles")
    func modernBadge() {
        let renderer: [String: Any] = [
            "contentImage": [
                "thumbnailViewModel": [
                    "overlays": [
                        [
                            "thumbnailOverlayBadgeViewModel": [
                                "thumbnailBadges": [["badgeViewModel": ["text": "Members only"]]]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        #expect(VideoMembershipParser.badges(in: renderer) == [Video.membersOnlyBadge])
    }

    @Test("Modern thumbnail badges provide duration and live state for channel filters")
    func thumbnailMetadata() async {
        let api = InnerTubeAPI()
        let duration = await api.thumbnailBadgeMetadata([
            "overlays": [
                ["thumbnailOverlayBadgeViewModel": ["thumbnailBadges": [["badgeViewModel": ["text": "12:34"]]]]]
            ]
        ])
        #expect(duration.duration == 754)
        #expect(!duration.isLive)
        let live = await api.thumbnailBadgeMetadata([
            "overlays": [
                ["thumbnailOverlayBadgeViewModel": ["thumbnailBadges": [["badgeViewModel": ["text": "LIVE"]]]]]
            ]
        ])
        #expect(live.isLive)
        #expect(live.duration == nil)
    }
}

private actor ChannelPagesFake: ChannelBrowsingAPI {
    private var pageCalls = 0
    private var suspendedPage: CheckedContinuation<VideoGroup, Never>?
    private var pageStarted: CheckedContinuation<Void, Never>?
    let suspendPage: Bool

    init(suspendPage: Bool = false) { self.suspendPage = suspendPage }

    func fetchChannel(channelId: String) -> (channel: Channel, videos: VideoGroup) {
        (
            Channel(id: channelId, title: channelId),
            VideoGroup(
                videos: [
                    Video(id: channelId, title: channelId, channelTitle: channelId)
                ], nextPageToken: "page-2")
        )
    }

    func fetchChannelVideos(channelId: String, continuationToken: String?) async -> VideoGroup {
        pageCalls += 1
        if suspendPage {
            return await withCheckedContinuation { continuation in
                suspendedPage = continuation
                pageStarted?.resume()
                pageStarted = nil
            }
        }
        return VideoGroup(
            videos: [
                Video(id: channelId, title: "Duplicate", channelTitle: channelId),
                Video(id: "next", title: "Next", channelTitle: channelId, badges: [Video.membersOnlyBadge]),
            ], nextPageToken: "page-2")
    }

    func waitForPage() async {
        if suspendedPage != nil { return }
        await withCheckedContinuation { pageStarted = $0 }
    }

    func finishPage() {
        suspendedPage?.resume(returning: VideoGroup(videos: [Video(id: "stale", title: "Stale", channelTitle: "Old")]))
        suspendedPage = nil
    }

    func calls() -> Int { pageCalls }
}

@Suite("Channel pagination")
@MainActor
struct ChannelPaginationTests {
    @Test("Repeated load triggers fetch one page, deduplicate videos and stop repeated tokens")
    func pagination() async {
        let api = ChannelPagesFake()
        let model = ChannelViewModel(api: api)
        model.load(channelId: "channel")
        await model.waitForCurrentRequest()
        model.loadMore()
        model.loadMore()
        await model.waitForCurrentRequest()
        #expect(await api.calls() == 1)
        #expect(model.videos.map(\.id) == ["channel", "next"])
        #expect(model.videos.last?.isMembersOnly == true)
        #expect(!model.hasMore)
    }

    @Test("Changing channels rejects an old continuation response")
    func stalePage() async {
        let api = ChannelPagesFake(suspendPage: true)
        let model = ChannelViewModel(api: api)
        model.load(channelId: "old")
        await model.waitForCurrentRequest()
        let oldRequest = model.loadMore()
        await api.waitForPage()
        model.load(channelId: "new")
        await model.waitForCurrentRequest()
        await api.finishPage()
        await oldRequest?.value
        #expect(model.channel?.id == "new")
        #expect(model.videos.map(\.id) == ["new"])
        #expect(!model.isLoading)
    }
}
