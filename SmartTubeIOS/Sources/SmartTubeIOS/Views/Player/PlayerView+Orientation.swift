#if os(iOS)
import SmartTubeIOSCore
import SwiftUI
import UIKit

private let playerOrientationLog = DiagnosticLogger(category: "Orientation")

extension PlayerView {
    private var forceLandscape: Bool {
        isLandscapeLocked || store.settings.landscapeAlwaysPlay
    }

    private var physicalLandscape: Bool? {
        let orientation = UIDevice.current.orientation
        return orientation.isValidInterfaceOrientation ? orientation.isLandscape : nil
    }

    private var physicalLandscapeSide: PlayerOrientationState.LandscapeSide? {
        OrientationManager.landscapeSide(for: UIDevice.current.orientation)
    }

    private var canAcceptOrientationChanges: Bool {
        // This player lives in a separate UIHostingController. Its SwiftUI
        // scenePhase/visibility can lag UIKit during presentation and unlocking.
        // UIApplication is the authoritative source for screen-lock inactivity.
        playerState.presentation == .fullScreen && UIApplication.shared.applicationState == .active
    }

    func beginOrientationTracking() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        orientationState.present(
            physicalLandscape: physicalLandscape,
            interfaceLandscape: scene?.interfaceOrientation.isLandscape ?? false,
            forceLandscape: forceLandscape,
            physicalLandscapeSide: physicalLandscapeSide,
            interfaceLandscapeSide: scene.flatMap { OrientationManager.landscapeSide(for: $0.interfaceOrientation) }
        )
        restorePlayerOrientation()
    }

    func handleDeviceOrientationChanged() {
        let acceptsChanges = canAcceptOrientationChanges
        playerOrientationLog.notice(
            "Device rotation: accepts=\(acceptsChanges) applicationState=\(UIApplication.shared.applicationState.rawValue) scenePhase=\(String(describing: scenePhase)) physicalLandscape=\(String(describing: physicalLandscape))"
        )
        orientationState.deviceRotated(
            physicalLandscape: physicalLandscape,
            sceneIsActive: acceptsChanges,
            forceLandscape: forceLandscape,
            physicalLandscapeSide: physicalLandscapeSide
        )
        guard acceptsChanges else { return }
        applyPlayerOrientation()
    }

    func synchronizeLandscapePreference() {
        guard playerState.presentation == .fullScreen else { return }
        orientationState.deviceRotated(
            physicalLandscape: physicalLandscape,
            sceneIsActive: canAcceptOrientationChanges,
            forceLandscape: forceLandscape,
            physicalLandscapeSide: physicalLandscapeSide
        )
        orientationState.setForceLandscape(forceLandscape)
        applyPlayerOrientation()
    }

    func togglePlayerOrientation() {
        guard playerState.presentation == .fullScreen else { return }
        if orientationState.isLandscape {
            // Returning to portrait also releases the landscape-only lock.
            isLandscapeLocked = false
        }
        orientationState.toggleOrientation(
            physicalLandscape: physicalLandscape, physicalLandscapeSide: physicalLandscapeSide)
        applyPlayerOrientation()
        vm.showControls()
    }

    func restorePlayerOrientation() {
        // Do not sample UIDevice here: its initial value after unlocking can be
        // portrait/unknown even though the player was landscape before locking.
        orientationState.setForceLandscape(forceLandscape)
        applyPlayerOrientation()
        OrientationManager.shared.restoreInterfaceOrientation()
    }

    private func applyPlayerOrientation() {
        vm.isLandscape = orientationState.isLandscape
        OrientationManager.shared.applyPlayerOrientation(
            isLandscape: orientationState.isLandscape, landscapeSide: orientationState.landscapeSide)
    }
}
#endif
