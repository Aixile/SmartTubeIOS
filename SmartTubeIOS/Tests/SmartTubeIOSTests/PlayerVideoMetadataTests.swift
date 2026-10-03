import Foundation
import Testing

@testable import SmartTubeIOSCore

private final class PlayerMetadataURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let json =
            #"{"playabilityStatus":{"status":"OK"},"videoDetails":{"title":"Chinese video","author":"Uploader","channelId":"UC-uploader","viewCount":"1234"},"microformat":{"playerMicroformatRenderer":{"publishDate":"2020-08-23","uploadDate":"2020-08-21"}},"streamingData":{"hlsManifestUrl":"https://example.invalid/master.m3u8"}}"#
        guard let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Player video metadata")
struct PlayerVideoMetadataTests {
    @Test("Player responses retain uploader ID and exact publication date")
    func playerResponseKeepsMetadata() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PlayerMetadataURLProtocol.self]
        let api = InnerTubeAPI(authToken: nil, session: URLSession(configuration: configuration))
        let info = try await api.fetchPlayerInfo(videoId: "fixture")
        #expect(info.video.channelId == "UC-uploader")
        #expect(info.video.publishedDateText == "2020-08-23")
        #expect(info.video.publishedAt == Video.parsePublicationDate("2020-08-23"))
        #expect(info.video.viewCount == 1234)
    }

    @Test("Sparse streaming metadata preserves the feed channel and relative date")
    func sparseResponseUsesFeedMetadata() {
        let source = Video(
            id: "same", title: "Feed title", channelTitle: "Feed channel", channelId: "UC-feed",
            viewCount: 100, publishedTimeText: "3 months ago")
        let streaming = Video(id: "same", title: "Player title", channelTitle: "")
        let result = source.mergingPlaybackMetadata(streaming)
        #expect(result.title == "Player title")
        #expect(result.channelTitle == "Feed channel")
        #expect(result.channelId == "UC-feed")
        #expect(result.viewCount == 100)
        #expect(result.publicationLabel == "3 months ago")
    }

    @Test("A late response from a previous video cannot replace the current uploader")
    func mismatchedResponseIsIgnored() {
        let current = Video(id: "current", title: "Current", channelTitle: "New channel", channelId: "UC-new")
        let stale = Video(
            id: "previous", title: "Previous", channelTitle: "Old channel", channelId: "UC-old",
            publishedDateText: "2020-08-23")
        #expect(current.mergingPlaybackMetadata(stale) == current)
    }

    @Test("An exact player date replaces the relative feed approximation")
    func exactDateHasPriority() throws {
        let feed = Video(id: "same", title: "", channelTitle: "", publishedTimeText: "6 years ago")
        let streaming = Video(
            id: "same", title: "", channelTitle: "", publishedAt: Video.parsePublicationDate("2020-08-23"),
            publishedDateText: "2020-08-23")
        let result = feed.mergingPlaybackMetadata(streaming)
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.timeZone = .gmt
        let expected = try #require(Video.parsePublicationDate("2020-08-23")).formatted(style)
        #expect(result.publicationLabel == expected)
    }

    @Test("Publication dates reject invalid calendar days and accept timestamp days")
    func dateParsing() {
        #expect(Video.parsePublicationDate("2020-02-30") == nil)
        #expect(Video.parsePublicationDate("garbage") == nil)
        #expect(Video.parsePublicationDate("2020-8-23") == nil)
        #expect(Video.parsePublicationDate("2020-08-23T20:45:00-07:00") == Video.parsePublicationDate("2020-08-23"))
        let unknown = Video(id: "unknown", title: "", channelTitle: "")
        #expect(unknown.publicationLabel == nil)
    }

    @Test("Saved videos from older builds still decode without an exact date")
    func oldVideoJSONDecodes() throws {
        let original = Video(
            id: "saved", title: "Saved video", channelTitle: "Channel", publishedTimeText: "2 years ago")
        let encoded = try JSONEncoder().encode(original)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "publishedDateText")
        let restored = try JSONDecoder().decode(Video.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(restored.publishedDateText == nil)
        #expect(restored.publicationLabel == "2 years ago")
    }
}
