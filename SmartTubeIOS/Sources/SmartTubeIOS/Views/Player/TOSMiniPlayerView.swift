#if os(iOS)
import SwiftUI
import WebKit
import SmartTubeIOSCore

// MARK: - TOSMiniPlayerView

/// Uses the same floating window as native playback while keeping the web video attached.
struct TOSMiniPlayerView: View {
    @Environment(TOSPlayerStateStore.self) private var tosState

    private var isPlaying: Bool {
        tosState.vm?.playerState == .playing || tosState.vm?.playerState == .buffering
    }

    var body: some View {
        FloatingMiniPlayerView(
            title: tosState.currentVideo?.title ?? "",
            isPlaying: isPlaying,
            windowIdentifier: AccessibilityID.MiniPlayer.webWindow,
            expandIdentifier: AccessibilityID.MiniPlayer.webExpand,
            playPauseIdentifier: AccessibilityID.MiniPlayer.webPlayPause,
            closeIdentifier: AccessibilityID.MiniPlayer.webClose,
            onExpand: { tosState.expand() },
            onPlayPause: {
                if isPlaying { tosState.vm?.pause() } else { tosState.vm?.play() }
            },
            onClose: { tosState.stop() },
            videoContent: {
                if let webView = tosState.vm?.webView {
                    TOSMiniPlayerLayerView(webView: webView)
                        .accessibilityHidden(true)
                } else if let thumbnail = tosState.currentVideo?.thumbnailURL {
                    AsyncImage(url: thumbnail) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.black
                    }
                    .accessibilityHidden(true)
                } else {
                    Color.black
                }
            })
    }
}

// MARK: - TOSMiniPlayerLayerView

/// UIViewRepresentable that hosts the TOS player's WKWebView as a live thumbnail.
/// UIView.addSubview transplants the webView from the full-screen
/// YouTubeWebPlayerView's container automatically — no explicit removeFromSuperview
/// needed. Keeping the webView attached to the window keeps the embedded YouTube
/// <video> element's document.visibilityState == 'visible', so playback continues
/// while minimized. Mirrors MiniPlayerLayerView's transplant pattern for AVPlayer.
private struct TOSMiniPlayerLayerView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.clipsToBounds = true
        attach(to: container)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if webView.superview !== uiView {
            attach(to: uiView)
        }
    }

    private func attach(to container: UIView) {
        // Disable interaction so taps fall through to the SwiftUI buttons
        // (expand / play-pause / close) overlaying this view, rather than being
        // captured by YouTube's native player controls inside the WKWebView.
        webView.isUserInteractionEnabled = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }
}
#endif  // os(iOS)
