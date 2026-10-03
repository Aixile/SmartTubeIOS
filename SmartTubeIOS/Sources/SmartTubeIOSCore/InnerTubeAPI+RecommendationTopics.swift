import Foundation
import os

private let topicsLog = Logger(subsystem: appSubsystem, category: "RecommendationTopics")

extension InnerTubeAPI: RecommendationTopicsAPI {
    public func fetchRecommendationTopics() async throws -> [RecommendationTopic] {
        if authToken != nil {
            do {
                let topics = try await fetchTVRecommendationTopics()
                if !topics.isEmpty { return topics }
            } catch {
                try Task.checkCancellation()
                topicsLog.notice("TV topics unavailable; trying the web feed")
            }
        }
        // WEB exposes the full chip bar when the TV client omits it. It uses the
        // existing browser cookie session, never the TV OAuth Bearer token.
        let data = try await topicBrowse(client: .web, endpoint: .browse(id: "FEwhat_to_watch", params: nil))
        let topics = RecommendationTopicParser.parse(data, client: .web)
        topicsLog.notice("WEB returned \(topics.count) recommendation topics")
        return topics
    }

    private func fetchTVRecommendationTopics() async throws -> [RecommendationTopic] {
        var topics: [RecommendationTopic] = []
        var page: String?
        var seenPages = Set<String>()
        var seenTitles = Set<String>()
        // TV Home sends only a few shelves per page. Follow vertical continuations
        // to discover the personalised topics below Recommended and Shorts.
        let discoveryPageLimit = 6
        for _ in 0..<discoveryPageLimit {
            try Task.checkCancellation()
            let endpoint =
                page.map(RecommendationTopic.Endpoint.continuation)
                ?? .browse(id: "FEwhat_to_watch", params: nil)
            let data: [String: Any]
            do {
                data = try await topicBrowse(client: .tv, endpoint: endpoint)
            } catch {
                if topics.isEmpty { throw error }
                break
            }
            let chips = RecommendationTopicParser.parse(data, client: .tv)
            if !chips.isEmpty { return chips }
            let parsed = RecommendationShelfParser.parse(data)
            for shelf in parsed.shelves {
                guard shelf.title != BrowseSection.SectionType.recommended.defaultTitle,
                    seenTitles.insert(shelf.title).inserted,
                    let group = try? parseVideoGroup(from: shelf.content, title: shelf.title), !group.videos.isEmpty
                else { continue }
                topics.append(
                    RecommendationTopic(
                        title: shelf.title, client: .tv,
                        endpoint: .homeShelf(nextPage: group.nextPageToken), initialVideos: group.videos))
            }
            guard let next = parsed.continuation, seenPages.insert(next).inserted else { break }
            page = next
        }
        topicsLog.notice("TV returned \(topics.count) recommendation topics")
        return topics
    }

    public func fetchRecommendationVideos(topic: RecommendationTopic, continuation: String?) async throws -> VideoGroup
    {
        let endpoint = continuation.map { RecommendationTopic.Endpoint.continuation($0) } ?? topic.endpoint
        let group: VideoGroup
        if case .homeShelf(let nextPage) = endpoint {
            // Home pages are dynamic. Keep the exact shelf that produced the chip;
            // requesting its vertical page again can return entirely different topics.
            group = VideoGroup(title: topic.title, videos: topic.initialVideos, nextPageToken: nextPage)
        } else {
            let data = try await topicBrowse(client: topic.client, endpoint: endpoint)
            group = try parseVideoGroup(from: data, title: topic.title)
        }
        topicsLog.notice(
            "Topic \(topic.title, privacy: .public): \(group.videos.count) videos, more=\(group.nextPageToken != nil)")
        return group
    }

    private func topicBrowse(
        client: RecommendationTopic.Client, endpoint: RecommendationTopic.Endpoint
    ) async throws -> [String: Any] {
        var body = makeBody(client: client == .tv ? tvClientContext : webClientContext, includeVisitorData: true)
        switch endpoint {
        case .browse(let id, let params):
            body["browseId"] = id
            if let params { body["params"] = params }
        case .continuation(let token):
            body["continuation"] = token
        case .homeShelf:
            throw APIError.decodingError("Home shelf already loaded")
        }
        let data: [String: Any]
        if client == .tv {
            data = try await postTV(endpoint: "browse", body: body)
        } else {
            var request = URLRequest(url: baseURL.appendingPathComponent("browse"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
            request.setValue(InnerTubeClients.WebSafari.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue(InnerTubeClients.Web.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
            request.setValue(InnerTubeClients.Web.version, forHTTPHeaderField: "X-YouTube-Client-Version")
            if let sid = sapisid {
                request.setValue(Self.sapisidhash(sapisid: sid), forHTTPHeaderField: "Authorization")
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: feedRequestBody(body, endpoint: "browse"))
            let (bytes, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            guard let json = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
                throw APIError.decodingError("Invalid recommendation response")
            }
            data = json
        }
        updateVisitorData(from: data)
        return data
    }
}
