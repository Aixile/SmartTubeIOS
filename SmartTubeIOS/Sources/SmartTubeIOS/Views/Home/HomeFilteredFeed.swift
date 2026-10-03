import SmartTubeIOSCore
import SwiftUI

struct HomeFilteredFeed: View {
    let sourceVideos: [Video]
    let isLoading: Bool
    let hasMore: Bool
    let errorMessage: String?
    let loadMore: () -> Void
    let refresh: () async -> Void
    let onSelect: (Video, [Video]) -> Void
    @Environment(SettingsStore.self) private var store
    private let history = LocalWatchHistoryStore.shared

    private var videos: [Video] {
        store.settings.homeVideoFilter.apply(
            to: sourceVideos, settings: store.settings,
            watchedVideoIDs: Set(history.entries.map { $0.video.id }))
    }

    var body: some View {
        let matches = videos
        ScrollView {
            VStack(spacing: 16) {
                if !matches.isEmpty {
                    Text("\(matches.count) videos")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    ForEach(store.settings.homeVideoFilter.groups(in: matches)) { group in
                        if let title = group.title {
                            HStack {
                                Text(title).font(.headline)
                                Text("\(group.videos.count)").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        VideoGridSection(videos: group.videos, onSelect: { onSelect($0, group.videos) })
                    }
                } else if !isLoading {
                    ContentUnavailableView(
                        hasMore ? "No matches yet" : "No matching videos",
                        systemImage: AppSymbol.filters,
                        description: Text(hasMore ? "Load more videos or try fewer filters." : "Try fewer filters."))
                    Button("Reset filters") { store.settings.homeVideoFilter = HomeVideoFilter() }
                        .accessibilityIdentifier(AccessibilityID.Home.filterReset)
                }
                if isLoading {
                    ProgressView("Loading videos…").padding()
                } else {
                    if let errorMessage { Text(errorMessage).foregroundStyle(.secondary) }
                    if hasMore {
                        Button("Load more videos", action: loadMore)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(AccessibilityID.Home.filteredLoadMore)
                    } else if errorMessage != nil {
                        Button("Try again") { Task { await refresh() } }
                    }
                    Text("Filters and sorting apply to videos loaded in this feed.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical)
        }
        .refreshable { await refresh() }
        .accessibilityIdentifier(AccessibilityID.Home.filteredFeed)
    }
}
