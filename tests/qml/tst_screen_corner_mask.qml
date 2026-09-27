import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/ScreenCornerMask.js" as Mask

// Fake screen-corner bezel: the wedge math is pure JS so it is verified
// directly, and the mask component is checked for the four corner boxes it
// hands to the canvas.
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
            compare(Mask.controlOffset(r), r * (1 - Math.PI / 6))
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
        }

        function test_cornerBoxSizeAddsOffScreenBleed() {
            compare(Mask.cornerBoxSize(16, 2), 18)
            compare(Mask.cornerBoxSize(16, 0), 16)
            compare(Mask.cornerBoxSize(0, 2), 2)
            compare(Mask.cornerBoxSize(16, -4), 16)
        }

        function test_cornerOriginAnchorsWedgesToScreenCorners() {
            // Boxes overhang the screen by the bleed, so the far edges sit
            // exactly on the screen boundary.
            compare(Mask.cornerOrigin(0, 18, 200, 100), [0, 0])
            compare(Mask.cornerOrigin(1, 18, 200, 100), [182, 0])
            compare(Mask.cornerOrigin(2, 18, 200, 100), [182, 82])
            compare(Mask.cornerOrigin(3, 18, 200, 100), [0, 82])
            // Out-of-range indices wrap instead of producing NaN geometry.
            compare(Mask.cornerOrigin(4, 18, 200, 100), [0, 0])
            compare(Mask.cornerOrigin(-1, 18, 200, 100), [0, 82])
            // Degenerate screen size collapses to the origin instead of
            // pushing a wedge off-surface; clampRadius keeps this unreachable
            // from the component.
            compare(Mask.cornerOrigin(2, 18, 8, 4), [0, 0])
        }

        function test_cornerPathIsAClosedCurveCommandList() {
            var r = 16
            var b = 2
            var size = r + b
            var k = r * (1 - Math.PI / 6)
            // Bézier handle length from each tangent point, along the edge.
            var handle = r - k
            // Top-left: start at the box corner, hug the top edge, arc down to
            // the left edge, close.
            compare(Mask.cornerPath(r, b, 0), [[Mask.MOVE, 0, 0], [Mask.LINE, r, 0],
                [Mask.CURVE, k, 0, 0, k, 0, r], [Mask.CLOSE]])
            // Top-right: mirrored horizontally, tangent points move to the
            // right edge.
            compare(Mask.cornerPath(r, b, 1), [[Mask.MOVE, size, 0], [Mask.LINE, b, 0],
                [Mask.CURVE, b + handle, 0, size, k, size, r], [Mask.CLOSE]])
            // Bottom-right: both edges mirrored.
            compare(Mask.cornerPath(r, b, 2), [[Mask.MOVE, size, size], [Mask.LINE, b, size],
                [Mask.CURVE, b + handle, size, size, b + handle, size, b], [Mask.CLOSE]])
            // Bottom-left: mirrored vertically.
            compare(Mask.cornerPath(r, b, 3), [[Mask.MOVE, 0, size], [Mask.LINE, r, size],
                [Mask.CURVE, k, size, 0, b + handle, 0, b], [Mask.CLOSE]])
        }

        function test_cornerPathStaysInsideItsBoxWithoutNaN() {
            var size = 18
            for (var i = 0; i < Mask.CORNER_COUNT; i++) {
                var commands = Mask.cornerPath(16, 2, i)
                compare(commands.length, 4)
                compare(commands[0][0], Mask.MOVE)
                compare(commands[3][0], Mask.CLOSE)
                for (var c = 0; c < commands.length; c++) {
                    for (var p = 1; p < commands[c].length; p++) {
                        var value = commands[c][p]
                        verify(!isNaN(value), "corner " + i + " command " + c + " has NaN")
                        // Control handles may sit outside the box, but the
                        // anchor points and the arc must stay inside it.
                        if (c < 2) {
                            verify(value >= -0.001 && value <= size + 0.001,
                                "corner " + i + " anchor " + p + " outside the box")
                        }
                    }
                }
            }
            compare(Mask.cornerPath(0, 2, 0).length, 0)
        }

        function test_maskPutsOneWedgeInEachScreenCorner() {
            compare(Mask.CORNER_COUNT, 4)
            compare(mask.effectiveRadius, 16)
            compare(mask.boxSize, 18)
            var items = cornerItems(mask)
            compare(items.length, 4)
            var expectedX = [0, 182, 182, 0]
            var expectedY = [0, 0, 82, 82]
            for (var i = 0; i < items.length; i++) {
                compare(items[i].width, 18)
                compare(items[i].height, 18)
                compare(items[i].x, expectedX[i])
                compare(items[i].y, expectedY[i])
                verify(items[i].visible, "corner " + i + " must paint")
                // Wedges must not paint into a cached framebuffer.
                compare(items[i].renderTarget, Canvas.Image)
            }
        }

        function test_radiusFollowsSurfaceAndClampsOnShortScreens() {
            mask.radius = 24
            compare(mask.effectiveRadius, 24)
            compare(mask.boxSize, 26)
            var items = cornerItems(mask)
            compare(items[2].x, 200 - 26)
            compare(items[2].y, 100 - 26)

            compare(clampedMask.effectiveRadius, 10)
            compare(clampedMask.boxSize, 12)
            var clamped = cornerItems(clampedMask)
            compare(clamped.length, 4)
            for (var i = 0; i < clamped.length; i++) {
                compare(clamped[i].width, 12)
                compare(clamped[i].height, 12)
                verify(clamped[i].visible, "clamped corner " + i + " must paint")
            }
            // Radius 0 means no bezel at all, so the host can skip the surface.
            compare(disabledMask.effectiveRadius, 0)
            var hidden = cornerItems(disabledMask)
            for (var j = 0; j < hidden.length; j++)
                verify(!hidden[j].visible, "radius 0 must hide corner " + j)
        }

        function test_geometryAndPaintChangesRepaintTheCanvas() {
            var wedge = cornerItems(mask)[0]
            wait(50)
            var before = wedge.toDataURL()
            // A new radius resizes the box, a new colour asks for a repaint.
            mask.radius = 20
            wait(50)
            compare(mask.effectiveRadius, 20)
            compare(wedge.width, 22)
            var afterGeometry = wedge.toDataURL()
            verify(afterGeometry !== before, "radius change must repaint the wedge")
            mask.maskColor = "#101112"
            wait(50)
            var afterColor = wedge.toDataURL()
            verify(afterColor !== afterGeometry, "maskColor change must repaint the wedge")
        }

        // Reset shared state here so a failed case cannot leak into the next.
        function cleanup() {
            mask.maskColor = "#000000"
            mask.radius = 16
        }
    }
}
