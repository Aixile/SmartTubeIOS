import SmartTubeIOSCore
import SwiftUI

// MARK: - ChannelView
//
// Displays channel info, subscriber count and a grid of recent uploads.
// Mirrors the Android `ChannelFragment`.

public struct ChannelView: View {
    public let channelId: String
    @State private var vm = ChannelViewModel()
    @State private var selectedVideo: Video?
    @State private var shortsPresentation: ShortsPresentation?
    @State private var channelDestination: ChannelDestination?
    @State private var filter = ChannelVideoFilter()
    @State private var showsFilters = false
    @State private var loadedChannelId: String?
    @State private var isFollowedLocally = false
    private let history = LocalWatchHistoryStore.shared
    @Environment(SettingsStore.self) private var store
    @Environment(AuthService.self) private var auth
    @Environment(\.innerTubeAPI) private var api
    @Environment(\.isLandscapeLayout) private var isLandscapeLayout
    #if os(iOS)
    @Environment(PlayerRouter.self) private var playerRouter
    #endif

    public init(channelId: String) {
        self.channelId = channelId
    }

    public var body: some View {
        Group {
            if vm.isLoading && vm.channel == nil {
                ProgressView("Loading channel…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(AccessibilityID.Channel.view)
            } else {
                content
            }
        }
        .navigationTitle(vm.channel?.title ?? "Channel")
        .task(id: channelId) {
            guard loadedChannelId != channelId else { return }
            vm = ChannelViewModel(api: api)
            loadedChannelId = channelId
            vm.load(channelId: channelId)
            await vm.waitForCurrentRequest()
        }
        .sheet(isPresented: $showsFilters) { ChannelFiltersSheet(filter: $filter) }
        .task(id: vm.channel?.id) {
            guard let id = vm.channel?.id else { return }
            isFollowedLocally = await LocalSubscriptionStore.shared.isFollowing(id)
        }
        #if !os(iOS) && !os(macOS)
        .fullScreenCover(item: $selectedVideo) { video in
            PlayerView(video: video, api: api)
        }
        #endif
        #if os(macOS)
        .navigationDestination(item: $selectedVideo) { video in
            PlayerView(video: video, api: api)
        }
        #endif
        .navigationDestination(item: $channelDestination) { dest in
            ChannelView(channelId: dest.channelId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openChannel)) { note in
            guard let channelId = note.userInfo?["channelId"] as? String, !channelId.isEmpty else { return }
            channelDestination = ChannelDestination(channelId: channelId)
        }
        #if !os(macOS)
        .fullScreenCover(item: $shortsPresentation) { target in
            ShortsPlayerView(videos: target.videos, startIndex: target.startIndex, api: api)
        }
        #endif
        .alert(
            "Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } }),
            presenting: vm.error
        ) { _ in
            Button("Retry") {
                if vm.hasMore { vm.loadMore() } else { vm.load(channelId: channelId) }
            }
            Button("Dismiss", role: .cancel) {}
        } message: { err in
            Text(err.localizedDescription)
        }
        .toolbar {
            if let channel = vm.channel {
                #if os(macOS)
                ToolbarItem(placement: .automatic) {
                    let isExcluded = store.settings.sponsorBlockExcludedChannels[channel.id] != nil
                    Button {
                        toggleSponsorBlockExclusion(for: channel)
                    } label: {
                        Label(
                            isExcluded ? "Remove SponsorBlock Exclusion" : "Exclude from SponsorBlock",
                            systemImage: isExcluded
                                ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.minus"
                        )
                    }
                }
                #else
                ToolbarItem(placement: .topBarTrailing) {
                    let isExcluded = store.settings.sponsorBlockExcludedChannels[channel.id] != nil
                    Button {
                        toggleSponsorBlockExclusion(for: channel)
                    } label: {
                        Label(
                            isExcluded ? "Remove SponsorBlock Exclusion" : "Exclude from SponsorBlock",
                            systemImage: isExcluded
                                ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.minus"
                        )
                    }
                    .accessibilityIdentifier(AccessibilityID.Channel.sponsorBlockButton)
                }
                #endif
            }
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if let channel = vm.channel { channelHeader(channel) }
                Section {
                    let filtered = filteredVideos
                    if filtered.isEmpty && !vm.isLoading {
                        ContentUnavailableView {
                            Label("No matching videos", systemImage: AppSymbol.search)
                        } description: {
                            Text(
                                vm.hasMore
                                    ? "Try different filters or load more videos below."
                                    : "Try changing or clearing your filters.")
                        } actions: {
                            if filter.isActive { Button("Clear filters") { filter = ChannelVideoFilter() } }
                        }
                    } else if filter.kind == .shorts {
                        shortsGrid(filtered)
                    } else {
                        videosGrid(filtered)
                    }
                    paginationFooter
                } header: {
                    filterBar
                }
            }
        }
        .refreshable {
            vm.load(channelId: channelId)
            await vm.waitForCurrentRequest()
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .accessibilityIdentifier(AccessibilityID.Channel.view)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: AppSymbol.search).foregroundStyle(.secondary)
                TextField("Search loaded videos", text: $filter.query)
                    .accessibilityIdentifier(AccessibilityID.Channel.search)
                Button {
                    showsFilters = true
                } label: {
                    Label(
                        filter.activeCount == 0 ? "Filters" : "Filters (\(filter.activeCount))",
                        systemImage: AppSymbol.filters)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(AccessibilityID.Channel.filtersButton)
            }
            Picker("Membership", selection: $filter.access) {
                ForEach(ChannelVideoFilter.Access.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityID.Channel.access)
            HStack {
                Text("\(filteredVideos.count) matching · \(vm.videos.count) loaded")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if filter.isActive {
                    Button("Clear") { filter = ChannelVideoFilter() }
                        .font(.caption)
                        .accessibilityIdentifier(AccessibilityID.Channel.reset)
                }
            }
        }
        .padding()
        .background(.background)
    }

