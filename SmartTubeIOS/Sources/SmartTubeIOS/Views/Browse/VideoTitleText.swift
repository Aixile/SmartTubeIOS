import SmartTubeIOSCore
import SwiftUI

/// Shared title rendering for feed cards, Shorts, and player information.
struct VideoTitleText: View {
    let video: Video
    @Environment(SettingsStore.self) private var store
    @State private var resolvedTitle: String?
    @State private var resolvedVideoID: String?

    private struct Lookup: Hashable {
        let videoID: String
        let enabled: Bool
    }

    var body: some View {
        let lookup = Lookup(videoID: video.id, enabled: store.settings.preferOriginalTitles)
        Text(
            video.displayTitle(
                originalTitle: resolvedVideoID == video.id ? resolvedTitle : nil,
                preferOriginalTitles: lookup.enabled,
                deArrowEnabled: store.settings.deArrowEnabled)
        )
        .task(id: lookup) {
            guard lookup.enabled else { return }
            let title = await OriginalVideoTitleCache.shared.title(for: lookup.videoID)
            guard !Task.isCancelled else { return }
            resolvedVideoID = lookup.videoID
            resolvedTitle = title
        }
    }
}
