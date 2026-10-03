import SmartTubeIOSCore
import SwiftUI
import os

#if canImport(UIKit)
import UIKit
#endif

private let swipeLog = Logger(subsystem: "com.void.smarttube.app", category: "TOSSwipe")

// MARK: - TOSSwipeNavigationOverlay
//
// Right-swipe return for the web player, matching the native player's Back action.
// Video navigation is handled by explicit Previous/Next controls.
//
// Reuses PassthroughGestureView (SwipeGestureOverlay.swift) so the pan gesture
// recognizer is re-homed onto the window and never blocks touches to the
// WKWebView's own controls. To avoid stealing YouTube's native bottom
// scrubber/control-bar drag (which also uses horizontal pans for seeking),
// `gestureRecognizer(_:shouldReceive:)` only accepts touches starting in the
// top `verticalActivationFraction` of the screen.

#if os(iOS)
struct TOSSwipeNavigationOverlay: UIViewRepresentable {
    var onReturn: () -> Void
    /// Called on any tap anywhere on the player. Receives window coordinates so
    /// the caller can distinguish tap zones (e.g. native controls area at bottom).
    var onTap: ((CGPoint) -> Void)? = nil
    /// #19: continuous vertical-drag callback for brightness (outer-left 20% of the screen)
    /// / volume (outer-right 20%, #148), fired on every `.changed` update of a drag where vertical
    /// movement dominates horizontal (so it never fires alongside a horizontal swipe-nav
    /// gesture). `isLeftHalf` is fixed for the whole gesture from where the touch began; drags starting
    /// in the middle 60% never call this.
    /// `translationY`/`viewHeight` let the caller compute a delta-from-gesture-start value
    /// itself (this view holds no brightness/volume state of its own).
    var onVerticalDragChanged: ((_ isLeftHalf: Bool, _ translationY: CGFloat, _ viewHeight: CGFloat) -> Void)? = nil
    /// Fired once when a vertical drag ends (or is cancelled) — lets the caller reset its
    /// per-gesture start value and dismiss any on-screen brightness/volume indicator.
    var onVerticalDragEnded: (() -> Void)? = nil
    var isEnabled: Bool = true
    /// Touches below this fraction of the screen height are ignored, leaving
    /// YouTube's bottom scrubber/control-bar free to handle horizontal drags.
    var verticalActivationFraction: CGFloat = 0.75
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PassthroughGestureView {
        let view = PassthroughGestureView()
        view.backgroundColor = .clear

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        context.coordinator.pan = pan

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        context.coordinator.tap = tap

        view.managedGestureRecognizers = [pan, tap]
        return view
    }

    func updateUIView(_ uiView: PassthroughGestureView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.pan?.isEnabled = isEnabled
        context.coordinator.tap?.isEnabled = isEnabled
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TOSSwipeNavigationOverlay
        weak var pan: UIPanGestureRecognizer?
        weak var tap: UITapGestureRecognizer?
        /// Fixed at gesture `.began` from the touch's initial x — which half of the
        /// screen a vertical drag started in doesn't change mid-gesture even if the
        /// finger crosses the midline.
        private var verticalDragIsLeftHalf: Bool?
        /// True once the gesture has committed to being a vertical (brightness/volume)
        /// drag rather than a horizontal swipe — set on the first `.changed` where
        /// vertical movement dominates, so a gesture can't flip categories mid-drag.
        private var isVerticalDrag = false
        /// Captured at `.began` — the touch's x-position in the gesture's view, used both
        /// to decide whether a vertical drag started in the left or right edge zone.
        private var gestureStartX: CGFloat?

        init(_ parent: TOSSwipeNavigationOverlay) {
            self.parent = parent
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // Pan only fires in the top verticalActivationFraction of the screen.
            // Tap fires everywhere — no vertical restriction.
            guard gestureRecognizer === pan else { return true }
            let window = (gestureRecognizer.view as? UIWindow) ?? gestureRecognizer.view?.window
            guard let window else { return true }
            let y = touch.location(in: window).y
            let fraction = parent.verticalActivationFraction
            let accept = y <= window.bounds.height * fraction
            swipeLog.debug(
                "[shouldReceive] y=\(Int(y)) height=\(Int(window.bounds.height)) fraction=\(fraction, format: .fixed(precision: 2)) → \(accept ? "accept" : "reject")"
            )
            return accept
        }

        @MainActor @objc func handleTap(_ gr: UITapGestureRecognizer) {
            parent.onTap?(gr.location(in: nil))
        }

        @MainActor @objc func handlePan(_ gr: UIPanGestureRecognizer) {
            let t = gr.translation(in: gr.view)
            swipeLog.notice("[handlePan] state=\(gr.state.rawValue) tx=\(Int(t.x)) ty=\(Int(t.y))")

            if gr.state == .began {
                verticalDragIsLeftHalf = nil
                isVerticalDrag = false
                gestureStartX = gr.location(in: gr.view).x
                return
            }

            if gr.state == .changed {
                // Once a gesture commits to horizontal (a swipe-nav candidate), never
                // switch it to vertical mid-drag — only the reverse (small initial
                // wiggle before the real direction emerges) is allowed.
                if !isVerticalDrag, abs(t.y) > abs(t.x), abs(t.y) > 8 {
                    isVerticalDrag = true
                    if let view = gr.view {
                        let startX = gestureStartX ?? (gr.location(in: view).x - t.x)
                        // #148: only the outer edge strips adjust brightness/volume; a
                        // vertical drag starting mid-screen commits to "vertical" (so it can't
                        // become a swipe-nav) but leaves verticalDragIsLeftHalf nil → no-op.
                        switch GestureEdgeZone.zone(forStartX: startX, viewWidth: view.bounds.width) {
                        case .left: verticalDragIsLeftHalf = true
                        case .right: verticalDragIsLeftHalf = false
                        case nil: verticalDragIsLeftHalf = nil
                        }
                    }
                }
                if isVerticalDrag, let isLeftHalf = verticalDragIsLeftHalf, let view = gr.view {
                    parent.onVerticalDragChanged?(isLeftHalf, t.y, view.bounds.height)
                }
                return
            }

            defer {
                verticalDragIsLeftHalf = nil
                isVerticalDrag = false
                gestureStartX = nil
            }
            guard gr.state == .ended || gr.state == .cancelled else { return }
            if isVerticalDrag {
                parent.onVerticalDragEnded?()
                return
            }
            guard gr.state == .ended else { return }
            guard PlayerReturnGesture.matches(horizontal: t.x, vertical: t.y) else { return }
            parent.onReturn()
        }
    }
}
#endif
