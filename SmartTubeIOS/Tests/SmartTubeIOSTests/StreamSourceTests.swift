import Foundation
import Testing

@testable import SmartTubeIOS
@testable import SmartTubeIOSCore

private actor PlayerInfoStub: VisionOSPlayerInfoFetching {
    let hlsURL: URL?
    private(set) var requestedID: String?

    init(hlsURL: URL?) { self.hlsURL = hlsURL }

    func fetchPlayerInfoVisionOS(videoId: String) -> PlayerInfo {
        requestedID = videoId
        return PlayerInfo(
            video: Video(id: videoId, title: "Test", channelTitle: "Test"),
            formats: [], hlsURL: hlsURL, dashURL: nil, captionTracks: [],
            trackingURLs: nil, endCards: []
        )
    }
}

@Suite("Native stream source")
struct StreamSourceTests {
    @Test("Requested video and HLS playlist are preserved")
    func resolvesRequestedVideo() async throws {
        let url = URL(string: "https://example.com/playlist.m3u8")!
        let api = PlayerInfoStub(hlsURL: url)
        let info = try await VisionOSStreamSource(api: api).resolve(videoID: "test-video")
        #expect(await api.requestedID == "test-video")
        #expect(info.video.id == "test-video")
        #expect(info.hlsURL == url)
    }

    @Test("A response without HLS is rejected so another source can be tried")
    func rejectsMissingPlaylist() async {
        let source = VisionOSStreamSource(api: PlayerInfoStub(hlsURL: nil))
        await #expect(throws: APIError.self) {
            try await source.resolve(videoID: "test-video")
        }
    }

    @Test("Cancelled resolution cannot deliver a stream to a newer playback session")
    func cancelledResolution() async {
        let source = VisionOSStreamSource(api: PlayerInfoStub(hlsURL: URL(string: "https://example.com/playlist.m3u8")))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await source.resolve(videoID: "old-video")
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
