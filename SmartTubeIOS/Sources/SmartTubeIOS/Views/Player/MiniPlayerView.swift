#if os(iOS)
import SwiftUI
import AVFoundation
import UIKit
import SmartTubeIOSCore

// MARK: - MiniPlayerView

/// Floating live video window backed by the same AVPlayerLayer as full-screen playback.
struct MiniPlayerView: View {
    @Environment(PlayerStateStore.self) private var playerState

    var body: some View {
        FloatingMiniPlayerView(
            title: playerState.playingVideo?.title ?? "",
            isPlaying: playerState.vm.isPlaying,
            windowIdentifier: AccessibilityID.MiniPlayer.window,
            expandIdentifier: AccessibilityID.MiniPlayer.expand,
            playPauseIdentifier: AccessibilityID.MiniPlayer.playPause,
            closeIdentifier: AccessibilityID.MiniPlayer.close,
            onExpand: { playerState.expand() },
            onPlayPause: { playerState.vm.togglePlayPause() },
            onClose: { playerState.stop() },
            videoContent: {
                MiniPlayerLayerView(hostView: playerState.playerHostView)
                    .accessibilityHidden(true)
            })
    }
}

// MARK: - MiniPlayerLayerView

/// UIViewRepresentable that embeds PersistentPlayerHostView as a subview.
/// UIView.addSubview transplants the hostView from the full-screen context
/// automatically — no explicit removeFromSuperview needed.
private struct MiniPlayerLayerView: UIViewRepresentable {
    let hostView: PersistentPlayerHostView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        attach(to: container)
        return container
    }

    private func attach(to container: UIView) {
        hostView.videoGravity = .resizeAspect
        hostView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostView)
        NSLayoutConstraint.activate([
            hostView.topAnchor.constraint(equalTo: container.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if hostView.superview !== uiView { attach(to: uiView) }
    }
}
#endif
