import Foundation
import Testing

@testable import SmartTubeIOSCore

private enum HomePageFixtureError: Error { case failed }

@Suite @MainActor
struct HomeFeedPaginationTests {
    private func video(_ id: String) -> Video { Video(id: id, title: id, channelTitle: "Creator") }

    private func model(_ api: MockInnerTubeAPI) -> HomeViewModel {
        // Keep unrelated Shorts background paging inactive.
        api.shortsResult = VideoGroup(
            videos: (0..<50).map {
                Video(id: "short-\($0)", title: "Short", channelTitle: "Creator", isShort: true)
            })
        return HomeViewModel(api: api)
    }

    @Test func homeKeepsEveryVideoFromTheFirstBatch() async {
        let api = MockInnerTubeAPI()
        api.homeRowsResult = [VideoGroup(videos: (0..<45).map { video("rec-\($0)") })]
        api.subscriptionsResult = VideoGroup(videos: (0..<35).map { video("sub-\($0)") })
        let vm = model(api)
        defer { vm.cancel() }
        vm.load()
        await vm.waitForCurrentRequests()
        #expect(vm.homeRegularVideos.count == 80)
        #expect(vm.homeRegularVideos.contains { $0.id == "rec-44" })
        #expect(vm.homeRegularVideos.contains { $0.id == "sub-34" })
    }

    @Test func bothFeedsContinueWithoutDuplicatesOrReordering() async {
        let api = MockInnerTubeAPI()
        api.homeRowsHandler = { token in
            [
                VideoGroup(
                    videos: token == nil ? [video("rec-1"), video("rec-2")] : [video("rec-2"), video("rec-3")],
                    nextPageToken: token == nil ? "rec-next" : nil)
            ]
        }
        api.subscriptionsHandler = { token in
            VideoGroup(
                videos: token == nil ? [video("sub-1")] : [video("sub-1"), video("sub-2")],
                nextPageToken: token == nil ? "sub-next" : nil)
        }
        let vm = model(api)
        defer { vm.cancel() }
        vm.load()
        await vm.waitForCurrentRequests()
        let firstBatch = vm.mergedVideos.map(\.id)
        vm.loadMoreMerged()
        vm.loadMoreMerged()  // simultaneous appearances must not duplicate requests
        await vm.waitForCurrentRequests()
        #expect(Array(vm.mergedVideos.prefix(firstBatch.count)).map(\.id) == firstBatch)
        #expect(Set(vm.mergedVideos.map(\.id)) == ["rec-1", "rec-2", "rec-3", "sub-1", "sub-2"])
        #expect(vm.mergedVideos.count == 5)
        #expect(api.calls.filter { $0.method == "fetchHomeRows" && $0.args == ["rec-next"] }.count == 1)
        #expect(api.calls.filter { $0.method == "fetchSubscriptions" && $0.args == ["sub-next"] }.count == 1)
        #expect(vm.sections.allSatisfy { $0.nextPageToken == nil && !$0.isLoadingMore })
    }

    @Test func failedPagesKeepTheirCursorForManualRetry() async {
        let api = MockInnerTubeAPI()
        api.homeRowsResult = [VideoGroup(videos: [video("first")], nextPageToken: "next")]
        let vm = model(api)
        defer { vm.cancel() }
        vm.load()
        await vm.waitForCurrentRequests()
        api.homeRowsHandler = { _ in throw HomePageFixtureError.failed }
        vm.loadMoreMerged(automatically: true)
        await vm.waitForCurrentRequests()
        let failed = vm.sections.first { $0.section.type == .home }
        #expect(failed?.nextPageToken == "next")
        #expect(failed?.hasFailed == true)
        let count = api.calls.count
        vm.loadMoreMerged(automatically: true)
        await vm.waitForCurrentRequests()
        #expect(api.calls.count == count)
        api.homeRowsHandler = { _ in [VideoGroup(videos: [video("second")])] }
        vm.loadMoreMerged()
        await vm.waitForCurrentRequests()
        #expect(vm.homeRegularVideos.map(\.id) == ["first", "second"])
        #expect(vm.sections.first { $0.section.type == .home }?.hasFailed == false)
    }

    @Test func repeatedContinuationStopsWithoutDiscardingNewVideos() async {
        let api = MockInnerTubeAPI()
        api.homeRowsHandler = { token in
            [VideoGroup(videos: [video(token == nil ? "first" : "second")], nextPageToken: "same-token")]
        }
        let vm = model(api)
        defer { vm.cancel() }
        vm.load()
        await vm.waitForCurrentRequests()
        vm.loadMoreMerged()
        await vm.waitForCurrentRequests()
        #expect(vm.homeRegularVideos.map(\.id) == ["first", "second"])
        #expect(vm.sections.first { $0.section.type == .home }?.nextPageToken == nil)
    }

    @Test func popularFallbackContinuesThroughSearch() async {
        let api = MockInnerTubeAPI()
        api.searchResult = VideoGroup(videos: [video("first")], nextPageToken: "popular-next")
        let vm = model(api)
        defer { vm.cancel() }
        vm.load()
        await vm.waitForCurrentRequests()
        api.searchResult = VideoGroup(videos: [video("second")])
        vm.loadMoreMerged()
        await vm.waitForCurrentRequests()
        #expect(vm.homeRegularVideos.map(\.id) == ["first", "second"])
        #expect(api.calls.filter { $0.method == "fetchHomeRows" }.count == 1)
        #expect(api.calls.filter { $0.method == "search" }.count == 2)
    }

    @Test func shortsPreloadingKeepsRegularSubscriptionVideos() async {
        let api = MockInnerTubeAPI()
        api.homeRowsResult = [VideoGroup(videos: [video("rec")])]
        api.subscriptionsHandler = { token in
            VideoGroup(
                videos: [video(token == nil ? "sub-first" : "sub-next")],
                nextPageToken: token == nil ? "mixed-page" : nil)
        }
        let vm = HomeViewModel(api: api)
        defer { vm.cancel() }
        vm.load()
        await vm.waitForCurrentRequests()
        #expect(Set(vm.homeRegularVideos.map(\.id)) == ["rec", "sub-first", "sub-next"])
    }

    @Test func shelfFeedRetainsTVContainerContinuation() async {
        let api = InnerTubeAPI()
        let fixture: [String: Any] = [
            "contents": [
                "sectionListRenderer": [
                    "contents": [
                        [
                            "richShelfRenderer": [
                                "title": ["simpleText": "Recommendations"],
                                "contents": [
                                    ["videoRenderer": ["videoId": "rec-1", "title": ["simpleText": "Video"]]]
                                ],
                            ]
                        ]
                    ],
                    "continuations": [["nextContinuationData": ["continuation": "tv-next"]]],
                ]
            ]
        ]
        let rows = await api.parseVideoGroupRowsForTesting(fixture)
        #expect(rows.flatMap(\.videos).map(\.id) == ["rec-1"])
        #expect(rows.last?.nextPageToken == "tv-next")
    }
}
