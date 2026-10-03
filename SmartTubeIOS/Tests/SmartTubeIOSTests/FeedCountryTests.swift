import Foundation
import Testing

@testable import SmartTubeIOSCore

/// Echo the request body so assertions exercise the actual serialized transport,
/// without sharing mutable state or reaching the live service.
private final class CountryEchoURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else { return }
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension InnerTubeAPI {
    func probeCountry(transport: String, endpoint: String) async throws -> [String] {
        let context = transport == "web" ? webClientContext : tvClientContext
        let body = makeBody(client: context, continuationToken: "opaque-page")
        let response: [String: Any]
        switch transport {
        case "web": response = try await post(endpoint: endpoint, body: body)
        case "category": response = try await postTVCategory(endpoint: endpoint, body: body)
        default: response = try await postTV(endpoint: endpoint, body: body)
        }
        let returnedContext = response["context"] as? [String: Any]
        let client = returnedContext?["client"] as? [String: Any]
        return [
            client?["gl"] as? String ?? "", client?["clientName"] as? String ?? "",
            response["continuation"] as? String ?? "",
        ]
    }
}

@Suite("Feed country")
struct FeedCountryTests {
    private func api() -> InnerTubeAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CountryEchoURLProtocol.self]
        return InnerTubeAPI(authToken: "test-token", session: URLSession(configuration: configuration))
    }

    @Test("Old settings preserve the previous feed country; a new choice survives relaunch")
    func persistence() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(old.feedCountryCode == "US")
        var settings = old
        settings.feedCountryCode = "JP"
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(restored.feedCountryCode == "JP")
        #expect(restored.backgroundPlaybackEnabled == old.backgroundPlaybackEnabled)
    }

    @Test("Malformed saved country codes fall back safely")
    func invalidCountry() throws {
        let invalid = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"feedCountryCode":"invalid"}"#.utf8))
        #expect(invalid.feedCountryCode == FeedCountry.defaultCode)
        #expect(FeedCountry.normalized(" jp ") == "JP")
    }

    @Test(
        "All feed transports send the chosen country and preserve continuation tokens",
        arguments: ["tv", "web", "category"], ["browse", "search"])
    func feedRequests(transport: String, endpoint: String) async throws {
        let api = api()
        await api.setFeedCountry("JP")
        let result = try await api.probeCountry(transport: transport, endpoint: endpoint)
        #expect(result == ["JP", transport == "web" ? "WEB" : "TVHTML5", "opaque-page"])
    }

    @Test("Feed country changes leave player request contexts intact")
    func playerRequests() async throws {
        let api = api()
        await api.setFeedCountry("JP")
        #expect(try await api.probeCountry(transport: "tv", endpoint: "player") == ["US", "TVHTML5", "opaque-page"])
    }

    @Test("Changing countries resets the recommendation visitor; reselecting the same one keeps it")
    func visitorReset() async {
        let api = api()
        await api.updateVisitorData(from: ["responseContext": ["visitorData": "old-country"]])
        await api.setFeedCountry("JP")
        #expect(await api.currentVisitorData() == nil)
        await api.updateVisitorData(from: ["responseContext": ["visitorData": "new-country"]])
        await api.setFeedCountry("JP")
        #expect(await api.currentVisitorData() == "new-country")
    }
}
