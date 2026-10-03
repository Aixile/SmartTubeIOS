import Foundation
import Testing

@testable import SmartTubeIOSCore

@Suite("Home video filtering and grouping")
struct HomeVideoFilterTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)
    private var videos: [Video] {
        [
            Video(
                id: "watched", title: "Camera review", channelTitle: "Café Studio", channelId: "a", duration: 600,
                viewCount: 40, publishedAt: now.addingTimeInterval(-60), watchProgress: 0.95),
            Video(
                id: "long", title: "Audio setup", channelTitle: "Café Studio", channelId: "a", duration: 1201,
                viewCount: 10, publishedAt: now.addingTimeInterval(-604800)),
            Video(id: "short", title: "Camera tip", channelTitle: "Other", channelId: "b", duration: 30, isShort: true),
            Video(id: "live", title: "Live chat", channelTitle: "Other", channelId: "b", isLive: true),
            Video(id: "upcoming", title: "Premiere", channelTitle: "Other", channelId: "b", isUpcoming: true),
            Video(id: "unknown", title: "Camera lesson", channelTitle: "Café Studio", channelId: "a"),
        ]
    }

    private func ids(
        _ filter: HomeVideoFilter, settings: AppSettings = AppSettings(), history: Set<String> = []
    ) -> [String] {
        filter.apply(to: videos, settings: settings, watchedVideoIDs: history, now: now).map(\.id)
    }

    @Test("Defaults preserve order; type, duration, date, watch status and search compose")
    func combinations() {
        var filter = HomeVideoFilter()
        var settings = AppSettings()
        settings.hideShorts = false
        settings.hideVideoPremieres = false
        settings.hideWatchedVideos = false
        #expect(ids(filter, settings: settings) == videos.map(\.id))
        filter.kind = .videos
        filter.duration = .medium
        filter.watchStatus = .watched
        filter.uploadDate = .day
        filter.query = "  CAFE camera "
        #expect(ids(filter, settings: settings) == ["watched"])
        #expect(filter.activeCount == 5)
        filter.watchStatus = .unwatched
        #expect(ids(filter, settings: settings).isEmpty)
        filter = HomeVideoFilter()
        filter.kind = .videos
        filter.watchStatus = .unwatched
        #expect(ids(filter, settings: settings, history: ["long"]) == ["unknown"])
    }

    @Test("Explicit Shorts and Watched override the corresponding global hiding settings")
    func explicitChoices() {
        var settings = AppSettings()
        settings.hideShorts = true
        settings.hideWatchedVideos = true
        var filter = HomeVideoFilter()
        #expect(!ids(filter, settings: settings).contains("short"))
        #expect(!ids(filter, settings: settings).contains("watched"))
        filter.kind = .shorts
        #expect(ids(filter, settings: settings) == ["short"])
        filter.kind = .videos
        filter.watchStatus = .watched
        #expect(ids(filter, settings: settings) == ["watched"])
        filter.kind = .live
        filter.watchStatus = .all
        #expect(ids(filter, settings: settings) == ["live", "upcoming"])
    }

    @Test("Date ranges include exact boundaries and exclude unknown/future dates")
    func uploadDates() {
        #expect(HomeVideoFilter.UploadDate.week.includes(now.addingTimeInterval(-604800), now: now))
        #expect(!HomeVideoFilter.UploadDate.week.includes(now.addingTimeInterval(-604801), now: now))
        #expect(!HomeVideoFilter.UploadDate.day.includes(now.addingTimeInterval(1), now: now))
        #expect(!HomeVideoFilter.UploadDate.day.includes(nil, now: now))
        var filter = HomeVideoFilter()
        filter.uploadDate = .week
        #expect(ids(filter) == ["watched", "long"])
    }

    @Test("Sorting is stable, keeps unknown metadata last, and supports both duration directions")
    func sorting() {
        var filter = HomeVideoFilter()
        var settings = AppSettings()
        settings.hideShorts = false
        settings.hideVideoPremieres = false
        settings.hideWatchedVideos = false
        filter.sort = .shortest
        #expect(ids(filter, settings: settings) == ["short", "watched", "long", "live", "upcoming", "unknown"])
        filter.sort = .longest
        #expect(ids(filter, settings: settings) == ["long", "watched", "short", "live", "upcoming", "unknown"])
        filter.sort = .views
        #expect(ids(filter, settings: settings) == ["watched", "long", "short", "live", "upcoming", "unknown"])
        filter.sort = .newest
        #expect(ids(filter, settings: settings) == ["watched", "long", "short", "live", "upcoming", "unknown"])
        let equal = [
            Video(id: "one", title: "One", channelTitle: "", viewCount: 10),
            Video(id: "two", title: "Two", channelTitle: "", viewCount: 10),
        ]
        filter.sort = .views
        #expect(filter.apply(to: equal + equal, settings: settings).map(\.id) == ["one", "two"])
    }

    @Test("Grouping preserves first appearance and within-group sort order")
    func grouping() {
        var filter = HomeVideoFilter()
        filter.grouping = .channel
        let groups = filter.groups(in: [videos[2], videos[1], videos[0], videos[3]])
        #expect(groups.map(\.id) == ["channel:b", "channel:a"])
        #expect(groups[1].videos.map(\.id) == ["long", "watched"])
        #expect(filter.isActive)
        #expect(filter.activeCount == 0)
        filter.grouping = .type
        #expect(filter.groups(in: videos).map(\.title) == ["Videos", "Shorts", "Live / upcoming"])
        filter.grouping = .channel
        let differentChannels = [
            Video(id: "one", title: "One", channelTitle: "Same", channelId: "one"),
            Video(id: "two", title: "Two", channelTitle: "Same", channelId: "two"),
        ]
        #expect(filter.groups(in: differentChannels).count == 2)
    }

    @Test("Filters and grouping persist without resetting other settings; old settings receive defaults")
    func persistence() throws {
        var settings = AppSettings()
        settings.playbackSpeed = 1.5
        settings.homeVideoFilter.kind = .videos
        settings.homeVideoFilter.duration = .long
        settings.homeVideoFilter.grouping = .channel
        settings.homeVideoFilter.query = "中文"
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.homeVideoFilter == settings.homeVideoFilter)
        #expect(decoded.playbackSpeed == 1.5)
        let legacy = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"playbackSpeed":1.5}"#.utf8))
        #expect(legacy.homeVideoFilter == HomeVideoFilter())
        #expect(legacy.playbackSpeed == 1.5)
        let malformed = try JSONDecoder().decode(
            AppSettings.self, from: Data(#"{"playbackSpeed":1.5,"homeVideoFilter":{"kind":"invalid"}}"#.utf8))
        #expect(malformed.homeVideoFilter == HomeVideoFilter())
        #expect(malformed.playbackSpeed == 1.5)
    }

    @Test("A topic page with no matches retains its continuation and the next page can match")
    @MainActor
    func filteredPagination() async {
        let topic = RecommendationTopic(title: "Music", client: .web, endpoint: .browse(id: "music", params: nil))
        let model = RecommendationTopicsViewModel(api: FilteredTopicFake())
        var settings = AppSettings()
        settings.homeVideoFilter.duration = .long
        model.select(topic)
        await model.waitForCurrentRequest()
        #expect(settings.homeVideoFilter.apply(to: model.videos, settings: settings).isEmpty)
        #expect(model.nextPageToken == "next")
        model.loadMore()
        await model.waitForCurrentRequest()
        #expect(settings.homeVideoFilter.apply(to: model.videos, settings: settings).map(\.id) == ["long"])
        #expect(model.nextPageToken == nil)
    }
}

private actor FilteredTopicFake: RecommendationTopicsAPI {
    func fetchRecommendationTopics() -> [RecommendationTopic] { [] }

    func fetchRecommendationVideos(topic: RecommendationTopic, continuation: String?) -> VideoGroup {
        if continuation == nil {
            return VideoGroup(
                videos: [Video(id: "short", title: "Short", channelTitle: "Music", duration: 30)], nextPageToken: "next"
            )
        }
        return VideoGroup(videos: [Video(id: "long", title: "Long", channelTitle: "Music", duration: 1500)])
    }
}
