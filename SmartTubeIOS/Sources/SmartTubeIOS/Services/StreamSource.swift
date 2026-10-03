import Foundation
import SmartTubeIOSCore

/// Resolves metadata and a playable stream without owning the player lifecycle.
protocol StreamSource: Sendable {
    var name: String { get }
    func resolve(videoID: String) async throws -> PlayerInfo
}

protocol VisionOSPlayerInfoFetching: Sendable {
    func fetchPlayerInfoVisionOS(videoId: String) async throws -> PlayerInfo
}

extension InnerTubeAPI: VisionOSPlayerInfoFetching {}

struct VisionOSStreamSource: StreamSource {
    let api: any VisionOSPlayerInfoFetching
    let name = "VisionOS"

    func resolve(videoID: String) async throws -> PlayerInfo {
        let info = try await api.fetchPlayerInfoVisionOS(videoId: videoID)
        try Task.checkCancellation()
        guard info.hlsURL != nil else {
            throw APIError.unavailable("This stream source did not return an HLS playlist")
        }
        return info
    }
}

enum PlaybackTuning {
    static let preferredSourceTimeout: Duration = .seconds(12)
    static let diagnosticProgressInterval: Double = 5
}
