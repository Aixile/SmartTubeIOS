import SmartTubeIOSCore
import SwiftUI

struct FeedCountryButton: View {
    @Environment(SettingsStore.self) private var store
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Label("Feed country", systemImage: AppSymbol.globe)
                Spacer()
                Text(FeedCountry.name(for: store.settings.feedCountryCode))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(AccessibilityID.FeedCountry.button)
        .sheet(isPresented: $isPresented) { FeedCountryPicker() }
    }
}

private struct FeedCountryPicker: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var countries: [String] {
        FeedCountry.codes.filter {
            query.isEmpty || FeedCountry.name(for: $0).localizedCaseInsensitiveContains(query)
                || $0.localizedCaseInsensitiveContains(query)
        }.sorted { FeedCountry.name(for: $0).localizedStandardCompare(FeedCountry.name(for: $1)) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Feed country").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .accessibilityIdentifier(AccessibilityID.FeedCountry.done)
            }
            .padding(.horizontal)
            .padding(.top)
            Text("Choose the country used for recommendations. Your viewing history also shapes your feed.")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
            TextField("Search countries", text: $query)
                .textFieldStyle(.roundedBorder).padding(.horizontal)
                .accessibilityIdentifier(AccessibilityID.FeedCountry.search)
            List(countries, id: \.self) { code in
                Button {
                    store.settings.feedCountryCode = code
                    dismiss()
                } label: {
                    HStack {
                        Text(FeedCountry.name(for: code))
                        Spacer()
                        if code == store.settings.feedCountryCode { Image(systemName: AppSymbol.checkmark) }
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityAddTraits(code == store.settings.feedCountryCode ? [.isSelected] : [])
                .accessibilityIdentifier(AccessibilityID.FeedCountry.country(code))
            }
            .overlay {
                if countries.isEmpty {
                    ContentUnavailableView("No matching countries", systemImage: AppSymbol.search)
                }
            }
        }
        .frame(idealWidth: 520, idealHeight: 680)
        .accessibilityIdentifier(AccessibilityID.FeedCountry.picker)
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }
}
