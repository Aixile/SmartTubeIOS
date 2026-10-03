import Foundation
import Observation

@MainActor
@Observable
public final class RecommendationTopicsViewModel {
    public private(set) var topics: [RecommendationTopic] = []
    public private(set) var selectedTopic: RecommendationTopic?
    public private(set) var videos: [Video] = []
    public private(set) var isLoadingTopics = false
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var nextPageToken: String?
    private let api: any RecommendationTopicsAPI
    private var generation = 0
    private var task: Task<Void, Never>?

    public init(api: any RecommendationTopicsAPI) { self.api = api }

    public func loadTopics() async {
        isLoadingTopics = true
        defer { isLoadingTopics = false }
        do {
            let result = try await api.fetchRecommendationTopics()
            guard !Task.isCancelled else { return }
            topics = result
        } catch {
            // Keep an already-loaded chip bar usable after a transient refresh failure.
        }
    }

    public func reset() {
        select(nil)
        topics = []
    }

    public func select(_ topic: RecommendationTopic?) {
        generation += 1
        task?.cancel()
        selectedTopic = topic
        videos = []
        nextPageToken = nil
        errorMessage = nil
        isLoading = topic != nil
        guard let topic else { return }
        let requestGeneration = generation
        task = Task { await fetch(topic, continuation: nil, generation: requestGeneration) }
    }

    public func loadMore() {
        guard !isLoading, let topic = selectedTopic, let token = nextPageToken else { return }
        isLoading = true
        errorMessage = nil
        let requestGeneration = generation
        task = Task { await fetch(topic, continuation: token, generation: requestGeneration) }
    }

    public func retry() {
        if videos.isEmpty { select(selectedTopic) } else { loadMore() }
    }

    public func refreshSelectedTopic() async {
        let selectedID = selectedTopic?.id
        await loadTopics()
        guard !Task.isCancelled, selectedTopic?.id == selectedID,
            let refreshed = topics.first(where: { $0.id == selectedID })
        else { return }
        select(refreshed)
        await waitForCurrentRequest()
    }

    public func waitForCurrentRequest() async { await task?.value }

    private func fetch(_ topic: RecommendationTopic, continuation: String?, generation requestGeneration: Int) async {
        defer { if generation == requestGeneration { isLoading = false } }
        do {
            let group = try await api.fetchRecommendationVideos(topic: topic, continuation: continuation)
            guard !Task.isCancelled, generation == requestGeneration else { return }
            var seen = Set(videos.map(\.id))
            videos.append(contentsOf: group.videos.filter { seen.insert($0.id).inserted })
            // A repeated token cannot make progress and must not create a fetch loop.
            nextPageToken = group.nextPageToken == continuation ? nil : group.nextPageToken
        } catch {
            guard !Task.isCancelled, generation == requestGeneration else { return }
            errorMessage = "Couldn’t load this topic. Please try again."
        }
    }
}
