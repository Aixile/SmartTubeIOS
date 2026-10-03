#if os(iOS)
import SwiftUI

/// One live video window with a small set of controls shared by both players.
struct FloatingMiniPlayerView<VideoContent: View>: View {
    let title: String
    let isPlaying: Bool
    let windowIdentifier: String
    let expandIdentifier: String
    let playPauseIdentifier: String
    let closeIdentifier: String
    let onExpand: () -> Void
    let onPlayPause: () -> Void
    let onClose: () -> Void
    @ViewBuilder var videoContent: () -> VideoContent

    var body: some View {
        ZStack {
            Button(action: onExpand) {
                videoContent()
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .contentShape(Rectangle())
                    .overlay(alignment: .topLeading) {
                        controlImage(symbol: AppSymbol.expandVideo)
                            .padding(4)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Expand video: \(title)")
            .accessibilityIdentifier(expandIdentifier)

            VStack {
                HStack {
                    Spacer()
                    control(symbol: AppSymbol.xmark, label: "Close video", identifier: closeIdentifier, action: onClose)
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    control(
                        symbol: isPlaying ? AppSymbol.pause : AppSymbol.play,
                        label: isPlaying ? "Pause" : "Play",
                        identifier: playPauseIdentifier,
                        action: onPlayPause)
                }
            }
            .padding(4)
        }
        .clipShape(RoundedRectangle(cornerRadius: MiniPlayerLayout.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MiniPlayerLayout.cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(windowIdentifier)
        .accessibilityHint("Drag to move the video window")
    }

    private func control(symbol: String, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            controlImage(symbol: symbol)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func controlImage(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(.black.opacity(0.6), in: Circle())
            .frame(width: MiniPlayerLayout.controlSize, height: MiniPlayerLayout.controlSize)
    }
}

#endif
