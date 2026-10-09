import Foundation
import Testing

@testable import SmartTubeIOSCore

private actor TitleFetchGate {
    private var calls = 0
    private var active = 0
    private var peak = 0
    private var open = false
    private var pending: [CheckedContinuation<Void, Never>] = []
    private var ready: [CheckedContinuation<Void, Never>] = []

    func fetch(_ id: String) async -> String? {
        calls += 1
        active += 1
        peak = max(peak, active)
        if active == OriginalVideoTitleCache.maxConcurrentRequests {
            ready.forEach { $0.resume() }
            ready.removeAll()
        }
        if !open {
            await withCheckedContinuation { pending.append($0) }
        }
        active -= 1
        return "原始标题 \(id)"
    }

    func waitUntilFull() async {
        if active >= OriginalVideoTitleCache.maxConcurrentRequests { return }
        await withCheckedContinuation { ready.append($0) }
    }

    func release() {
        open = true
        pending.forEach { $0.resume() }
        pending.removeAll()
    }

    func counts() -> (calls: Int, peak: Int) { (calls, peak) }
}

private final class TitleTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_000)
    func now() -> Date { lock.withLock { date } }
    func advance(_ interval: TimeInterval) { lock.withLock { date.addTimeInterval(interval) } }
}

private actor TitleFetchCounter {
    private var count = 0
    func fetch(_ id: String) -> String? {
        count += 1
        return id == "no_title___" ? nil : "  原始标题  "
    }
    func calls() -> Int { count }
}

private final class OriginalTitleURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let items = components?.queryItems ?? []
        let videoURL = items.first { $0.name == "url" }?.value ?? ""
        let valid =
            components?.path == "/oembed"
            && items.first { $0.name == "format" }?.value == "json"
            && request.value(forHTTPHeaderField: "Authorization") == nil
            && request.value(forHTTPHeaderField: "Accept-Language") == nil
        let denied = videoURL.contains("unavailable")
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url, statusCode: valid && !denied ? 200 : 403, httpVersion: nil, headerFields: nil)
        else { return }
        let payload = videoURL.contains("empty_title") ? #"{"title":""}"# : #"{"title":"中文原始标题"}"#
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(payload.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite struct OriginalVideoTitleTests {
    @Test func originalTitlesDefaultOnAndMigrateOldSettings() throws {
        #expect(AppSettings().preferOriginalTitles)
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(old.preferOriginalTitles)
        var settings = AppSettings()
        settings.preferOriginalTitles = false
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(!restored.preferOriginalTitles)
    }

    @Test func titleSelectionHonorsOriginalFallbackAndExplicitDeArrow() {
        var video = Video(id: "jNQXAC9IVRw", title: "Translated title", channelTitle: "Creator")
        #expect(video.displayTitle(originalTitle: "原始标题", preferOriginalTitles: true, deArrowEnabled: false) == "原始标题")
        #expect(
            video.displayTitle(originalTitle: "原始标题", preferOriginalTitles: false, deArrowEnabled: false)
                == "Translated title")
        #expect(
            video.displayTitle(originalTitle: nil, preferOriginalTitles: true, deArrowEnabled: false)
                == "Translated title")
        video.deArrowTitle = "Community title"
        #expect(
            video.displayTitle(originalTitle: "原始标题", preferOriginalTitles: true, deArrowEnabled: true)
                == "Community title")
    }

    @Test func cachedTitlesExpireAndAreTrimmed() async {
        let counter = TitleFetchCounter()
        let clock = TitleTestClock()
        let cache = OriginalVideoTitleCache(fetch: { await counter.fetch($0) }, now: { clock.now() })
        #expect(await cache.title(for: "jNQXAC9IVRw") == "原始标题")
        #expect(await cache.title(for: "jNQXAC9IVRw") == "原始标题")
        #expect(await counter.calls() == 1)
        clock.advance(24 * 3600 + 1)
        #expect(await cache.title(for: "jNQXAC9IVRw") == "原始标题")
        #expect(await counter.calls() == 2)
    }

    @Test func missingTitlesRetryAfterShortCooldownAndIgnorePlaylistIDs() async {
        let counter = TitleFetchCounter()
        let clock = TitleTestClock()
        let cache = OriginalVideoTitleCache(fetch: { await counter.fetch($0) }, now: { clock.now() })
        #expect(await cache.title(for: "WL") == nil)
        #expect(await counter.calls() == 0)
        #expect(await cache.title(for: "no_title___") == nil)
        #expect(await cache.title(for: "no_title___") == nil)
        #expect(await counter.calls() == 1)
        clock.advance(61)
        #expect(await cache.title(for: "no_title___") == nil)
        #expect(await counter.calls() == 2)
    }

    @Test func repeatedConcurrentCardsShareOneRequest() async {
        let counter = TitleFetchCounter()
        let cache = OriginalVideoTitleCache(fetch: { await counter.fetch($0) })
        await withTaskGroup(of: String?.self) { group in
            for _ in 0..<20 { group.addTask { await cache.title(for: "jNQXAC9IVRw") } }
            for await title in group { #expect(title == "原始标题") }
        }
        #expect(await counter.calls() == 1)
    }

    @Test func fastScrollingLimitsRequestsAndSkipsCancelledCards() async {
        let gate = TitleFetchGate()
        let cache = OriginalVideoTitleCache(fetch: { await gate.fetch($0) })
        await withTaskGroup(of: String?.self) { group in
            for index in 0..<3 { group.addTask { await cache.title(for: "videoid000\(index)") } }
            await gate.waitUntilFull()
            let cancelled = Task { await cache.title(for: "cancelled00") }
            cancelled.cancel()
            for index in 3..<10 { group.addTask { await cache.title(for: "videoid000\(index)") } }
            await gate.release()
            #expect(await cancelled.value == nil)
            for await title in group { #expect(title != nil) }
        }
        let counts = await gate.counts()
        #expect(counts.calls == 10)
        #expect(counts.peak <= OriginalVideoTitleCache.maxConcurrentRequests)
    }

    @Test func sourceReadsCreatorTitleWithoutLanguageOrAuthentication() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OriginalTitleURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        #expect(try await fetchYouTubeOriginalTitle(videoID: "jNQXAC9IVRw", session: session) == "中文原始标题")
        #expect(try await fetchYouTubeOriginalTitle(videoID: "unavailable", session: session) == nil)
    }

    @Test func emptyMetadataDoesNotReplaceFeedTitle() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OriginalTitleURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let cache = OriginalVideoTitleCache(fetch: {
            try await fetchYouTubeOriginalTitle(videoID: $0, session: session)
        })
        #expect(await cache.title(for: "empty_title") == nil)
    }
}
