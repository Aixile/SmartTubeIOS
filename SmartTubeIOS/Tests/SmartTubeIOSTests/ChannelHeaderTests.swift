import Foundation
import Testing

@testable import SmartTubeIOSCore

private final class ChannelHeaderURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let shape = request.value(forHTTPHeaderField: "X-Channel-Fixture") ?? "modern"
        var parts: [[String: Any]] = [
            ["text": ["content": "@subscribers"]],
            ["text": ["content": "200 videos"]],
        ]
        if shape != "missing" { parts.append(["text": ["content": "1.54M subscribers"]]) }
        var header: [String: Any] = [
            "content": [
                "pageHeaderViewModel": [
                    "title": ["content": "Modern channel"],
                    "metadata": [
                        "contentMetadataViewModel": ["metadataRows": [["metadataParts": parts]]]
                    ],
                ]
            ]
        ]
        var headerKey = "pageHeaderRenderer"
        if shape == "legacy" {
            headerKey = "c4TabbedHeaderRenderer"
            header = ["title": "Legacy channel", "subscriberCountText": ["runs": [["text": "123 subscribers"]]]]
        } else if shape == "emptyLegacy" {
            header["subscriberCountText"] = ["simpleText": " "]
        }
        let json: [String: Any] = [
            "header": [headerKey: header],
            "metadata": ["channelMetadataRenderer": ["externalId": "UC-fixture", "title": "Fallback title"]],
            "contents": [String: Any](),
        ]
        guard let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            let data = try? JSONSerialization.data(withJSONObject: json)
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Channel header metadata")
struct ChannelHeaderTests {
    @Test(
        "Channel fetch retains subscriber counts across header formats", arguments: ["legacy", "modern", "emptyLegacy"])
    func subscriberCount(shape: String) async throws {
        let channel = try await fetchFixture(shape: shape)
        #expect(channel.subscriberCount == (shape == "legacy" ? "123 subscribers" : "1.54M subscribers"))
        #expect(channel.title == (shape == "legacy" ? "Legacy channel" : "Modern channel"))
        #expect(channel.id == "UC-fixture")
    }

    @Test("Handles and video counts never substitute for unavailable subscribers")
    func missingCountRemainsUnknown() async throws {
        let channel = try await fetchFixture(shape: "missing")
        #expect(channel.subscriberCount == nil)
        #expect(channel.title == "Modern channel")
    }

    private func fetchFixture(shape: String) async throws -> Channel {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChannelHeaderURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Channel-Fixture": shape]
        let api = InnerTubeAPI(authToken: nil, session: URLSession(configuration: configuration))
        return try await api.fetchChannel(channelId: "UC-fixture").channel
    }
}
