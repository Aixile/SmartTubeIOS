import SmartTubeIOSCore
import SwiftUI

/// Compact pinned controls, with search and selected refinements revealed as needed.
struct ChannelBrowseHeader: View {
    @Binding var filter: ChannelVideoFilter
    let matchingCount: Int
    let loadedCount: Int
    let onShowFilters: () -> Void
    @State private var showsSearch = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Videos").font(.headline)
                    Text(filter.isActive ? "\(matchingCount) of \(loadedCount) videos" : "\(matchingCount) videos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Channel.resultCount)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                searchButton
                sortMenu
                filtersButton
            }
            .padding(.vertical, 6)

            if showsSearch {
                searchField
                    .padding(.bottom, 10)
            }
            if filter.isActive {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(activeLabels.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Reset") { filter = ChannelVideoFilter() }
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier(AccessibilityID.Channel.reset)
                }
                .padding(.bottom, 10)
                .accessibilityIdentifier(AccessibilityID.Channel.filterSummary)
            }
        }
        .padding(.horizontal, 16)
        .background(.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.primary.opacity(0.06)).frame(height: 1).allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Channel.browseHeader)
    }

    private var searchButton: some View {
        Button {
            showsSearch.toggle()
            searchFocused = showsSearch
        } label: {
            Image(systemName: AppSymbol.search)
                .font(.title3)
                .foregroundStyle(showsSearch || !filter.query.isEmpty ? Color.accentColor : Color.primary)
                .frame(width: BrowseHeaderLayout.controlSize, height: BrowseHeaderLayout.controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsSearch ? "Hide channel search" : "Search channel videos")
        .accessibilityIdentifier(AccessibilityID.Channel.searchButton)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort videos", selection: $filter.sort) {
                ForEach(ChannelVideoFilter.Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Image(systemName: AppSymbol.sort)
                .font(.title3)
                .foregroundStyle(filter.sort == .channel ? Color.primary : Color.accentColor)
                .frame(width: BrowseHeaderLayout.controlSize, height: BrowseHeaderLayout.controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sort channel videos")
        .accessibilityValue(filter.sort.rawValue)
        .accessibilityIdentifier(AccessibilityID.Channel.sortMenu)
    }

    private var filtersButton: some View {
        Button(action: onShowFilters) {
            Image(systemName: AppSymbol.filters)
                .font(.title3)
                .foregroundStyle(filter.activeCount == 0 ? Color.primary : Color.accentColor)
                .frame(width: BrowseHeaderLayout.controlSize, height: BrowseHeaderLayout.controlSize)
                .contentShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    if filter.activeCount > 0 {
                        Text("\(filter.activeCount)").font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.accentColor, in: Circle())
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Channel filters")
        .accessibilityValue("\(filter.activeCount) active filters")
        .accessibilityIdentifier(AccessibilityID.Channel.filtersButton)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: AppSymbol.search).foregroundStyle(.secondary)
            TextField("Search video titles", text: $filter.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .accessibilityIdentifier(AccessibilityID.Channel.search)
                #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
                #endif
                .onSubmit { searchFocused = false }
            if !filter.query.isEmpty {
                Button {
                    filter.query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: AppSymbol.xmarkCircle)
                        .foregroundStyle(.secondary)
                        .frame(width: BrowseHeaderLayout.controlSize, height: BrowseHeaderLayout.controlSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear channel search")
                .accessibilityIdentifier(AccessibilityID.Channel.clearSearch)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, filter.query.isEmpty ? 12 : 0)
        .frame(minHeight: BrowseHeaderLayout.controlSize)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var activeLabels: [String] {
        var labels: [String] = []
        if filter.kind != .all { labels.append(filter.kind.rawValue) }
        if filter.access != .all { labels.append(filter.access.rawValue) }
        if filter.watchStatus != .all { labels.append(filter.watchStatus.rawValue) }
        if filter.duration != .all { labels.append(filter.duration.rawValue) }
        if filter.sort != .channel { labels.append(filter.sort.rawValue) }
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty { labels.append("“\(query)”") }
        return labels
    }
}
