import SmartTubeIOSCore
import SwiftUI

struct ChannelFiltersSheet: View {
    @Binding var filter: ChannelVideoFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Channel filters").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .accessibilityIdentifier(AccessibilityID.Channel.filtersDone)
            }
            .padding()

            Form {
                Section("Video type") {
                    Picker("Type", selection: $filter.kind) {
                        ForEach(ChannelVideoFilter.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Channel.kind)
                }
                Section {
                    Picker("Access", selection: $filter.access) {
                        ForEach(ChannelVideoFilter.Access.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Channel.access)
                } header: {
                    Text("Membership")
                } footer: {
                    Text(
                        "Members-only labels come from YouTube. Regular videos have no membership badge in the returned data."
                    )
                }
                Section {
                    Picker("Watch status", selection: $filter.watchStatus) {
                        ForEach(ChannelVideoFilter.WatchStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Channel.watchStatus)
                    Picker("Duration", selection: $filter.duration) {
                        ForEach(ChannelVideoFilter.Duration.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Channel.duration)
                } header: {
                    Text("Refine")
                } footer: {
                    Text(
                        "Watch status uses this app’s history and YouTube’s watch progress. Videos with no known length are excluded by duration filters."
                    )
                }
                Section {
                    Picker("Sort by", selection: $filter.sort) {
                        ForEach(ChannelVideoFilter.Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Channel.sort)
                } header: {
                    Text("Order")
                } footer: {
                    Text(
                        "Search, filters and sorting apply to loaded videos. Use Load more videos to include more from this channel."
                    )
                }
                Section {
                    Button("Reset filters", role: .destructive) { filter = ChannelVideoFilter() }
                        .accessibilityIdentifier(AccessibilityID.Channel.reset)
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
        }
        .frame(idealWidth: 520, idealHeight: 680)
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
        .accessibilityIdentifier(AccessibilityID.Channel.filtersSheet)
    }
}

struct VideoMembershipBadge: View {
    let video: Video

    var body: some View {
        if video.isMembersOnly {
            Label(Video.membersOnlyBadge, systemImage: AppSymbol.membersOnly)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                .accessibilityIdentifier(AccessibilityID.Channel.membersBadge(video.id))
        }
    }
}
