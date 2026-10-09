import Foundation

/// Creator titles from YouTube's lightweight oEmbed metadata, independent of feed language.
/// Only visible titles request metadata; duplicate requests share work and scrolling is bounded.
public actor OriginalVideoTitleCache {
    public static let shared = OriginalVideoTitleCache()
    static let maxConcurrentRequests = 3
    private static let capacity = 500
    private static let successTTL: TimeInterval = 24 * 3600
    private static let failureTTL: TimeInterval = 60

    private struct Entry {
        let title: String?
        let fetchedAt: Date
    }

    private let fetch: @Sendable (String) async throws -> String?
    private let now: @Sendable () -> Date
    private var entries: [String: Entry] = [:]
    private var recency: [String] = []
    private var requests: [String: Task<String?, Never>] = [:]

    public init() {
        fetch = { try await fetchYouTubeOriginalTitle(videoID: $0) }
        now = { Date() }
    }

    init(
        fetch: @escaping @Sendable (String) async throws -> String?,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fetch = fetch
        self.now = now
    }

    public func title(for videoID: String) async -> String? {
        guard Self.isVideoID(videoID) else { return nil }
        while !Task.isCancelled {
            if let entry = entries[videoID],
                now().timeIntervalSince(entry.fetchedAt) < (entry.title == nil ? Self.failureTTL : Self.successTTL)
            {
                touch(videoID)
                return entry.title
            }
            if let request = requests[videoID] { return await request.value }
            // Wait without enqueuing a new network task. Offscreen callers exit on cancellation.
            if requests.count >= Self.maxConcurrentRequests, let request = requests.values.first {
                _ = await request.value
                continue
            }
            let fetch = fetch
            let request = Task {
                let raw = try? await fetch(videoID)
                let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = trimmed?.isEmpty == false ? trimmed : nil
                finish(videoID: videoID, title: title)
                return title
            }
            requests[videoID] = request
            return await request.value
        }
        return nil
    }

    private func finish(videoID: String, title: String?) {
        requests.removeValue(forKey: videoID)
        entries[videoID] = Entry(title: title, fetchedAt: now())
        touch(videoID)
        if recency.count > Self.capacity {
            entries.removeValue(forKey: recency.removeFirst())
        }
    }

    private func touch(_ videoID: String) {
        recency.removeAll { $0 == videoID }
        recency.append(videoID)
    }

    private static func isVideoID(_ value: String) -> Bool {
        value.utf8.count == 11
            && value.utf8.allSatisfy {
                (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
            }
    }
}

/// No login, API key, stream extraction or locale hint is needed for oEmbed.
func fetchYouTubeOriginalTitle(videoID: String, session: URLSession = .shared) async throws -> String? {
    var components = URLComponents(string: "https://www.youtube.com/oembed")
    components?.queryItems = [
        URLQueryItem(name: "url", value: "https://www.youtube.com/watch?v=\(videoID)"),
        URLQueryItem(name: "format", value: "json"),
    ]
    guard let url = components?.url else { return nil }
    var request = URLRequest(url: url, timeoutInterval: 8)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { return nil }
    struct Metadata: Decodable { let title: String }
    return try JSONDecoder().decode(Metadata.self, from: data).title
}
