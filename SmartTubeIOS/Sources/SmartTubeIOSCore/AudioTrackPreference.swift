import Foundation

/// One policy for AVFoundation renditions and YouTube's per-language HLS variants.
public enum AudioTrackPreference {
    public static let original = "original"
    public static let system = "system"

    public static func select(
        from tracks: [AudioTrack], preferred: String?, deviceLanguages: [String] = Locale.preferredLanguages
    ) -> AudioTrack? {
        let creatorTrack = tracks.first(where: \.isOriginal)
        let preference = preferred ?? original
        if preference == original { return creatorTrack ?? tracks.first }
        let languages = preference == system ? deviceLanguages : [preference]
        for language in languages {
            let normalized = normalize(language)
            let exact = tracks.filter { normalize($0.languageCode) == normalized }
            if let match = exact.first(where: \.isOriginal) ?? exact.first { return match }
            let base = normalized.split(separator: "-").first
            let matches = tracks.filter { normalize($0.languageCode).split(separator: "-").first == base }
            if let match = matches.first(where: \.isOriginal) ?? matches.first { return match }
        }
        return creatorTrack ?? tracks.first
    }

    /// Choosing Original must follow the creator's language on each new video,
    /// rather than saving one video's language (e.g. Chinese) as a global override.
    public static func savedPreference(for track: AudioTrack?) -> String {
        guard let track, !track.isOriginal else { return original }
        return track.languageCode
    }

    private static func normalize(_ language: String) -> String {
        language.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}
