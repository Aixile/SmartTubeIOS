import Foundation
import Testing

@testable import SmartTubeIOSCore

/// Returns a small Home preview unless the request explicitly selects Videos.
/// Each continuation is a separate immutable fixture, without live networking.
private final class ChannelUploadsURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = requestBody()
        let uploads =
            body["browseId"] as? String == "UC-uploads"
            && body["params"] as? String == "EgZ2aWRlb3PyBgQKAjoA"
        let continuation = body["continuation"] as? String
        let validContinuation = body["browseId"] == nil && body["params"] == nil
        let ids: [String]
        let nextToken: String?
        switch continuation {
        case "uploads-page-2" where validContinuation:
            ids = ["video-2", "video-3"]
            nextToken = "uploads-page-3"
        case "uploads-page-3" where validContinuation:
            ids = ["video-4"]
            nextToken = nil
        default:
            ids = uploads ? ["video-1", "video-2"] : ["home-preview"]
            nextToken = uploads ? "uploads-page-2" : nil
        }
        var items: [[String: Any]] = ids.map {
            [
                "videoRenderer": [
                    "videoId": $0, "title": ["simpleText": $0],
                    "publishedTimeText": ["simpleText": "3 days ago"],
                ]
            ]
        }
        if let nextToken {
            items.append([
                "continuationItemRenderer": [
                    "continuationEndpoint": ["continuationCommand": ["token": nextToken]]
                ]
            ])
        }
        let json: [String: Any]
        if continuation != nil {
            json = ["onResponseReceivedActions": [["appendContinuationItemsAction": ["continuationItems": items]]]]
        } else {
            json = [
                "header": ["c4TabbedHeaderRenderer": ["title": "Uploads channel"]],
                "metadata": ["channelMetadataRenderer": ["externalId": "UC-uploads"]],
                "contents": [
                    "twoColumnBrowseResultsRenderer": [
                        "tabs": [
                            [
                                "tabRenderer": [
                                    "selected": true, "content": ["richGridRenderer": ["contents": items]],
                                ]
                            ]
                        ]
                    ]
                ],
            ]
        }
        guard let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            let data = try? JSONSerialization.data(withJSONObject: json)
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func requestBody() -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}

@Suite("Channel upload listings and continuation")
@MainActor
struct ChannelUploadsPaginationTests {
    @Test("Opening a channel selects Videos and follows every page beyond the Home preview")
    func fullUploadsAndPagination() async {
        let model = ChannelViewModel(api: makeAPI())
        model.load(channelId: "UC-uploads")
        await model.waitForCurrentRequest()
        #expect(model.error == nil)
        #expect(model.channel?.title == "Uploads channel")
        #expect(model.videos.map(\.id) == ["video-1", "video-2"])
        #expect(model.nextPageToken == "uploads-page-2")

        await model.loadMore()?.value
        #expect(model.error == nil)
        #expect(model.videos.map(\.id) == ["video-1", "video-2", "video-3"])
        #expect(model.nextPageToken == "uploads-page-3")

        await model.loadMore()?.value
        #expect(model.error == nil)
        #expect(model.videos.map(\.id) == ["video-1", "video-2", "video-3", "video-4"])
        #expect(!model.hasMore)
        #expect(model.loadMore() == nil)
    }

    @Test("The standalone channel videos endpoint selects the same initial uploads page")
    func standaloneVideosTab() async throws {
        let group = try await makeAPI().fetchChannelVideos(channelId: "UC-uploads")
        #expect(group.videos.map(\.id) == ["video-1", "video-2"])
        #expect(group.nextPageToken == "uploads-page-2")
    }

    private func makeAPI() -> InnerTubeAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChannelUploadsURLProtocol.self]
        return InnerTubeAPI(authToken: nil, session: URLSession(configuration: configuration))
    }
}
