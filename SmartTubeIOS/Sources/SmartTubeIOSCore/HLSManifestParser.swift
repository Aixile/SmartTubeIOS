import Foundation

// MARK: - HLS Master Manifest Parser
//
// Parses an HLS master playlist (M3U8) and returns a map of stream height → variant URL.
// Extracted from PlaybackQualityManager.fetchHLSVariantURLs (task #133, SRP-1).
//
// On iOS/macOS the parser prefers the H.264 (avc1) variant when both HEVC and H.264
// are present at the same resolution. On tvOS the first-seen variant is kept as-is
// (tvOS hardware decoders handle HEVC efficiently with lower power consumption).

/// Parses `manifestText` as an HLS master playlist and returns a map of
/// stream height (e.g. 1080) → absolute variant playlist URL.
///
/// - Parameters:
///   - manifestText: The raw text content of the `.m3u8` master playlist.
///   - baseURL: Base URL used to resolve relative URIs in the manifest.
/// - Returns: Dictionary mapping height in pixels to the best variant URL for that height.
public func parseHLSMasterManifest(_ manifestText: String, baseURL: URL) -> [Int: URL] {
    var variants: [Int: URL] = [:]
    var variantIsH264: [Int: Bool] = [:]
    let lines = manifestText.components(separatedBy: .newlines)
    var pendingHeight: Int? = nil
    var pendingIsH264: Bool = false

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("#EXT-X-STREAM-INF") {
            pendingHeight = nil
            pendingIsH264 = false

            if let range = trimmed.range(of: #"RESOLUTION=\d+x(\d+)"#, options: .regularExpression) {
                let match = String(trimmed[range])
                if let xIdx = match.firstIndex(of: "x"),
                    let height = Int(match[match.index(after: xIdx)...])
                {
                    pendingHeight = height
                }
            }
            if let codecsRange = trimmed.range(of: #"CODECS="[^"]*""#, options: .regularExpression) {
                pendingIsH264 = trimmed[codecsRange].contains("avc1")
            }

        } else if !trimmed.hasPrefix("#"), !trimmed.isEmpty, let height = pendingHeight {
            let variantURL: URL?
            if trimmed.hasPrefix("http") {
                variantURL = URL(string: trimmed)
            } else {
                variantURL = URL(string: trimmed, relativeTo: baseURL).map { $0.absoluteURL }
            }

            if let resolvedURL = variantURL {
                if variants[height] == nil {
                    variants[height] = resolvedURL
                    variantIsH264[height] = pendingIsH264
                } else {
                    #if !os(tvOS)
                    // iOS/macOS: upgrade HEVC variant to H.264 if one arrives later.
                    if !(variantIsH264[height] ?? false) && pendingIsH264 {
                        variants[height] = resolvedURL
                        variantIsH264[height] = true
                    }
                    #endif
                }
            }
            pendingHeight = nil
            pendingIsH264 = false

        } else if trimmed.hasPrefix("#") {
            // Any tag other than #EXT-X-STREAM-INF resets pending state so
            // we don't accidentally attach a URI from a different entry.
            if pendingHeight != nil, !trimmed.hasPrefix("#EXT-X-STREAM-INF") {
                pendingHeight = nil
                pendingIsH264 = false
            }
        }
    }

    return variants
}

/// Parses a map of stream height → variant URL from the HLS master manifest for a
/// specific dubbed-audio content ID. Used by switchHLSLanguage to update hlsVariantURLs.
/// If `contentID` is nil, uses the original track's metadata, falling back to variants
/// without YT-EXT-AUDIO-CONTENT-ID when the original has no content ID.
public func parseHLSVariantURLsForLanguage(
    _ contentID: String?,
    from manifest: String,
    baseURL: URL
) -> [Int: URL] {
    let lines = manifest.components(separatedBy: "\n")
    let selectedContentID = contentID ?? parseHLSAudioLanguages(from: manifest).first(where: \.isOriginal)?.contentID
    var result: [Int: URL] = [:]
    var i = 0
    while i < lines.count {
        let line = lines[i].trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("#EXT-X-STREAM-INF:") {
            let matches = hlsVariantMatchesAudioContentID(line, contentID: selectedContentID)
            guard matches else {
                i += 2
                continue
            }

            var height = 0
            if let resRange = line.range(of: #"RESOLUTION=\d+x(\d+)"#, options: .regularExpression) {
                let resPart = String(line[resRange])
                if let h = resPart.components(separatedBy: "x").last.flatMap(Int.init) {
                    height = h
                }
            }
            i += 1
            while i < lines.count {
                let candidate = lines[i].trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty && !candidate.hasPrefix("#") { break }
                i += 1
            }
            if i < lines.count, height > 0 {
                let uriLine = lines[i].trimmingCharacters(in: .whitespaces)
                let resolved: URL?
                if uriLine.hasPrefix("http://") || uriLine.hasPrefix("https://") {
                    resolved = URL(string: uriLine)
                } else {
                    let baseDir = baseURL.deletingLastPathComponent()
                    resolved = URL(string: uriLine, relativeTo: baseDir).map { $0.absoluteURL }
                }
                if let url = resolved { result[height] = url }
            }
        }
        i += 1
    }
    return result
}

