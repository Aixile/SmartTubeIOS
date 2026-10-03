import SmartTubeIOSCore
import SwiftUI

struct HomeBrowseHeader: View {
    let sections: [BrowseSection]
    let selectedSection: BrowseSection
    let topics: RecommendationTopicsViewModel
    let onSelect: (BrowseSection) -> Void
    @Binding var filter: HomeVideoFilter
    @State private var showsTopics = false

    private var hasRecommendations: Bool {
        selectedSection.type == .home || selectedSection.type == .recommended
    }

    var body: some View {
        HStack(spacing: 4) {
            Menu {
                ForEach(sections) { section in
                    Button {
                        onSelect(section)
                    } label: {
                        if section == selectedSection {
                            Label(section.title, systemImage: AppSymbol.checkmark)
                        } else {
                            Text(section.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedSection.title).font(.title2.bold()).lineLimit(1)
                    Image(systemName: AppSymbol.chevronDown)
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                .frame(minHeight: BrowseHeaderLayout.controlSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose feed: \(selectedSection.title)")
            .accessibilityIdentifier(AccessibilityID.Home.feedMenu)

            Spacer(minLength: 0)
            if hasRecommendations {
                Button {
                    showsTopics = true
                } label: {
                    Image(systemName: AppSymbol.topics).font(.title3)
                        .frame(width: BrowseHeaderLayout.controlSize, height: BrowseHeaderLayout.controlSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show all topics")
                .accessibilityIdentifier(AccessibilityID.Home.topicPickerButton)
                groupingMenu
                HomeFiltersButton(filter: $filter)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Home.header)
        .sheet(isPresented: $showsTopics) { RecommendationTopicPicker(model: topics) }
    }

    private var groupingMenu: some View {
        Menu {
            Picker("Group by", selection: $filter.grouping) {
                ForEach(HomeVideoFilter.Grouping.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Image(systemName: AppSymbol.grouping).font(.title3)
                .foregroundStyle(filter.grouping == .none ? Color.primary : Color.accentColor)
                .frame(width: BrowseHeaderLayout.controlSize, height: BrowseHeaderLayout.controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Group videos")
        .accessibilityValue(filter.grouping.rawValue)
        .accessibilityIdentifier(AccessibilityID.Home.groupingMenu)
    }
}
