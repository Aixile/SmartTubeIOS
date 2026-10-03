/// Remembers the player's last foreground orientation across screen locking.
/// Sensor values observed while inactive must not replace that orientation.
public struct PlayerOrientationState: Equatable, Sendable {
    public private(set) var isLandscape = false
    private var physicalLandscape = false
    private var isPresented = false

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
        self.physicalLandscape = physicalLandscape
        setForceLandscape(forceLandscape)
    }

    public mutating func setForceLandscape(_ forceLandscape: Bool) {
        isLandscape = forceLandscape || physicalLandscape
    }

    public mutating func dismiss() {
        self = Self()
    }
}
