import SmartTubeIOSCore
import SwiftUI

struct RecommendationTopicPicker: View {
    let model: RecommendationTopicsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var topics: [RecommendationTopic] {
        model.topics.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Topics").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .accessibilityIdentifier(AccessibilityID.Home.topicPickerDone)
            }
            .padding(.top)
            .padding(.horizontal)
            FeedCountryButton().padding(.horizontal)
            TextField("Search topics", text: $query)
                .textFieldStyle(.roundedBorder).padding(.horizontal)
                .accessibilityIdentifier(AccessibilityID.Home.topicSearch)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                    choice("All", id: AccessibilityID.Home.allTopics, selected: model.selectedTopic == nil) {
                        model.select(nil)
                    }
                    ForEach(topics) { topic in
                        choice(topic.title, id: topic.id, selected: model.selectedTopic?.id == topic.id) {
                            model.select(topic)
                        }
                    }
                }
                .padding(.horizontal)
                if model.isLoadingTopics {
                    ProgressView().padding()
                } else if topics.isEmpty {
                    Text(query.isEmpty ? "No topics available yet" : "No matching topics")
                        .foregroundStyle(.secondary).padding()
                    if query.isEmpty {
                        Button("Reload topics") { Task { await model.loadTopics() } }
                    }
                }
            }
        }
        .frame(idealWidth: 600, idealHeight: 680)
        .accessibilityIdentifier(AccessibilityID.Home.topicPicker)
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private func choice(_ title: String, id: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Text(title).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if selected { Image(systemName: AppSymbol.checkmark) }
            }
            .font(.subheadline.weight(.medium))
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(
                selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier(AccessibilityID.Home.topicChoice(id))
    }
}
