import Foundation

extension InnerTubeAPI {
    /// Localize feed requests at the transport boundary, including continuations.
    /// Playback clients keep their existing context and stream-selection behavior.
    func feedRequestBody(_ body: [String: Any], endpoint: String) -> [String: Any] {
        guard endpoint == "browse" || endpoint == "search",
            var context = body["context"] as? [String: Any],
            var client = context["client"] as? [String: Any]
        else { return body }
        var localized = body
        client["gl"] = feedCountryCode
        context["client"] = client
        localized["context"] = context
        return localized
    }
}
