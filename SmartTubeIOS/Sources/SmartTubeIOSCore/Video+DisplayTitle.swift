import Foundation

extension Video {
    public func displayTitle(originalTitle: String?, preferOriginalTitles: Bool, deArrowEnabled: Bool) -> String {
        if deArrowEnabled, let deArrowTitle, !deArrowTitle.isEmpty { return deArrowTitle }
        if preferOriginalTitles, let originalTitle, !originalTitle.isEmpty { return originalTitle }
        return title
    }
}