    private var paginationFooter: some View {
        VStack(spacing: 8) {
            if vm.isLoading {
                ProgressView("Loading videos…")
            } else if vm.hasMore {
                Button("Load more videos") { vm.loadMore() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(AccessibilityID.Channel.loadMore)
                    .onAppear {
                        if !filter.isActive && vm.error == nil { vm.loadMore() }
                    }
                Text("Filters and sorting apply to loaded videos.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var filteredVideos: [Video] {
        filter.apply(
            to: vm.videos, hideShorts: store.settings.hideShorts, watchedThreshold: store.settings.hideWatchedThreshold,
            watchedVideoIDs: Set(history.entries.map { $0.video.id }))
    }

    // MARK: - Grid layouts

    private func videosGrid(_ videos: [Video]) -> some View {
        let compact = store.settings.compactThumbnails
        return Group {
            if compact {
                LazyVStack(spacing: 0) {
                    ForEach(videos) { video in
                        VideoCardView(video: video, compact: true)
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .accessibilityIdentifier(AccessibilityID.Channel.videoCard(video.id))
                            .onTapGesture {
                                #if os(iOS)
                                playerRouter.open(video: video, api: api)
                                #else
                                selectedVideo = video
                                #endif
                            }
                        Divider().padding(.horizontal)
                    }
                }
            } else {
                #if os(tvOS)
                let columnCount = 4
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(stride(from: 0, to: videos.count, by: columnCount)), id: \.self) { startIdx in
                        let rowVideos = Array(videos[startIdx..<min(startIdx + columnCount, videos.count)])
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(rowVideos) { video in
                                VideoCardView(video: video, compact: false, onSelect: { selectedVideo = video })
                                    .frame(maxWidth: .infinity)
                                    .accessibilityIdentifier(AccessibilityID.Channel.videoCard(video.id))
                            }
                            let remainder = columnCount - rowVideos.count
                            if remainder > 0 {
                                ForEach(0..<remainder, id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding()
                #else
                LazyVGrid(
                    columns: videoGridColumns(store.settings, landscape: isLandscapeLayout),
                    spacing: videoGridRowSpacing
                ) {
                    ForEach(videos) { video in
                        VideoCardView(video: video, compact: false)
                            .accessibilityIdentifier(AccessibilityID.Channel.videoCard(video.id))
                            .onTapGesture {
                                #if os(iOS)
                                playerRouter.open(video: video, api: api)
                                #else
                                selectedVideo = video
                                #endif
                            }
                    }
                }
                .id(isLandscapeLayout)  // reset on column-count change — see VideoGridSection (#82)
                .padding()
                #endif
            }
        }
    }

    private func shortsGrid(_ videos: [Video]) -> some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(videos) { video in
                VideoCardView(video: video)
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .onTapGesture { selectShort(video, from: videos) }
            }
        }
        .padding(.horizontal)
        .accessibilityIdentifier(AccessibilityID.Channel.videoGrid)
    }

    private func selectShort(_ video: Video, from videos: [Video]) {
        let idx = videos.firstIndex(where: { $0.id == video.id }) ?? 0
        shortsPresentation = ShortsPresentation(videos: videos, startIndex: idx)
    }

    private func toggleSponsorBlockExclusion(for channel: Channel) {
        if store.settings.sponsorBlockExcludedChannels[channel.id] != nil {
            store.settings.sponsorBlockExcludedChannels.removeValue(forKey: channel.id)
        } else {
            store.settings.sponsorBlockExcludedChannels[channel.id] = channel.title
        }
    }

    private func channelHeader(_ channel: Channel) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: channel.thumbnailURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.secondary.opacity(0.3))
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier(AccessibilityID.Channel.title)
                if let subs = channel.subscriberCount {
                    Text(subs)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let desc = channel.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if !auth.isSignedIn {
                Button {
                    Task { await toggleFollow(channel) }
                } label: {
                    Label(
                        isFollowedLocally ? "Unfollow" : "Follow",
                        systemImage: isFollowedLocally ? "bell.slash" : "bell"
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(AccessibilityID.Channel.followButton)
            }
        }
        .padding()
        .background(.background)
        .accessibilityIdentifier(AccessibilityID.Channel.header)
    }

    private func toggleFollow(_ channel: Channel) async {
        if isFollowedLocally {
            await LocalSubscriptionStore.shared.unfollow(channelId: channel.id)
            isFollowedLocally = false
        } else {
            let local = LocalChannel(
                id: channel.id,
                title: channel.title,
                thumbnailURL: channel.thumbnailURL
            )
            await LocalSubscriptionStore.shared.follow(local)
            isFollowedLocally = true
        }
    }
}
