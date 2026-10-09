import SmartTubeIOSCore
import Testing

@Suite("Player orientation across screen locking")
struct PlayerOrientationStateTests {
    @Test("The button toggles both ways without moving the phone")
    func manualToggle() {
        var state = PlayerOrientationState()
        state.present(physicalLandscape: false, interfaceLandscape: false, forceLandscape: false)
        state.toggleOrientation()
        #expect(state.isLandscape)
        state.deviceRotated(physicalLandscape: false, sceneIsActive: true, forceLandscape: false)
        #expect(state.isLandscape)
        state.toggleOrientation()
        #expect(!state.isLandscape)
    }

    @Test("Manual portrait survives sensor duplicates, backgrounding and reappearance")
    func manualPortrait() {
        var state = landscapePlayer()
        state.toggleOrientation()
        state.deviceRotated(physicalLandscape: true, sceneIsActive: true, forceLandscape: false)
        state.deviceRotated(physicalLandscape: nil, sceneIsActive: true, forceLandscape: false)
        state.deviceRotated(physicalLandscape: false, sceneIsActive: false, forceLandscape: false)
        state.present(physicalLandscape: true, interfaceLandscape: true, forceLandscape: false)
        #expect(!state.isLandscape)
        state.dismiss()
        state.present(physicalLandscape: true, interfaceLandscape: true, forceLandscape: false)
        #expect(state.isLandscape)
    }

    @Test("A genuine physical turn resumes automatic orientation after using the button")
    func physicalTurnClearsManualChoice() {
        var state = landscapePlayer()
        state.toggleOrientation()
        #expect(!state.isLandscape)
        state.deviceRotated(physicalLandscape: false, sceneIsActive: true, forceLandscape: false)
        state.deviceRotated(physicalLandscape: true, sceneIsActive: true, forceLandscape: false)
        #expect(state.isLandscape)
    }

    @Test("Manual choice overrides Always Play until the user requests landscape locking")
    func manualChoiceAndLandscapePreference() {
        var state = landscapePlayer()
        state.setForceLandscape(true)
        state.toggleOrientation()
        state.setForceLandscape(true)
        #expect(!state.isLandscape)
        state.clearManualOrientation()
        state.setForceLandscape(true)
        #expect(state.isLandscape)
    }

    @Test("The button refreshes a stale sensor baseline without changing its target")
    func buttonRefreshesPhysicalBaseline() {
        var state = PlayerOrientationState()
        state.present(physicalLandscape: false, interfaceLandscape: false, forceLandscape: true)
        state.toggleOrientation(physicalLandscape: true)
        state.deviceRotated(physicalLandscape: true, sceneIsActive: true, forceLandscape: false)
        #expect(!state.isLandscape)
    }

    @Test("An active player switches to landscape on the first rotation event")
    func portraitToLandscape() {
        var state = PlayerOrientationState()
        state.present(physicalLandscape: false, interfaceLandscape: false, forceLandscape: false)
        #expect(!state.isLandscape)
        state.deviceRotated(physicalLandscape: true, sceneIsActive: true, forceLandscape: false)
        #expect(state.isLandscape)
        state.deviceRotated(physicalLandscape: false, sceneIsActive: true, forceLandscape: false)
        #expect(!state.isLandscape)
    }

    @Test("Inactive and background sensor events cannot replace landscape")
    func screenLockPreservesLandscape() {
        var state = landscapePlayer()
        state.deviceRotated(physicalLandscape: false, sceneIsActive: false, forceLandscape: false)
        state.deviceRotated(physicalLandscape: nil, sceneIsActive: false, forceLandscape: false)
        #expect(state.isLandscape)

        // UIKit can report portrait while restoring the player after unlocking.
        state.present(physicalLandscape: false, interfaceLandscape: false, forceLandscape: false)
        #expect(state.isLandscape)
        state.deviceRotated(physicalLandscape: nil, sceneIsActive: true, forceLandscape: false)
        #expect(state.isLandscape)

        // A genuine foreground rotation still changes the player's orientation.
        state.deviceRotated(physicalLandscape: false, sceneIsActive: true, forceLandscape: false)
        #expect(!state.isLandscape)
    }

    @Test("Rotation lock keeps landscape and unlocking follows the physical device")
    func rotationLock() {
        var state = landscapePlayer()
        state.setForceLandscape(true)
        state.deviceRotated(physicalLandscape: false, sceneIsActive: true, forceLandscape: true)
        #expect(state.isLandscape)
        state.setForceLandscape(false)
        #expect(!state.isLandscape)
    }

    @Test("Unlocking rotation with an ambiguous sensor preserves landscape")
    func ambiguousSensor() {
        var state = landscapePlayer()
        state.setForceLandscape(true)
        state.deviceRotated(physicalLandscape: nil, sceneIsActive: true, forceLandscape: true)
        state.setForceLandscape(false)
        #expect(state.isLandscape)
    }

    @Test("A new presentation can fall back to the interface orientation")
    func presentationFallbackAndDismissal() {
        var state = PlayerOrientationState()
        state.present(physicalLandscape: nil, interfaceLandscape: true, forceLandscape: false)
        #expect(state.isLandscape)
        state.dismiss()
        #expect(!state.isLandscape)
        state.present(physicalLandscape: false, interfaceLandscape: true, forceLandscape: false)
        #expect(!state.isLandscape)
    }

    @Test("Always-landscape can be toggled without losing the physical orientation")
    func landscapePreference() {
        var state = PlayerOrientationState()
        state.present(physicalLandscape: false, interfaceLandscape: false, forceLandscape: true)
        #expect(state.isLandscape)
        state.setForceLandscape(false)
        #expect(!state.isLandscape)
        state.deviceRotated(physicalLandscape: true, sceneIsActive: true, forceLandscape: false)
        state.setForceLandscape(true)
        state.setForceLandscape(false)
        #expect(state.isLandscape)
    }

    private func landscapePlayer() -> PlayerOrientationState {
        var state = PlayerOrientationState()
        state.present(physicalLandscape: true, interfaceLandscape: false, forceLandscape: false)
        return state
    }
}
