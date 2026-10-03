import Foundation

public protocol ChannelBrowsingAPI: Sendable {
    func fetchChannel(channelId: String) async throws -> (channel: Channel, videos: VideoGroup)
    func fetchChannelVideos(channelId: String, continuationToken: String?) async throws -> VideoGroup
}
