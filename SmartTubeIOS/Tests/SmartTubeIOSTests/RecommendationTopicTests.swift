import Foundation
import Testing

@testable import SmartTubeIOSCore

@Suite("YouTube recommendation topics")
struct RecommendationTopicTests {
    @Test("TV topic selection uses its original shelf without requesting a changing Home page")
    func keepsOriginalShelf() async throws {
        let session = URLSession(configuration: .ephemeral)
        // A network request is a test failure; this selection must use the shelf snapshot.
        session.invalidateAndCancel()
        let api = InnerTubeAPI(authToken: nil, session: session)
        let original = Video(id: "original", title: "Original recommendation", channelTitle: "Test")
        let topic = RecommendationTopic(
            title: "Science", client: .tv,
            endpoint: .homeShelf(nextPage: "science-next-page"), initialVideos: [original])
        let group = try await api.fetchRecommendationVideos(topic: topic, continuation: nil)
        #expect(group.videos == [original])
        #expect(group.nextPageToken == "science-next-page")
    }

    @Test("Server chip order and opaque endpoints are preserved; All and duplicates are omitted")
    func parsesChips() {
        let response: [String: Any] = [
            "chipCloudRenderer": [
                "chips": [
                    ["chipCloudChipRenderer": ["text": ["simpleText": "All"], "isSelected": true]],
                    [
                        "chipCloudChipRenderer": [
                            "text": ["runs": [["text": "Computer "], ["text": "science"]]],
                            "navigationEndpoint": ["continuationCommand": ["token": "opaque-token"]],
                        ]
                    ],
                    [
                        "chipCloudChipRenderer": [
                            "text": ["simpleText": "Cooking"],
                            "navigationEndpoint": [
                                "browseEndpoint": ["browseId": "FEwhat_to_watch", "params": "server-params"]
                            ],
                        ]
                    ],
                    [
                        "chipCloudChipRenderer": [
                            "text": ["simpleText": "Cooking"],
                            "navigationEndpoint": ["continuationCommand": ["token": "duplicate"]],
                        ]
                    ],
                ]
            ]
        ]
        let topics = RecommendationTopicParser.parse(response, client: .tv)
        #expect(topics.map(\.title) == ["Computer science", "Cooking"])
        #expect(topics.first?.endpoint == .continuation("opaque-token"))
        #expect(topics.last?.endpoint == .browse(id: "FEwhat_to_watch", params: "server-params"))
        #expect(topics.allSatisfy { $0.client == .tv })
    }

    @Test("New chip view models expose their nested browse commands")
    func parsesChipViewModel() {
        let response: [String: Any] = [
            "chips": [
                [
                    "chipViewModel": [
                        "text": "Electronics",
                        "tapCommand": [
                            "innertubeCommand": [
                                "browseEndpoint": ["browseId": "FEwhat_to_watch", "params": "electronics"]
                            ]
                        ],
                    ]
                ],
                [
                    "chipViewModel": [
                        "text": "Unsupported", "tapCommand": ["urlEndpoint": ["url": "https://example.com"]],
                    ]
                ],
            ]
        ]
        let topics = RecommendationTopicParser.parse(response, client: .web)
        #expect(topics.map(\.title) == ["Electronics"])
        #expect(topics.first?.endpoint == .browse(id: "FEwhat_to_watch", params: "electronics"))
    }

    @Test("TV shelf topics keep their own pagination separate from discovery pagination")
    func parsesTVShelfTopics() {
        let shelf: [String: Any] = [
            "shelfRenderer": [
                "headerRenderer": [
                    "shelfHeaderRenderer": [
                        "avatarLockup": [
                            "avatarLockupRenderer": [
                                "title": ["runs": [["text": "Computer science"]]]
                            ]
                        ]
                    ]
                ],
                "content": [
                    "horizontalListRenderer": [
                        "items": [], "continuations": [["nextContinuationData": ["continuation": "topic-page"]]],
                    ]
                ],
            ]
        ]
        let response: [String: Any] = [
            "continuationContents": [
                "sectionListContinuation": [
                    "contents": [shelf], "continuations": [["nextContinuationData": ["continuation": "more-topics"]]],
                ]
            ]
        ]
        let parsed = RecommendationShelfParser.parse(response)
        #expect(parsed.shelves.map(\.title) == ["Computer science"])
        #expect(parsed.continuation == "more-topics")
        let list = parsed.shelves.first?.content["horizontalListRenderer"] as? [String: Any]
        let continuations = list?["continuations"] as? [[String: Any]]
        let next = continuations?.first?["nextContinuationData"] as? [String: Any]
        #expect(next?["continuation"] as? String == "topic-page")
    }

