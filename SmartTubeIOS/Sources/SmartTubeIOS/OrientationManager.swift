#if os(iOS)
import Foundation
import SmartTubeIOSCore
import UIKit
import OSLog

private let orientationLog = Logger(subsystem: "com.void.smarttube.app", category: "Orientation")

/// File-scope handler passed to `UIWindowScene.requestGeometryUpdate(_:errorHandler:)`.
/// Must live outside any `@MainActor` class so it does NOT inherit actor isolation.
/// On iOS 26+ UIKit calls this handler on a background GCD queue via `_BSActionResponder`;
/// a `@MainActor`-isolated closure would crash with `EXC_BREAKPOINT` in
/// `_swift_task_checkIsolatedSwift` / `_dispatch_assert_queue_fail`.
@Sendable
private func geometryUpdateErrorHandler(_ error: Error) {
    orientationLog.error("[OrientationManager] requestGeometryUpdate error: \(error.localizedDescription)")
}

/// Tracks whether the video player is currently presented on screen so that the
/// app delegate can advertise landscape-capable orientations to UIKit while the
/// player is active. Access is confined to the main actor because it is read by
/// UIApplicationDelegate (main thread) and written by PlayerView lifecycle hooks
/// (also main actor).
@MainActor
public final class OrientationManager {
    public static let shared = OrientationManager()
    private init() {}
    private var landscapeSide: PlayerOrientationState.LandscapeSide?

    /// Device and interface landscape directions are opposite (UIKit convention).
    static func landscapeSide(for orientation: UIDeviceOrientation) -> PlayerOrientationState.LandscapeSide? {
        switch orientation {
        case .landscapeLeft: .right
        case .landscapeRight: .left
        default: nil
        }
    }

    static func landscapeSide(for orientation: UIInterfaceOrientation) -> PlayerOrientationState.LandscapeSide? {
        switch orientation {
        case .landscapeLeft: .left
        case .landscapeRight: .right
        default: nil
        }
    }

    /// A left/right turn needs a geometry request even though the layout stays landscape.
    func applyPlayerOrientation(isLandscape: Bool, landscapeSide: PlayerOrientationState.LandscapeSide?) {
        let nextSide = isLandscape ? landscapeSide : nil
        let sideChanged = self.landscapeSide != nextSide
        self.landscapeSide = nextSide
        if playerIsActive != isLandscape {
            playerIsActive = isLandscape
        } else if isLandscape && sideChanged {
            restoreInterfaceOrientation()
        }
    }

    /// Set to `true` when the player is on screen AND `vm.isLandscape == true`
    /// (driven by `landscapeAlwaysPlay` or physical device orientation).
    /// Changing this value:
    ///   1. Invalidates UIKit's cached `supportedInterfaceOrientations` so the
    ///      AppDelegate can return the updated mask.
    ///   2. Requests a geometry update so the window actually rotates.
    public var playerIsActive = false {
        didSet {
            if !playerIsActive { landscapeSide = nil }
            guard oldValue != playerIsActive else {
                orientationLog.notice(
                    "[OrientationManager] playerIsActive set to \(self.playerIsActive) — no change, skipping")
                return
            }
            orientationLog.notice("[OrientationManager] playerIsActive: \(oldValue) → \(self.playerIsActive)")
            restoreInterfaceOrientation()
        }
    }

    /// Advertise only the chosen layout, so UIKit cannot independently rotate a
    /// landscape-locked player back to portrait.
    var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        playerIsActive ? .landscape : .portrait
    }

    /// Reapply the mask after unlocking even when the desired layout is unchanged.
    func restoreInterfaceOrientation() {
        invalidateOrientationCache()
        requestGeometryUpdate()
    }

    // MARK: - Private helpers

    private func invalidateOrientationCache() {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first
        else {
            orientationLog.error("[OrientationManager] invalidateOrientationCache — no UIWindowScene found")
            return
        }
        let window =
            scene.windows.first(where: { $0.rootViewController != nil })
            ?? scene.windows.first
        let rootVC = window?.rootViewController
        orientationLog.notice(
            "[OrientationManager] invalidateOrientationCache — rootVC=\(rootVC.map { "\(type(of: $0))" } ?? "nil")")
        rootVC?.setNeedsUpdateOfSupportedInterfaceOrientations()
        var topVC = rootVC
        while let presented = topVC?.presentedViewController { topVC = presented }
        if topVC !== rootVC {
            orientationLog.notice(
                "[OrientationManager] invalidateOrientationCache — also invalidating topVC=\(type(of: topVC!))")
            topVC?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private func requestGeometryUpdate() {
        Task { @MainActor [weak self] in
            // Brief yield so UIKit processes setNeedsUpdateOfSupportedInterfaceOrientations
            // before requestGeometryUpdate consults the updated mask.
            try? await Task.sleep(for: .milliseconds(50))
            guard let self else { return }
            guard
                let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })
            else {
                orientationLog.error("[OrientationManager] requestGeometryUpdate — no UIWindowScene found")
                return
            }
            // Read the current mask after yielding; an earlier rotation request
            // must not undo a newer lock, dismissal, or foreground restoration.
            let mask: UIInterfaceOrientationMask
            if self.playerIsActive, let side = self.landscapeSide {
                mask = side == .left ? .landscapeLeft : .landscapeRight
            } else {
                mask = self.supportedInterfaceOrientations
            }
            let pref = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
            orientationLog.notice(
                "[OrientationManager] requestGeometryUpdate — requesting mask=\(mask.rawValue) on scene")
            scene.requestGeometryUpdate(pref, errorHandler: geometryUpdateErrorHandler)
        }
    }
}
#endif
