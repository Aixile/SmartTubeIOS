/// Remembers the player's last foreground orientation across screen locking.
/// Sensor values observed while inactive must not replace that orientation.
public struct PlayerOrientationState: Equatable, Sendable {
    public private(set) var isLandscape = false
    private var physicalLandscape = false
    private var isPresented = false
    private var manualLandscape: Bool?

    public init() {}

    public mutating func present(
        physicalLandscape: Bool?, interfaceLandscape: Bool, forceLandscape: Bool
    ) {
        if !isPresented {
            self.physicalLandscape = physicalLandscape ?? interfaceLandscape
            isPresented = true
        }
        setForceLandscape(forceLandscape)
    }

    public mutating func deviceRotated(
        physicalLandscape: Bool?, sceneIsActive: Bool, forceLandscape: Bool
    ) {
        guard isPresented, sceneIsActive, let physicalLandscape else { return }
        // Geometry updates and repeated sensor events must not immediately undo
        // the button's choice. A genuine physical turn resumes automatic rotation.
        if physicalLandscape != self.physicalLandscape {
            manualLandscape = nil
        }
        self.physicalLandscape = physicalLandscape
        setForceLandscape(forceLandscape)
    }

    public mutating func setForceLandscape(_ forceLandscape: Bool) {
        isLandscape = manualLandscape ?? (forceLandscape || physicalLandscape)
    }

    public mutating func toggleOrientation(physicalLandscape: Bool? = nil) {
        guard isPresented else { return }
        if let physicalLandscape { self.physicalLandscape = physicalLandscape }
        isLandscape.toggle()
        manualLandscape = isLandscape
    }

    public mutating func clearManualOrientation() {
        manualLandscape = nil
    }

    public mutating func dismiss() {
        self = Self()
    }
}