    @Test("TV Shorts shelves and shelves outside the actual feed are not topic chips")
    func excludesShortsAndUnrelatedShelves() {
        let shelf: [String: Any] = [
            "shelfRenderer": [
                "title": ["simpleText": "Shorts"], "content": ["horizontalListRenderer": ["items": []]],
                "tvhtml5ShelfRendererType": "TVHTML5_SHELF_RENDERER_TYPE_SHORTS",
            ]
        ]
        let response: [String: Any] = ["contents": ["sectionListRenderer": ["contents": [shelf]]], "menu": shelf]
        #expect(RecommendationShelfParser.parse(response).shelves.isEmpty)
    }
}

private actor TopicAPIFake: RecommendationTopicsAPI {
    let topic = RecommendationTopic(title: "Electronics", client: .tv, endpoint: .continuation("filter"))
    private(set) var continuations: [String?] = []
    var failNext = false

    func fetchRecommendationTopics() -> [RecommendationTopic] { [topic] }
    func setFailure() { failNext = true }

    func fetchRecommendationVideos(topic: RecommendationTopic, continuation: String?) throws -> VideoGroup {
        continuations.append(continuation)
        if failNext {
            failNext = false
            throw APIError.httpError(503)
        }
        let ids = continuation == nil ? ["one", "two"] : ["two", "three"]
        return VideoGroup(
            title: topic.title, videos: ids.map { Video(id: $0, title: $0, channelTitle: "Test") },
            nextPageToken: "next")
    }
}

private actor DelayedTopicAPI: RecommendationTopicsAPI {
    private var result: CheckedContinuation<VideoGroup, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func fetchRecommendationTopics() -> [RecommendationTopic] { [] }

    func fetchRecommendationVideos(topic: RecommendationTopic, continuation: String?) async -> VideoGroup {
        await withCheckedContinuation { result in
            self.result = result
            started?.resume()
            started = nil
        }
    }

    func waitForRequest() async {
        if result != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func finish() {
        result?.resume(returning: VideoGroup(videos: [Video(id: "late", title: "Late result", channelTitle: "Test")]))
        result = nil
    }
}

@Suite("Recommendation topic feed")
@MainActor
struct RecommendationTopicsViewModelTests {
    @Test("Returning to All rejects a topic response that arrives after cancellation")
    func cancelledSelection() async {
        let api = DelayedTopicAPI()
        let model = RecommendationTopicsViewModel(api: api)
        model.select(RecommendationTopic(title: "Science", client: .tv, endpoint: .continuation("science")))
        await api.waitForRequest()
        model.select(nil)
        await api.finish()
        await model.waitForCurrentRequest()
        #expect(model.selectedTopic == nil)
        #expect(model.videos.isEmpty)
        #expect(model.errorMessage == nil)
        #expect(!model.isLoading)
    }

    @Test("A selected topic loads server results, deduplicates pages, and stops repeated continuations")
    func pagination() async {
        let api = TopicAPIFake()
        let model = RecommendationTopicsViewModel(api: api)
        await model.loadTopics()
        model.select(model.topics.first)
        await model.waitForCurrentRequest()
        #expect(model.videos.map(\.id) == ["one", "two"])
        model.loadMore()
        await model.waitForCurrentRequest()
        #expect(model.videos.map(\.id) == ["one", "two", "three"])
        #expect(model.nextPageToken == nil)
        #expect(await api.continuations == [nil, "next"])
        model.select(nil)
        #expect(model.selectedTopic == nil)
        #expect(model.videos.isEmpty)
        #expect(!model.isLoading)
    }

    @Test("Failed topic loading can be retried without mixing another feed into it")
    func retry() async {
        let api = TopicAPIFake()
        let model = RecommendationTopicsViewModel(api: api)
        await model.loadTopics()
        await api.setFailure()
        model.select(model.topics.first)
        await model.waitForCurrentRequest()
        #expect(model.errorMessage != nil)
        #expect(model.videos.isEmpty)
        model.retry()
        await model.waitForCurrentRequest()
        #expect(model.errorMessage == nil)
        #expect(model.videos.count == 2)
    }
}
