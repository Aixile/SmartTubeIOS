import Foundation

// MARK: - AudioTrack

/// A single audio rendition from an HLS manifest, exposed via AVMediaSelectionGroup.
/// AVMediaSelectionOption itself is not Sendable, so we snapshot the data we need
/// into this struct at load time; the actual option is kept in PlaybackViewModel.
public struct AudioTrack: Identifiable, Hashable, Sendable {
    /// Stable rendition identifier, distinguishing tracks that share a language.
    public let id: String
    /// Localised display name (e.g. "English", "Spanish", "French").
    public let name: String
    /// ISO 639-1 / BCP 47 language code from the rendition.
    public let languageCode: String
    /// `true` when metadata identifies the creator's original audio.
    /// A server-selected HLS default can be a dub, so it is not sufficient on its own.
    public let isOriginal: Bool
    /// The `YT-EXT-AUDIO-CONTENT-ID` value used to filter HLS variants via the proxy.
    /// `nil` for tracks sourced from `#EXT-X-MEDIA` groups (AVMediaSelectionGroup path)
    /// and for the synthetic "Original" entry added when the original-audio variant
    /// lacks a `YT-EXT-AUDIO-CONTENT-ID` attribute. When `nil`, the proxy keeps
    /// variants that have *no* `YT-EXT-AUDIO-CONTENT-ID` (i.e. the original stream).
    public let contentID: String?

    public init(
        id: String, name: String, languageCode: String, isOriginal: Bool,
        contentID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.languageCode = languageCode
        self.isOriginal = isOriginal
        self.contentID = contentID
    }
}
