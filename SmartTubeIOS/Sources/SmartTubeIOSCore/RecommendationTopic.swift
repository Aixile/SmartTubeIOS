import Foundation

public struct RecommendationTopic: Identifiable, Equatable, Sendable {
    public enum Client: String, Sendable { case tv, web }
    public enum Endpoint: Equatable, Sendable {
        case browse(id: String, params: String?)
        case continuation(String)
        /// The TV client groups automatic topics into shelves on Home pages.
        case homeShelf(nextPage: String?)
    }

    public let title: String
    public let client: Client
    public let endpoint: Endpoint
    public let initialVideos: [Video]
    public var id: String { "\(client.rawValue):\(title)" }

    public init(title: String, client: Client, endpoint: Endpoint, initialVideos: [Video] = []) {
        self.title = title
        self.client = client
        self.endpoint = endpoint
        self.initialVideos = initialVideos
    }
}

enum RecommendationShelfParser {
    struct Shelf {
        let title: String
        let content: [String: Any]
    }

    static func parse(_ response: [String: Any]) -> (shelves: [Shelf], continuation: String?) {
        var shelves: [Shelf] = []
        var continuation: String?
        func walk(_ value: Any) {
            if let dictionary = value as? [String: Any] {
                if let shelf = dictionary["shelfRenderer"] as? [String: Any] {
                    let header = shelf["headerRenderer"] as? [String: Any]
                    let renderer = header?["shelfHeaderRenderer"] as? [String: Any]
                    let avatar = renderer?["avatarLockup"] as? [String: Any]
                    let lockup = avatar?["avatarLockupRenderer"] as? [String: Any]
                    let text = (lockup?["title"] ?? shelf["title"]) as? [String: Any]
                    let title =
                        text?["simpleText"] as? String
                        ?? (text?["runs"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined()
                    if let title, !title.isEmpty, let content = shelf["content"] as? [String: Any],
                        shelf["tvhtml5ShelfRendererType"] as? String != "TVHTML5_SHELF_RENDERER_TYPE_SHORTS"
                    {
                        shelves.append(Shelf(title: title, content: content))
                    }
                    // Shelf continuations paginate that topic, not the vertical Home feed.
                    return
                }
                for key in ["sectionListRenderer", "sectionListContinuation"] {
                    if let section = dictionary[key] as? [String: Any] {
                        let continuations = section["continuations"] as? [[String: Any]]
                        let next = continuations?.first?["nextContinuationData"] as? [String: Any]
                        continuation = next?["continuation"] as? String
                        if let contents = section["contents"] { walk(contents) }
                        return
                    }
                }
                for key in dictionary.keys.sorted() {
                    if let value = dictionary[key] { walk(value) }
                }
            } else if let array = value as? [Any] {
                for item in array { walk(item) }
            }
        }
        // Never pick shelves embedded in menus, adverts, or tracking payloads.
        if let contents = response["contents"] ?? response["continuationContents"] { walk(contents) }
        return (shelves, continuation)
    }
}

/// Keep the server's filter order and opaque navigation tokens. A title is a
/// display label, never a search query or a category inferred from video titles.
enum RecommendationTopicParser {
    static func parse(_ response: [String: Any], client: RecommendationTopic.Client) -> [RecommendationTopic] {
        var topics: [RecommendationTopic] = []
        var seen = Set<String>()

        func text(_ value: Any?) -> String? {
            if let string = value as? String { return string }
            guard let value = value as? [String: Any] else { return nil }
            if let simple = value["simpleText"] as? String ?? value["content"] as? String { return simple }
            return (value["runs"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined()
        }

        func endpoint(_ value: Any, depth: Int = 0) -> RecommendationTopic.Endpoint? {
            guard depth < 16 else { return nil }
            if let dict = value as? [String: Any] {
                if let browse = dict["browseEndpoint"] as? [String: Any], let id = browse["browseId"] as? String {
                    return .browse(id: id, params: browse["params"] as? String)
                }
                if let command = dict["continuationCommand"] as? [String: Any], let token = command["token"] as? String
                {
                    return .continuation(token)
                }
                for key in dict.keys.sorted() {
                    if let result = endpoint(dict[key] as Any, depth: depth + 1) { return result }
                }
            } else if let array = value as? [Any] {
                for item in array {
                    if let result = endpoint(item, depth: depth + 1) { return result }
                }
            }
            return nil
        }

        func walk(_ value: Any, depth: Int = 0) {
            guard depth < 24 else { return }
            if let dict = value as? [String: Any] {
                for key in ["chipCloudChipRenderer", "tvChipCloudChipRenderer", "chipViewModel"] {
                    guard let chip = dict[key] as? [String: Any] else { continue }
                    // The initial selected chip is "All", supplied separately by the UI.
                    guard chip["isSelected"] as? Bool != true, chip["selected"] as? Bool != true,
                        let title = text(chip["text"] ?? chip["title"]), !title.isEmpty,
                        let target = endpoint(chip), seen.insert(title).inserted
                    else { return }
                    topics.append(RecommendationTopic(title: title, client: client, endpoint: target))
                    return
                }
                for key in dict.keys.sorted() { walk(dict[key] as Any, depth: depth + 1) }
            } else if let array = value as? [Any] {
                for item in array { walk(item, depth: depth + 1) }
            }
        }
        walk(response)
        return topics
    }
}

public protocol RecommendationTopicsAPI: Sendable {
    func fetchRecommendationTopics() async throws -> [RecommendationTopic]
    func fetchRecommendationVideos(topic: RecommendationTopic, continuation: String?) async throws -> VideoGroup
}
