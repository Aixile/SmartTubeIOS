import SmartTubeIOSCore
import SwiftUI

/// Explicit video navigation, separate from both seeking and returning to browse.
struct PlayerVideoNavigationButtons: View {
    let hasPrevious: Bool
    let hasNext: Bool
    let previousIdentifier: String
    let nextIdentifier: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onPrevious) {
                Label("Previous", systemImage: AppSymbol.previousTrack)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(.black.opacity(0.5), in: Capsule())
            }
            .disabled(!hasPrevious)
            .opacity(hasPrevious ? 1 : 0.35)
            .accessibilityLabel("Previous video")
            .accessibilityIdentifier(previousIdentifier)

            Spacer(minLength: 0)

            Button(action: onNext) {
                HStack {
                    Text("Next")
                    Image(systemName: AppSymbol.nextTrack)
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .background(.black.opacity(0.5), in: Capsule())
            }
            .disabled(!hasNext)
            .opacity(hasNext ? 1 : 0.35)
            .accessibilityLabel("Next video")
            .accessibilityIdentifier(nextIdentifier)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }
}
