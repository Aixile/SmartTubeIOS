import SmartTubeIOSCore
import SwiftUI

struct HomeFiltersButton: View {
    @Binding var filter: HomeVideoFilter
    @State private var showsFilters = false

    var body: some View {
        Button {
            showsFilters = true
        } label: {
            Image(systemName: AppSymbol.filters)
                .font(.title3)
                .foregroundStyle(filter.activeCount > 0 ? Color.accentColor : Color.primary)
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
        .accessibilityLabel("Video filters")
        .accessibilityValue("\(filter.activeCount) active filters")
        .accessibilityIdentifier(AccessibilityID.Home.filtersButton)
        .sheet(isPresented: $showsFilters) { HomeFiltersSheet(filter: $filter) }
    }
}

struct HomeFilterSummary: View {
    @Binding var filter: HomeVideoFilter

    var body: some View {
        if filter.isActive {
            HStack(spacing: 12) {
                Text(filter.activeLabels.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Reset") { filter = HomeVideoFilter() }
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier(AccessibilityID.Home.filterReset)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .accessibilityIdentifier(AccessibilityID.Home.filterSummary)
        }
    }
}

private struct HomeFiltersSheet: View {
    @Binding var filter: HomeVideoFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Home filters").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .accessibilityIdentifier(AccessibilityID.Home.filtersDone)
            }
            .padding()
            Form {
                Section("Find in this feed") {
                    TextField("Title or channel", text: $filter.query)
                        .accessibilityIdentifier(AccessibilityID.Home.filterSearch)
                }
                Section("Video type") {
                    Picker("Type", selection: $filter.kind) {
                        ForEach(HomeVideoFilter.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Home.filterKind)
                }
                Section {
                    Picker("Watch status", selection: $filter.watchStatus) {
                        ForEach(HomeVideoFilter.WatchStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Home.filterWatchStatus)
                    Picker("Duration", selection: $filter.duration) {
                        ForEach(HomeVideoFilter.Duration.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Home.filterDuration)
                    Picker("Uploaded", selection: $filter.uploadDate) {
                        ForEach(HomeVideoFilter.UploadDate.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Home.filterUploadDate)
                } header: {
                    Text("Refine")
                } footer: {
                    Text("Videos without a known upload date or length won’t match those filters.")
                }
                Section {
                    Picker("Sort by", selection: $filter.sort) {
                        ForEach(HomeVideoFilter.Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Home.filterSort)
                    Picker("Group by", selection: $filter.grouping) {
                        ForEach(HomeVideoFilter.Grouping.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier(AccessibilityID.Home.groupingPicker)
                } header: {
                    Text("Order")
                } footer: {
                    Text(
                        "Filters stay selected for Home and Recommended, including topics. Load more videos to find additional matches."
                    )
                }
                Section {
                    Button("Reset filters", role: .destructive) { filter = HomeVideoFilter() }
                        .accessibilityIdentifier(AccessibilityID.Home.filterReset)
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
        }
        .frame(idealWidth: 520, idealHeight: 640)
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
        .accessibilityIdentifier(AccessibilityID.Home.filtersSheet)
    }
}
