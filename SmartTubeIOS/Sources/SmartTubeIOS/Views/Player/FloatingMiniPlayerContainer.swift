#if os(iOS)
import SwiftUI
import UIKit

/// Moves the existing video host without rebuilding SwiftUI content for each pan event.
struct FloatingMiniPlayerContainer<Content: View>: UIViewControllerRepresentable {
    let tabBarBottomInset: CGFloat
    @ViewBuilder var content: () -> Content
    @Environment(PlayerStateStore.self) private var playerState
    @Environment(TOSPlayerStateStore.self) private var tosState

    // A hosting controller starts a new SwiftUI tree; explicitly carry playback stores across.
    private var hostedContent: AnyView {
        AnyView(content().environment(playerState).environment(tosState))
    }

    func makeUIViewController(context: Context) -> FloatingMiniPlayerController {
        FloatingMiniPlayerController(content: hostedContent, tabBarBottomInset: tabBarBottomInset)
    }

    func updateUIViewController(_ controller: FloatingMiniPlayerController, context: Context) {
        controller.update(content: hostedContent, tabBarBottomInset: tabBarBottomInset)
    }
}

final class FloatingMiniPlayerController: UIViewController {
    private let hostingController: UIHostingController<AnyView>
    private var tabBarBottomInset: CGFloat
    private var placement = FloatingMiniPlayerPlacement()
    private var movementBounds: FloatingMiniPlayerBounds?
    private var dragOrigin = CGPoint.zero
    private var dockingAnimator: UIViewPropertyAnimator?

    init(content: AnyView, tabBarBottomInset: CGFloat) {
        hostingController = UIHostingController(rootView: content)
        self.tabBarBottomInset = tabBarBottomInset
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        view = MiniPlayerPassthroughView()
        view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hostingController)
        hostingController.safeAreaRegions = []
        hostingController.view.backgroundColor = .clear
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        hostingController.view.addGestureRecognizer(pan)
    }

    func update(content: AnyView, tabBarBottomInset: CGFloat) {
        hostingController.rootView = content
        if self.tabBarBottomInset != tabBarBottomInset {
            self.tabBarBottomInset = tabBarBottomInset
            view.setNeedsLayout()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = FloatingMiniPlayerBounds(
            containerSize: view.bounds.size, tabBarBottomInset: tabBarBottomInset,
            safeAreaBottom: view.safeAreaInsets.bottom)
        guard bounds != movementBounds else { return }
        dockingAnimator?.stopAnimation(true)
        dockingAnimator = nil
        movementBounds = bounds
        hostingController.view.bounds.size = bounds.playerSize
        hostingController.view.center = placement.center(in: bounds)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        view.setNeedsLayout()
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let bounds = movementBounds, let window = hostingController.view else { return }
        switch pan.state {
        case .began:
            // Catch the window at its visible position if another drag interrupts docking.
            let visibleCenter = window.layer.presentation()?.position ?? window.center
            dockingAnimator?.stopAnimation(true)
            dockingAnimator = nil
            window.center = bounds.clampedCenter(visibleCenter)
            dragOrigin = window.center
            moveWindow(pan, in: bounds)
        case .changed:
            moveWindow(pan, in: bounds)
        case .ended, .cancelled:
            moveWindow(pan, in: bounds)
            placement.finishDrag(at: window.center, in: bounds)
            let destination = placement.center(in: bounds)
            let animator = UIViewPropertyAnimator(duration: MiniPlayerLayout.dockingDuration, dampingRatio: 1) {
                window.center = destination
            }
            dockingAnimator = animator
            animator.startAnimation()
        default:
            break
        }
    }

    private func moveWindow(_ pan: UIPanGestureRecognizer, in bounds: FloatingMiniPlayerBounds) {
        let translation = pan.translation(in: view)
        hostingController.view.center = bounds.clampedCenter(
            CGPoint(x: dragOrigin.x + translation.x, y: dragOrigin.y + translation.y))
    }
}

/// Feed scrolling and tab taps pass through outside the floating window.
private final class MiniPlayerPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let target = super.hitTest(point, with: event)
        return target === self ? nil : target
    }
}
#endif
