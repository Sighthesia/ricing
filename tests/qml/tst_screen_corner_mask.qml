import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/ScreenCornerMask.js" as Mask

// Fake screen-corner bezel: the wedge math is pure JS so it is verified
// directly, and the mask component is checked for the four corner boxes it
// hands to the Shapes module.
Item {
    id: root
    width: 200; height: 100

    Lazer.ScreenCornerMask {
        id: mask
        anchors.fill: parent
        radius: 16
    }

    Lazer.ScreenCornerMask {
        id: clampedMask
        width: 40; height: 20
        radius: 64
    }

    Lazer.ScreenCornerMask {
        id: disabledMask
        width: 40; height: 20
        radius: 0
    }

    TestCase {
        name: "ScreenCornerMask"
        when: windowShown
        visible: true

        // Locate the mask's Repeater without exposing test-only properties.
        function cornerItems(target) {
            var repeater = null
            for (var i = 0; i < target.children.length; i++) {
                var child = target.children[i]
                if (String(child).indexOf("Repeater") >= 0)
                    repeater = child
            }
            verify(repeater !== null, "corner Repeater missing")
            var items = []
            for (var j = 0; j < repeater.count; j++)
                items.push(repeater.itemAt(j))
            return items
        }

        function test_controlOffsetIsExactQuarterCircle() {
            var r = 16
            var expected = r * (1 - Math.PI / 6)
            compare(Mask.controlOffset(r), expected)
            // The handle sits inside the arc's bounding square.
            verify(Mask.controlOffset(r) > 0 && Mask.controlOffset(r) < r)
            compare(Mask.controlOffset(0), 0)
            compare(Mask.controlOffset(-4), 0)
            compare(Mask.controlOffset(NaN), 0)
        }

        function test_clampRadiusStaysInsideShorterEdge() {
            compare(Mask.clampRadius(16, 200, 100), 16)
            compare(Mask.clampRadius(64, 40, 20), 10)
            compare(Mask.clampRadius(0, 200, 100), 0)
            compare(Mask.clampRadius(-8, 200, 100), 0)
            compare(Mask.clampRadius(16, 0, 100), 0)
            compare(Mask.clampRadius(16, 200, 100), 16)
        }

        function test_cornerOriginAnchorsWedgesToScreenCorners() {
            compare(Mask.cornerOrigin(0, 16, 200, 100), [0, 0])
            compare(Mask.cornerOrigin(1, 16, 200, 100), [184, 0])
            compare(Mask.cornerOrigin(2, 16, 200, 100), [184, 84])
            compare(Mask.cornerOrigin(3, 16, 200, 100), [0, 84])
            // Out-of-range indices wrap instead of producing NaN geometry.
            compare(Mask.cornerOrigin(4, 16, 200, 100), [0, 0])
            compare(Mask.cornerOrigin(-1, 16, 200, 100), [0, 84])
            // Degenerate screen size collapses to the origin instead of
            // pushing a wedge off-surface; clampRadius keeps this unreachable
            // from the component.
            compare(Mask.cornerOrigin(2, 16, 8, 4), [0, 0])
        }

        function test_cornerPathMatchesMirroredArc() {
            var r = 16
            var k = r * (1 - Math.PI / 6)
            compare(Mask.cornerPath(r, 0), "M0,0 L16,0 C" + k + ",0 0," + k + " 0,16 Z")
            compare(Mask.cornerPath(r, 1), "M16,0 L0,0 C" + (r - k) + ",0 16," + k + " 16,16 Z")
            compare(Mask.cornerPath(r, 2), "M16,16 L0,16 C" + (r - k) + ",16 16," + (r - k) + " 16,0 Z")
            compare(Mask.cornerPath(r, 3), "M0,16 L16,16 C" + k + ",16 0," + (r - k) + " 0,0 Z")
            // Every wedge path is closed and starts on its screen corner.
            for (var i = 0; i < Mask.CORNER_COUNT; i++) {
                var path = Mask.cornerPath(r, i)
                verify(path.indexOf("M") === 0, "corner " + i + " must open with a move")
                verify(path.slice(-2) === " Z", "corner " + i + " must be closed")
                verify(path.indexOf("NaN") < 0, "corner " + i + " has NaN geometry")
            }
            compare(Mask.cornerPath(0, 0), "")
        }

        function test_maskPutsOneWedgeInEachScreenCorner() {
            compare(Mask.CORNER_COUNT, 4)
            compare(mask.effectiveRadius, 16)
            var items = cornerItems(mask)
            compare(items.length, 4)
            var expectedX = [0, 184, 184, 0]
            var expectedY = [0, 0, 84, 84]
            for (var i = 0; i < items.length; i++) {
                compare(items[i].width, 16)
                compare(items[i].height, 16)
                compare(items[i].x, expectedX[i])
                compare(items[i].y, expectedY[i])
                verify(items[i].visible, "corner " + i + " must paint")
            }
        }

        function test_radiusFollowsSurfaceAndClampsOnShortScreens() {
            mask.radius = 24
            compare(mask.effectiveRadius, 24)
            var items = cornerItems(mask)
            compare(items[2].x, 200 - 24)
            compare(items[2].y, 100 - 24)

            compare(clampedMask.effectiveRadius, 10)
            var clamped = cornerItems(clampedMask)
            compare(clamped.length, 4)
            for (var i = 0; i < clamped.length; i++) {
                compare(clamped[i].width, 10)
                compare(clamped[i].height, 10)
                verify(clamped[i].visible, "clamped corner " + i + " must paint")
            }
            // Radius 0 means no bezel at all, so the host can skip the surface.
            compare(disabledMask.effectiveRadius, 0)
            var hidden = cornerItems(disabledMask)
            for (var j = 0; j < hidden.length; j++)
                verify(!hidden[j].visible, "radius 0 must hide corner " + j)
        }
    }
}