/// Parses an HLS master M3U8 manifest and returns a map of stream height → variant URL
/// for all streams present. Handles both absolute and relative URIs.
/// Returns one URL per quality level — the first variant seen per height (original audio when
/// available, first dubbed entry as fallback when the manifest omits no-CONTENT-ID variants).
public func parseHLSAllVariants(from manifest: String, baseURL: URL) -> [Int: URL] {
    let lines = manifest.components(separatedBy: "\n")
    var result: [Int: URL] = [:]
    var i = 0
    while i < lines.count {
        let line = lines[i].trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("#EXT-X-STREAM-INF:") {
            var height = 0
            if let resRange = line.range(of: #"RESOLUTION=\d+x(\d+)"#, options: .regularExpression) {
                let resPart = String(line[resRange])
                if let h = resPart.components(separatedBy: "x").last.flatMap(Int.init) {
                    height = h
                }
            }
            i += 1
            while i < lines.count {
                let candidate = lines[i].trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty && !candidate.hasPrefix("#") { break }
                i += 1
            }
            if i < lines.count, height > 0 {
                let uriLine = lines[i].trimmingCharacters(in: .whitespaces)
                let resolved: URL?
                if uriLine.hasPrefix("http://") || uriLine.hasPrefix("https://") {
                    resolved = URL(string: uriLine)
                } else {
                    let baseDir = baseURL.deletingLastPathComponent()
                    resolved = URL(string: uriLine, relativeTo: baseDir).map { $0.absoluteURL }
                }
                if let url = resolved, result[height] == nil {
                    // First entry per height wins — for YouTube's manifest order
                    // (original first, then dubbed per quality), this naturally
                    // selects the original audio variant.
                    result[height] = url
                }
            }
        }
        i += 1
    }
    return result
}

/// Parses an HLS master M3U8 manifest and returns the URL of the best stream at ≥ `minHeight`.
/// Handles both absolute URIs and relative paths (resolved against `baseURL`).
public func parseHLSBestVariant(from manifest: String, baseURL: URL, minHeight: Int) -> URL? {
    let lines = manifest.components(separatedBy: "\n")
    var bestHeight = 0
    var bestURL: URL?
    var i = 0
    while i < lines.count {
        let line = lines[i].trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("#EXT-X-STREAM-INF:") {
            // No CONTENT-ID guard needed: the `height > bestHeight` condition naturally
            // selects the first entry per quality level (original audio in YouTube's
            // manifest order, or the first dubbed entry if no original exists).
            // Extract height from RESOLUTION=WxH
            var height = 0
            if let resRange = line.range(of: #"RESOLUTION=\d+x(\d+)"#, options: .regularExpression) {
                let resPart = String(line[resRange])  // "RESOLUTION=1280x720"
                if let h = resPart.components(separatedBy: "x").last.flatMap(Int.init) {
                    height = h
                }
            }
            // Skip to next non-empty, non-comment line (the URI)
            i += 1
            while i < lines.count {
                let candidate = lines[i].trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty && !candidate.hasPrefix("#") { break }
                i += 1
            }
            if i < lines.count, height >= minHeight, height > bestHeight {
                let uriLine = lines[i].trimmingCharacters(in: .whitespaces)
                let resolved: URL?
                if uriLine.hasPrefix("http://") || uriLine.hasPrefix("https://") {
                    resolved = URL(string: uriLine)
                } else {
                    // Relative URI — resolve against the directory of the master manifest URL
                    let baseDir = baseURL.deletingLastPathComponent()
                    resolved = URL(string: uriLine, relativeTo: baseDir).map { $0.absoluteURL }
                }
                if let url = resolved {
                    bestHeight = height
                    bestURL = url
                }
            }
        }
        i += 1
    }
    return bestURL
}

