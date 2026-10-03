import Foundation

/// ISO country codes used by YouTube's content-location (`gl`) request field.
public enum FeedCountry {
    public static let defaultCode = "US"
    // Content regions from YouTube's location picker, also maintained in
    // NewPipeExtractor's YoutubeService.SUPPORTED_COUNTRIES. Not every ISO
    // territory has a YouTube content region.
    public static let codes = [
        "DZ", "AR", "AU", "AT", "AZ", "BH", "BD", "BY", "BE", "BO", "BA", "BR", "BG", "KH",
        "CA", "CL", "CO", "CR", "HR", "CY", "CZ", "DK", "DO", "EC", "EG", "SV", "EE", "FI",
        "FR", "GE", "DE", "GH", "GR", "GT", "HN", "HK", "HU", "IS", "IN", "ID", "IQ", "IE",
        "IL", "IT", "JM", "JP", "JO", "KZ", "KE", "KW", "LA", "LV", "LB", "LY", "LI", "LT",
        "LU", "MY", "MT", "MX", "ME", "MA", "NP", "NL", "NZ", "NI", "NG", "MK", "NO", "OM",
        "PK", "PA", "PG", "PY", "PE", "PH", "PL", "PT", "PR", "QA", "RO", "RU", "SA", "SN",
        "RS", "SG", "SK", "SI", "ZA", "KR", "ES", "LK", "SE", "CH", "TW", "TZ", "TH", "TN",
        "TR", "UG", "UA", "AE", "GB", defaultCode, "UY", "VE", "VN", "YE", "ZW",
    ].sorted()

    public static func normalized(_ code: String) -> String {
        let value = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return codes.contains(value) ? value : defaultCode
    }

    public static func name(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }
}
