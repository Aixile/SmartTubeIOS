import Foundation

extension Video {
    /// Streaming clients can omit feed metadata; only merge responses for the same video.
    public func mergingPlaybackMetadata(_ playerVideo: Video?) -> Video {
        guard let playerVideo, playerVideo.id == id else { return self }
        var result = self
        if !playerVideo.title.isEmpty { result.title = playerVideo.title }
        if !playerVideo.channelTitle.isEmpty { result.channelTitle = playerVideo.channelTitle }
        if let channelId = playerVideo.channelId, !channelId.isEmpty { result.channelId = channelId }
        result.description = playerVideo.description ?? description
        result.viewCount = playerVideo.viewCount ?? viewCount
        result.publishedAt = playerVideo.publishedAt ?? publishedAt
        result.publishedTimeText = playerVideo.publishedTimeText ?? publishedTimeText
        result.publishedDateText = playerVideo.publishedDateText ?? publishedDateText
        return result
    }

    public var publicationLabel: String? {
        if let raw = publishedDateText, let date = Self.parsePublicationDate(raw) {
            var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
            // A date-only API value must not shift to the preceding day west of UTC.
            style.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            return date.formatted(style)
        }
        if let raw = publishedTimeText?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty { return raw }
        return publishedAt?.formatted(date: .abbreviated, time: .omitted)
    }

    static func parsePublicationDate(_ raw: String) -> Date? {
        // Player microformats use ISO dates or timestamps; the visible calendar day is authoritative.
        let day = String(raw.prefix(10))
        guard day.count == 10 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: day), formatter.string(from: date) == day else { return nil }
        return date
    }
}
