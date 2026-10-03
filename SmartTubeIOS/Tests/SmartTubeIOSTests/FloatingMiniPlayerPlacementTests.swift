import Foundation
import Testing

@testable import SmartTubeIOS

@Suite("Floating mini-player placement")
struct FloatingMiniPlayerPlacementTests {
    private let portrait = FloatingMiniPlayerBounds(
        containerSize: CGSize(width: 393, height: 760), tabBarBottomInset: 83, safeAreaBottom: 34)

    @Test("Small vertical drags stay where the window is dropped")
    func verticalDragIsRetained() {
        var placement = FloatingMiniPlayerPlacement()
        let original = placement.center(in: portrait)
        placement.finishDrag(CGSize(width: 0, height: -80), in: portrait)
        #expect(abs(placement.center(in: portrait).y - (original.y - 80)) < 0.001)
        placement.finishDrag(CGSize(width: 0, height: -40), in: portrait)
        placement.finishDrag(CGSize(width: 0, height: 25), in: portrait)
        #expect(abs(placement.center(in: portrait).y - (original.y - 95)) < 0.001)
    }

    @Test("Changing sides preserves vertical placement")
    func horizontalDockingKeepsHeight() {
        var placement = FloatingMiniPlayerPlacement()
        placement.finishDrag(CGSize(width: 0, height: -160), in: portrait)
        let height = placement.center(in: portrait).y
        placement.finishDrag(CGSize(width: -300, height: 0), in: portrait)
        #expect(!placement.dockRight)
        #expect(placement.center(in: portrait).x == portrait.left)
        #expect(abs(placement.center(in: portrait).y - height) < 0.001)
        placement.finishDrag(CGSize(width: 300, height: 0), in: portrait)
        #expect(placement.dockRight)
        #expect(placement.center(in: portrait).x == portrait.right)
        #expect(abs(placement.center(in: portrait).y - height) < 0.001)
    }

    @Test("An interrupted docking animation can drop from its current visible position")
    func dropFromUndockedPosition() {
        var placement = FloatingMiniPlayerPlacement()
        let visibleCenter = CGPoint(x: (portrait.left + portrait.right) / 2 - 10, y: portrait.top + 150)
        placement.finishDrag(at: visibleCenter, in: portrait)
        let settled = placement.center(in: portrait)
        #expect(settled.x == portrait.left)
        #expect(abs(settled.y - visibleCenter.y) < 0.001)
    }

    @Test("A free drag center is clamped without snapping while the finger is down")
    func liveCenterIsNotDocked() {
        let center = CGPoint(x: (portrait.left + portrait.right) / 2, y: portrait.top + 120)
        #expect(portrait.clampedCenter(center) == center)
        #expect(portrait.clampedCenter(CGPoint(x: -100, y: 10_000)) == CGPoint(x: portrait.left, y: portrait.bottom))
    }

    @Test("Dragging beyond the container clamps the window to its edges")
    func excessiveDragStaysInside() {
        var placement = FloatingMiniPlayerPlacement()
        let topLeft = placement.center(in: portrait, translation: CGSize(width: -10_000, height: -10_000))
        #expect(topLeft == CGPoint(x: portrait.left, y: portrait.top))
        placement.finishDrag(CGSize(width: -10_000, height: -10_000), in: portrait)
        #expect(placement.verticalFraction == 0)
        placement.finishDrag(CGSize(width: 10_000, height: 10_000), in: portrait)
        #expect(placement.center(in: portrait) == CGPoint(x: portrait.right, y: portrait.bottom))
        #expect(placement.verticalFraction == 1)
    }

    @Test("A stale full-screen inset cannot remove vertical travel")
    func oversizedInsetIsIgnored() {
        let bounds = FloatingMiniPlayerBounds(
            containerSize: CGSize(width: 393, height: 760), tabBarBottomInset: 760, safeAreaBottom: 34)
        #expect(bounds.bottom > bounds.top)
        #expect(bounds.bottom == portrait.bottom)
        #expect(bounds.bottom + bounds.playerSize.height / 2 + MiniPlayerLayout.margin == 711)
    }

    @Test("Rotation keeps the relative height within the new bounds")
    func rotationRetainsRelativeHeight() {
        var placement = FloatingMiniPlayerPlacement()
        placement.finishDrag(CGSize(width: 0, height: -(portrait.bottom - portrait.top) / 2), in: portrait)
        let landscape = FloatingMiniPlayerBounds(
            containerSize: CGSize(width: 760, height: 320), tabBarBottomInset: 49, safeAreaBottom: 0)
        let center = placement.center(in: landscape)
        #expect(abs(center.y - (landscape.top + landscape.bottom) / 2) < 0.001)
        #expect(center.x == landscape.right)
        #expect(center.y >= landscape.top && center.y <= landscape.bottom)
    }

    @Test("Short containers shrink the window without changing its aspect ratio")
    func smallContainerHasFinitePlacement() {
        let bounds = FloatingMiniPlayerBounds(
            containerSize: CGSize(width: 320, height: 160), tabBarBottomInset: 49, safeAreaBottom: 0)
        #expect(bounds.playerSize.width < MiniPlayerLayout.width)
        #expect(abs(bounds.playerSize.width / bounds.playerSize.height - MiniPlayerLayout.aspectRatio) < 0.001)
        #expect(bounds.top + bounds.playerSize.height / 2 <= 160 - 49 - MiniPlayerLayout.margin)
        var placement = FloatingMiniPlayerPlacement()
        placement.finishDrag(CGSize(width: -100, height: -100), in: bounds)
        #expect(placement.verticalFraction.isFinite)
        #expect(placement.center(in: bounds).y.isFinite)
    }
}