/// Produces an AVFoundation-safe HLS master while preserving separate audio renditions.
/// YouTube's VisionOS master mixes H.264 and VP9 variants; tvOS may select an unsupported
/// VP9 entry even when resolution hints are set. Filtering the master (rather than loading
/// a video-only variant) keeps `EXT-X-MEDIA` audio groups and removes incompatible video.
public func filterHLSMasterManifest(
    _ manifest: String,
    maximumHeight: Int,
    requiredVideoCodec: String
) -> String {
    let lines = manifest.components(separatedBy: .newlines)
    let originalAudioGroups = Set(
        lines.compactMap { line -> String? in
            guard line.contains("#EXT-X-MEDIA:"), line.contains("TYPE=AUDIO"),
                hlsMediaLineIsOriginalAudio(line)
            else { return nil }
            return extractQuotedHLSAttribute("GROUP-ID", from: line)
        })
    var output: [String] = []
    var shouldDropNextURI = false

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if shouldDropNextURI {
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#EXT-X-STREAM-INF:") {
                shouldDropNextURI = false
            } else if trimmed.hasPrefix("#") {
                output.append(line)
                continue
            } else {
                shouldDropNextURI = false
                continue
            }
        }

        if trimmed.hasPrefix("#EXT-X-STREAM-INF:") {
            let height: Int? =
                trimmed
                .range(of: #"RESOLUTION=\d+x(\d+)"#, options: .regularExpression)
                .map { String(trimmed[$0]) }
                .flatMap { $0.components(separatedBy: "x").last }
                .flatMap(Int.init)
            let codecMatches = trimmed.localizedCaseInsensitiveContains(requiredVideoCodec)
            guard codecMatches, let height, height <= maximumHeight else {
                shouldDropNextURI = true
                continue
            }
            output.append(line)
            continue
        }

        if trimmed.hasPrefix("#EXT-X-MEDIA:"),
            trimmed.localizedCaseInsensitiveContains("TYPE=AUDIO"),
            let group = extractQuotedHLSAttribute("GROUP-ID", from: trimmed),
            originalAudioGroups.contains(group)
        {
            let defaultValue = hlsMediaLineIsOriginalAudio(trimmed) ? "YES" : "NO"
            if let range = line.range(of: #"DEFAULT=(YES|NO)"#, options: .regularExpression) {
                output.append(line.replacingCharacters(in: range, with: "DEFAULT=\(defaultValue)"))
            } else {
                output.append(line + ",DEFAULT=\(defaultValue)")
            }
            continue
        }

        output.append(line)
    }

    return output.joined(separator: "\n")
}

private func hlsMediaLineIsOriginalAudio(_ line: String) -> Bool {
    if let name = extractQuotedHLSAttribute("NAME", from: line),
        name.localizedCaseInsensitiveContains("original")
            && !name.localizedCaseInsensitiveContains("dubbed")
    {
        return true
    }
    guard let encoded = extractQuotedHLSAttribute("YT-EXT-XTAGS", from: line) else {
        return false
    }
    let padded = encoded + String(repeating: "=", count: (4 - encoded.count % 4) % 4)
    guard let data = Data(base64Encoded: padded) else { return false }
    return data.range(of: Data("original".utf8)) != nil
        && data.range(of: Data("dubbed".utf8)) == nil
}

/// Compares complete content IDs, so selecting `en.1` cannot accidentally match `en.10`.
/// A nil ID selects variants without per-language metadata.
public func hlsVariantMatchesAudioContentID(_ line: String, contentID: String?) -> Bool {
    guard let contentID else { return !line.contains("YT-EXT-AUDIO-CONTENT-ID=") }
    if let quoted = extractQuotedHLSAttribute("YT-EXT-AUDIO-CONTENT-ID", from: line) {
        return quoted == contentID
    }
    guard let range = line.range(of: "YT-EXT-AUDIO-CONTENT-ID=") else { return false }
    let value = line[range.upperBound...].split(separator: ",", maxSplits: 1).first
    return value?.trimmingCharacters(in: .whitespaces) == contentID
}
