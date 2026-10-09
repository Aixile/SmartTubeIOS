/// Remembers the player's last foreground orientation across screen locking.
/// Sensor values observed while inactive must not replace that orientation.
public struct PlayerOrientationState: Equatable, Sendable {
    /// The interface direction, which is opposite to the device's landscape direction.
    public enum LandscapeSide: Equatable, Sendable {
        case left, right
    }

    public private(set) var isLandscape = false
    public private(set) var landscapeSide: LandscapeSide?
    private var physicalLandscape = false
    private var physicalLandscapeSide: LandscapeSide?
    private var isPresented = false
    private var manualLandscape: Bool?

    public init() {}

    public mutating func present(
        physicalLandscape: Bool?, interfaceLandscape: Bool, forceLandscape: Bool,
        physicalLandscapeSide: LandscapeSide? = nil, interfaceLandscapeSide: LandscapeSide? = nil
    ) {
        if !isPresented {
            self.physicalLandscape = physicalLandscape ?? interfaceLandscape
            self.physicalLandscapeSide = physicalLandscapeSide
            landscapeSide = physicalLandscapeSide ?? interfaceLandscapeSide
            isPresented = true
        }
        setForceLandscape(forceLandscape)
    }

    public mutating func deviceRotated(
        physicalLandscape: Bool?, sceneIsActive: Bool, forceLandscape: Bool,
        physicalLandscapeSide: LandscapeSide? = nil
    ) {
        guard isPresented, sceneIsActive, let physicalLandscape else { return }
        // Geometry updates and repeated sensor events must not immediately undo
        // the button's choice. A genuine physical turn resumes automatic rotation.
        let sideChanged = physicalLandscapeSide != nil && physicalLandscapeSide != self.physicalLandscapeSide
        if physicalLandscape != self.physicalLandscape || sideChanged {
            manualLandscape = nil
        }
        self.physicalLandscape = physicalLandscape
        self.physicalLandscapeSide = physicalLandscapeSide
        if let physicalLandscapeSide { landscapeSide = physicalLandscapeSide }
        setForceLandscape(forceLandscape)
    }

    public mutating func setForceLandscape(_ forceLandscape: Bool) {
        isLandscape = manualLandscape ?? (forceLandscape || physicalLandscape)
    }

    public mutating func toggleOrientation(
        physicalLandscape: Bool? = nil, physicalLandscapeSide: LandscapeSide? = nil
    ) {
        guard isPresented else { return }
        if let physicalLandscape { self.physicalLandscape = physicalLandscape }
        self.physicalLandscapeSide = physicalLandscapeSide
        if let physicalLandscapeSide { landscapeSide = physicalLandscapeSide }
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
