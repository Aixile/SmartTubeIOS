import Foundation

/// Reads the current watch page's date, avoiding dates in suggested-video scripts.
func extractYouTubePublicationDate(from html: String, videoID: String) -> String? {
    let tags = watchPageTags(in: html)
    let canonical = tags.first { $0.name == "link" && $0.attributes["rel"]?.lowercased() == "canonical" }?
        .attributes["href"]
    let ogURL = tags.first { $0.name == "meta" && $0.attributes["property"]?.lowercased() == "og:url" }?
        .attributes["content"]
    guard let pageURL = (canonical ?? ogURL).flatMap(URL.init(string:)),
        YouTubeLinkHandler.videoID(from: pageURL) == videoID
    else { return nil }

    for property in ["datepublished", "uploaddate"] {
        for tag in tags where tag.name == "meta" && tag.attributes["itemprop"]?.lowercased() == property {
            if let raw = tag.attributes["content"], Video.parsePublicationDate(raw) != nil {
                return String(raw.prefix(10))
            }
        }
    }
    return nil
}

private struct WatchPageTag {
    let name: String
    let attributes: [String: String]
}

private func watchPageTags(in html: String) -> [WatchPageTag] {
    guard let tagRegex = try? NSRegularExpression(pattern: #"<(meta|link)\b[^>]*>"#, options: [.caseInsensitive]),
        let attributeRegex = try? NSRegularExpression(
            pattern: #"([\w:-]+)\s*=\s*(["'])(.*?)\2"#, options: [.dotMatchesLineSeparators])
    else { return [] }
    return tagRegex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
        guard let range = Range(match.range, in: html), let nameRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let text = String(html[range])
        var attributes: [String: String] = [:]
        for attribute in attributeRegex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let keyRange = Range(attribute.range(at: 1), in: text),
                let valueRange = Range(attribute.range(at: 3), in: text)
            else { continue }
            attributes[String(text[keyRange]).lowercased()] = String(text[valueRange])
                .replacingOccurrences(of: "&amp;", with: "&")
        }
        return WatchPageTag(name: String(html[nameRange]).lowercased(), attributes: attributes)
    }
}
