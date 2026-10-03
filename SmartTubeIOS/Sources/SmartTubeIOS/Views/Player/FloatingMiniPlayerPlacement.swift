import Foundation

enum MiniPlayerLayout {
    static let width: CGFloat = 224
    static let aspectRatio: CGFloat = 16.0 / 9.0
    static let margin: CGFloat = 12
    static let cornerRadius: CGFloat = 16
    static let controlSize: CGFloat = 44
    static let minimumTabBarHeight: CGFloat = 49
    // Reject safe-area values from offscreen tabs or full-screen transitions.
    static let maximumTabBarHeight: CGFloat = 100
    static let dockingDuration: TimeInterval = 0.2
}

/// Positions are normalized to the available travel, so rotation keeps the window onscreen.
struct FloatingMiniPlayerPlacement {
    var dockRight = true
    var verticalFraction: CGFloat = 1

    func center(in bounds: FloatingMiniPlayerBounds, translation: CGSize = .zero) -> CGPoint {
        let origin = CGPoint(
            x: dockRight ? bounds.right : bounds.left,
            y: bounds.top + (bounds.bottom - bounds.top) * verticalFraction)
        return bounds.clampedCenter(CGPoint(x: origin.x + translation.width, y: origin.y + translation.height))
    }

    mutating func finishDrag(_ translation: CGSize, in bounds: FloatingMiniPlayerBounds) {
        finishDrag(at: center(in: bounds, translation: translation), in: bounds)
    }

    mutating func finishDrag(at center: CGPoint, in bounds: FloatingMiniPlayerBounds) {
        let droppedCenter = bounds.clampedCenter(center)
        dockRight = droppedCenter.x >= (bounds.left + bounds.right) / 2
        let travel = bounds.bottom - bounds.top
        verticalFraction = travel > 0 ? (droppedCenter.y - bounds.top) / travel : 1
    }
}

struct FloatingMiniPlayerBounds: Equatable {
    let playerSize: CGSize
    let left: CGFloat
    let right: CGFloat
    let top: CGFloat
    let bottom: CGFloat

    func clampedCenter(_ center: CGPoint) -> CGPoint {
        CGPoint(x: min(right, max(left, center.x)), y: min(bottom, max(top, center.y)))
    }

    init(containerSize: CGSize, tabBarBottomInset: CGFloat, safeAreaBottom: CGFloat) {
        let margin = MiniPlayerLayout.margin
        let reportedBarHeight = tabBarBottomInset - safeAreaBottom
        let barHeight =
            reportedBarHeight <= MiniPlayerLayout.maximumTabBarHeight
            ? max(MiniPlayerLayout.minimumTabBarHeight, reportedBarHeight)
            : MiniPlayerLayout.minimumTabBarHeight
        let availableWidth = max(0, containerSize.width - margin * 2)
        let availableHeight = max(0, containerSize.height - barHeight - margin * 2)
        let width = min(MiniPlayerLayout.width, availableWidth, availableHeight * MiniPlayerLayout.aspectRatio)
        let height = width / MiniPlayerLayout.aspectRatio
        playerSize = CGSize(width: width, height: height)
        left = margin + width / 2
        right = max(left, containerSize.width - left)
        top = margin + height / 2
        bottom = max(top, containerSize.height - barHeight - margin - height / 2)
    }
}
