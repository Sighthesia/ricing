import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/ScreenCornerMask.js" as Mask

// Fake screen-corner bezel: the wedge math is pure JS so it is verified
// directly, and the mask component is checked for the four corner boxes it
// hands to the rasterizer.
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

    // Stands in for the bar: a host that paints only the corners it covers, in
    // a one-strip-tall window, and so passes the real screen extent for clamping.
    Lazer.ScreenCornerMask {
        id: partialMask
        width: 200; height: 48
        screenWidth: 1645; screenHeight: 1028
        radius: 16
        corners: Mask.TOP_LEFT | Mask.BOTTOM_RIGHT
    }

    // The two real hosts, bound exactly as TopBar.qml and ScreenRoundedCorners
    // bind them, so the split is checked against the shipped configuration and
    // not only against the pure-JS masks.
    Lazer.ScreenCornerMask {
        id: barHost
        width: 200; height: 48
        screenWidth: 1645; screenHeight: 1028
        radius: 16
        corners: Mask.barCornerMask("top", false)
    }

    Lazer.ScreenCornerMask {
        id: bezelHost
        anchors.fill: parent
        radius: 16
        corners: Mask.barFreeCornerMask("top", false)
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

        function test_cornerBitsMapOneToOne() {
            // Every corner has its own bit, and all four cover the full mask.
            compare(Mask.TOP_LEFT, 1)
            compare(Mask.TOP_RIGHT, 2)
            compare(Mask.BOTTOM_RIGHT, 4)
            compare(Mask.BOTTOM_LEFT, 8)
            compare(Mask.ALL_CORNERS, 15)
            compare(Mask.cornerBit(0), Mask.TOP_LEFT)
            compare(Mask.cornerBit(1), Mask.TOP_RIGHT)
            compare(Mask.cornerBit(2), Mask.BOTTOM_RIGHT)
            compare(Mask.cornerBit(3), Mask.BOTTOM_LEFT)
            // Out-of-range indices wrap rather than shifting past the mask.
            compare(Mask.cornerBit(4), Mask.TOP_LEFT)
            compare(Mask.cornerBit(-1), Mask.BOTTOM_LEFT)
        }

        function test_cornersForMaskKeepsCornerOrder() {
            compare(Mask.cornersForMask(Mask.ALL_CORNERS), [0, 1, 2, 3])
            compare(Mask.cornersForMask(Mask.TOP_LEFT | Mask.BOTTOM_RIGHT), [0, 2])
            compare(Mask.cornersForMask(Mask.BOTTOM_LEFT), [3])
            compare(Mask.cornersForMask(0), [])
            compare(Mask.cornersForMask(undefined), [])
        }

        function test_barAndBezelNeverClaimTheSameCorner() {
            // Top bar, attached: the bar takes the top pair.
            compare(Mask.barCornerMask("top", false), Mask.TOP_LEFT | Mask.TOP_RIGHT)
            compare(Mask.barFreeCornerMask("top", false), Mask.BOTTOM_LEFT | Mask.BOTTOM_RIGHT)
            // Bottom bar, attached: the ownership swaps.
            compare(Mask.barCornerMask("bottom", false), Mask.BOTTOM_LEFT | Mask.BOTTOM_RIGHT)
            compare(Mask.barFreeCornerMask("bottom", false), Mask.TOP_LEFT | Mask.TOP_RIGHT)
            // A floating bar is inset by its margin and reaches no corner, so
            // the bezel surface keeps all four.
            compare(Mask.barCornerMask("top", true), 0)
            compare(Mask.barFreeCornerMask("top", true), Mask.ALL_CORNERS)
            // The two masks must partition the corners for every placement, or
            // a corner is either painted twice or not at all.
            for (var i = 0; i < 2; i++) {
                for (var j = 0; j < 2; j++) {
                    var position = i === 0 ? "top" : "bottom"
                    var floating = j === 0
                    var owned = Mask.barCornerMask(position, floating)
                    var shared = Mask.barFreeCornerMask(position, floating)
                    compare(owned & shared, 0, "a corner is claimed twice")
                    compare(owned | shared, Mask.ALL_CORNERS, "a corner is claimed by nobody")
                }
            }
        }

        function test_cornerOriginHangsTheWedgePastTheScreenEdge() {
            // The box overhangs the screen by the bleed on the two sides that
            // meet at its corner, so the arc is tangent to the screen edge and
            // the outermost pixel row and column stay solid.
            compare(Mask.cornerOrigin(0, 18, 2, 200, 100), [-2, -2])
            compare(Mask.cornerOrigin(1, 18, 2, 200, 100), [182, -2])
            compare(Mask.cornerOrigin(2, 18, 2, 200, 100), [182, 82])
            compare(Mask.cornerOrigin(3, 18, 2, 200, 100), [-2, 82])
            // Out-of-range indices wrap instead of producing NaN geometry.
            compare(Mask.cornerOrigin(4, 18, 2, 200, 100), [-2, -2])
            compare(Mask.cornerOrigin(-1, 18, 2, 200, 100), [-2, 82])
            // Degenerate screen size collapses to the origin instead of
            // pushing a wedge off-surface; clampRadius keeps this unreachable
            // from the component.
            compare(Mask.cornerOrigin(2, 18, 2, 8, 4), [0, 0])
        }

        function test_cornerPathIsAClosedExactArcCommandList() {
            var r = 16
            var b = 2
            // The arc is a real SVG arc at the requested radius rather than a
            // Bezier stand-in, so its radius survives the round trip exactly.
            // Top-left: start at the box corner, hug the top edge, arc down to
            // the left edge, close. The arc travels counter-clockwise so it
            // bulges towards the screen corner.
            compare(Mask.cornerPath(r, b, 0), [[Mask.MOVE, 0, 0], [Mask.LINE, 18, 2],
                [Mask.ARC, 16, 16, 0, 0, 0, 2, 18], [Mask.CLOSE]])
            // Top-right: mirrored horizontally, sweep flipped.
            compare(Mask.cornerPath(r, b, 1), [[Mask.MOVE, 18, 0], [Mask.LINE, 2, 2],
                [Mask.ARC, 16, 16, 0, 0, 1, 18, 18], [Mask.CLOSE]])
            // Bottom-right: both edges mirrored.
            compare(Mask.cornerPath(r, b, 2), [[Mask.MOVE, 18, 18], [Mask.LINE, 2, 18],
                [Mask.ARC, 16, 16, 0, 0, 0, 18, 2], [Mask.CLOSE]])
            // Bottom-left: mirrored vertically.
            compare(Mask.cornerPath(r, b, 3), [[Mask.MOVE, 0, 18], [Mask.LINE, 18, 18],
                [Mask.ARC, 16, 16, 0, 0, 1, 2, 2], [Mask.CLOSE]])
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
                        // The start corner and both arc endpoints ride the box
                        // edges, so they must sit inside the box.
                        if (c === 0 || c === 1 || p === 6) {
                            verify(value >= -0.001 && value <= size + 0.001,
                                "corner " + i + " point " + p + " outside the box")
                        }
                    }
                }
            }
            compare(Mask.cornerPath(0, 2, 0).length, 0)
        }

        function test_cornerSvgWrapsThePathInASizedDocument() {
            compare(Mask.cornerSvg(16, 2, 0, "#000000"),
                '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"'
                + ' viewBox="0 0 18 18"><path d="M0,0L18,2A16,16 0 0 0 2,18Z"'
                + ' fill="#000000"/></svg>')
            // The colour reaches the fill, and a degenerate wedge has no document.
            verify(Mask.cornerSvg(16, 2, 1, "#ff8800").indexOf('fill="#ff8800"') >= 0)
            compare(Mask.cornerSvg(0, 2, 0, "#000000"), "")
        }

        function test_maskPutsOneWedgeInEachScreenCorner() {
            compare(Mask.CORNER_COUNT, 4)
            compare(mask.effectiveRadius, 16)
            compare(mask.boxSize, 18)
            var items = cornerItems(mask)
            compare(items.length, 4)
            var expectedX = [-2, 182, 182, -2]
            var expectedY = [-2, -2, 82, 82]
            for (var i = 0; i < items.length; i++) {
                compare(items[i].width, 18)
                compare(items[i].height, 18)
                compare(items[i].x, expectedX[i])
                compare(items[i].y, expectedY[i])
                verify(items[i].visible, "corner " + i + " must paint")
                // Wedges are rasterized from an inline SVG, never cached in a
                // scene-graph canvas that a surface remap would leave blank.
                verify(String(items[i].source).indexOf("data:image/svg+xml") === 0,
                    "corner " + i + " must come from an inline SVG")
                compare(items[i].renderTarget, undefined)
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

        function test_onlySelectedCornersGetAWedge() {
            // The bar paints the corners it covers and the shared bezel surface
            // paints the rest, so a host must not emit wedges for corners it
            // was not given: a wedge the compositor then covers is invisible
            // work, and one both surfaces claim flickers.
            var items = cornerItems(partialMask)
            compare(items.length, 2, "only the selected corners get a wedge")
            // Top-left sits on the host's own top-left, bottom-right on its
            // bottom-right, so the geometry is still relative to this item.
            compare(items[0].x, -2)
            compare(items[0].y, -2)
            compare(items[1].x, 200 - 18)
            compare(items[1].y, 48 - 18)
            // The clamp reads the screen, not this window, so the radius is
            // identical to the one the bezel surface uses for the other edge.
            compare(partialMask.effectiveRadius, mask.effectiveRadius)
            for (var i = 0; i < items.length; i++)
                verify(items[i].visible, "selected corner " + i + " must paint")
        }

        function test_radiusClampsAgainstTheScreenNotTheHost() {
            // A one-strip-tall host must not cap the radius at half its own
            // height, or the two surfaces would disagree about the same bezel.
            compare(partialMask.height, 48)
            compare(partialMask.effectiveRadius, 16, "a 48px host must not clamp a 16px radius")
            // A radius past half the host height still survives, because the
            // clamp reads the screen extent the host passed in.
            partialMask.radius = 40
            compare(partialMask.effectiveRadius, 40)
            partialMask.radius = 16
        }

        // Screen corner each wedge actually lands on, read from its geometry
        // rather than from the index that created it.
        function cornerNamesAt(target) {
            var names = []
            var items = cornerItems(target)
            for (var i = 0; i < items.length; i++) {
                var w = items[i]
                if (w.x <= 0 && w.y <= 0) names.push("top-left")
                else if (w.x > 0 && w.y <= 0) names.push("top-right")
                else if (w.x > 0 && w.y > 0) names.push("bottom-right")
                else names.push("bottom-left")
            }
            return names
        }

        function test_theTwoHostsCoverAllFourCornersExactlyOnce() {
            // This is the regression guard for the reported bug: the bar and the
            // bezel are separate overlay-layer surfaces, so a corner painted by
            // both ends up showing whichever the compositor put on top, and a
            // corner painted by neither shows the desktop through.
            var barCovers = cornerNamesAt(barHost)
            var bezelCovers = cornerNamesAt(bezelHost)
            compare(barCovers, ["top-left", "top-right"], "an attached top bar covers the top pair")
            compare(bezelCovers, ["bottom-right", "bottom-left"], "the bezel surface keeps the bottom pair")

            var all = barCovers.concat(bezelCovers)
            compare(all.length, 4, "all four corners must be painted")
            for (var i = 0; i < Mask.CORNER_COUNT; i++) {
                var name = cornerNamesAt(mask)[i]
                compare(all.filter(function(c) { return c === name }).length, 1,
                    "corner " + name + " must be painted exactly once")
            }
        }

        function test_bothHostsResolveTheSameRadius() {
            // The hosts paint opposite edges of one bezel, so a radius
            // disagreement would show as a corner that does not match its
            // opposite.
            compare(barHost.effectiveRadius, bezelHost.effectiveRadius)
            compare(barHost.effectiveRadius, 16)
        }

        function test_geometryAndPaintChangesRebuildTheWedgeSource() {            var wedge = cornerItems(mask)[0]
            var before = String(wedge.source)
            // A new radius and a new colour both change the rasterized document,
            // which is what puts fresh pixels in the wedge after a remap.
            mask.radius = 20
            wait(50)
            compare(mask.effectiveRadius, 20)
            compare(wedge.width, 22)
            var afterGeometry = String(wedge.source)
            verify(afterGeometry !== before, "radius change must re-rasterize the wedge")
            verify(afterGeometry.indexOf("A20%2C20") >= 0, "arc must follow the radius")
            mask.maskColor = "#101112"
            wait(50)
            var afterColor = String(wedge.source)
            verify(afterColor !== afterGeometry, "maskColor change must re-rasterize the wedge")
            verify(afterColor.indexOf(encodeURIComponent("#101112")) >= 0,
                "the fill must carry the bezel colour")
        }

        // Reset shared state here so a failed case cannot leak into the next.
        function cleanup() {
            mask.maskColor = "#000000"
            mask.radius = 16
        }
    }
}
