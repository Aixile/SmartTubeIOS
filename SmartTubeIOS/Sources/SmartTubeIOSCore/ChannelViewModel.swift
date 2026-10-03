import Foundation
import Observation

@MainActor
@Observable
public final class ChannelViewModel {
    public private(set) var channel: Channel?
    public private(set) var videos: [Video] = []
    public private(set) var isLoading = false
    public private(set) var nextPageToken: String?
    public var error: Error?
    public var hasMore: Bool { nextPageToken != nil }

    private let api: any ChannelBrowsingAPI
    private var request: Task<Void, Never>?
    private var generation = 0
    private var loadedTokens: Set<String> = []
    private var hideObserverTasks: [Task<Void, Never>] = []

    public init(api: any ChannelBrowsingAPI = InnerTubeAPI()) {
        self.api = api
        observeFeedHideNotifications()
    }

    isolated deinit {
        request?.cancel()
        for task in hideObserverTasks { task.cancel() }
    }

    public func load(channelId: String) {
        request?.cancel()
        generation += 1
        let currentGeneration = generation
        isLoading = true
        error = nil
        nextPageToken = nil
        loadedTokens.removeAll()
        if channel?.id != channelId {
            channel = nil
            videos = []
        }
        request = Task { [weak self, api] in
            do {
                let (channel, group) = try await api.fetchChannel(channelId: channelId)
                guard let self, !Task.isCancelled, generation == currentGeneration else { return }
                self.channel = channel
                var seen: Set<String> = []
                videos = group.videos.filter { seen.insert($0.id).inserted }
                nextPageToken = group.nextPageToken
                isLoading = false
            } catch {
                guard let self, !Task.isCancelled, generation == currentGeneration else { return }
                self.error = error
                isLoading = false
            }
        }
    }

    @discardableResult
    public func loadMore() -> Task<Void, Never>? {
        guard let id = channel?.id, let token = nextPageToken, !isLoading else { return nil }
        // Mark loading before spawning the task; multiple visible rows can request a page together.
        isLoading = true
        error = nil
        let currentGeneration = generation
        request = Task { [weak self, api] in
            do {
                let group = try await api.fetchChannelVideos(channelId: id, continuationToken: token)
                guard let self, !Task.isCancelled, generation == currentGeneration else { return }
                var seen = Set(videos.map(\.id))
                videos.append(contentsOf: group.videos.filter { seen.insert($0.id).inserted })
                loadedTokens.insert(token)
                nextPageToken = group.nextPageToken.flatMap { loadedTokens.contains($0) ? nil : $0 }
                isLoading = false
            } catch {
                guard let self, !Task.isCancelled, generation == currentGeneration else { return }
                self.error = error
                isLoading = false
            }
        }
        return request
    }

    public func waitForCurrentRequest() async { await request?.value }

    private func observeFeedHideNotifications() {
        hideObserverTasks.append(
            Task { [weak self] in
                for await note in NotificationCenter.default.notifications(named: .hideVideoFromFeed) {
                    guard let self, let videoId = note.userInfo?["videoId"] as? String else { continue }
                    self.videos.removeAll { $0.id == videoId }
                }
            })
        hideObserverTasks.append(
            Task { [weak self] in
                for await note in NotificationCenter.default.notifications(named: .hideChannelFromFeed) {
                    guard let self, let channelId = note.userInfo?["channelId"] as? String else { continue }
                    self.videos.removeAll { $0.channelId == channelId }
                }
            })
    }
}
