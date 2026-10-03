import SmartTubeIOSCore
import SwiftUI

struct RecommendationTopicBar: View {
    let model: RecommendationTopicsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        chips.accessibilityIdentifier(AccessibilityID.Home.topicBar)
    }

    private var chips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", id: AccessibilityID.Home.allTopics, selected: model.selectedTopic == nil) {
                        model.select(nil)
                    }
                    ForEach(model.topics) { topic in
                        chip(
                            topic.title, id: AccessibilityID.Home.topic(topic.id),
                            selected: model.selectedTopic?.id == topic.id
                        ) {
                            model.select(topic)
                        }
                    }
                    if model.isLoadingTopics {
                        ProgressView().padding(.horizontal, 8)
                    } else if model.topics.isEmpty {
                        Button("Reload topics") { Task { await model.loadTopics() } }
                            .accessibilityIdentifier(AccessibilityID.Home.topicRetry)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .padding(.top, 2)
            }
            .onChange(of: model.selectedTopic?.id) { _, id in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(
                        id.map(AccessibilityID.Home.topic) ?? AccessibilityID.Home.allTopics, anchor: .center)
                }
            }
        }
    }

    private func chip(_ title: String, id: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    selected ? Color.primary : Color.secondary.opacity(0.08), in: Capsule()
                )
                .foregroundStyle(selected ? (colorScheme == .dark ? Color.black : Color.white) : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier(id)
        .id(id)
    }
}

struct TopicRecommendationsView: View {
    let model: RecommendationTopicsViewModel
    let settings: AppSettings
    let onSelect: (Video, [Video]) -> Void

    private var videos: [Video] {
        model.videos.filter {
            (!settings.hideShorts || !$0.isShort)
                && (!settings.hideLiveShorts || !($0.isShort && $0.isLive))
                && (!settings.hideVideoPremieres || !$0.isUpcoming)
                && (!settings.hideWatchedVideos || !$0.isWatched(threshold: settings.hideWatchedThreshold))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                let shorts = videos.filter(\.isShort)
                let regular = videos.filter { !$0.isShort }
                if !shorts.isEmpty {
                    ShortsRowSection(videos: shorts, onSelect: { onSelect($0, shorts) }, loadMore: { model.loadMore() })
                }
                VideoGridSection(videos: regular, onSelect: { onSelect($0, regular) }, loadMore: { model.loadMore() })
                if model.isLoading {
                    ProgressView().padding()
                } else if let error = model.errorMessage {
                    Text(error).foregroundStyle(.secondary)
                    Button("Try again") { model.retry() }
                } else if videos.isEmpty {
                    ContentUnavailableView("No videos for this topic", systemImage: AppSymbol.tvMediabox)
                }
            }
        }
        .id(model.selectedTopic?.id)
        .refreshable {
            await model.refreshSelectedTopic()
        }
        .task(id: model.nextPageToken) {
            // Hidden Shorts or watched videos can consume an entire page. Keep
            // going until there is visible content or the topic is exhausted.
            if videos.isEmpty, model.errorMessage == nil { model.loadMore() }
        }
        .accessibilityIdentifier(AccessibilityID.Home.topicFeed)
    }
}
