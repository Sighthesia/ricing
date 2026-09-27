import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/WallpaperReveal.js" as Reveal

// Wallpaper reveal: the circle geometry is pure JS so it is verified directly,
// and the reveal component is checked for the surface it hands to the mask.
Item {
    id: root
    width: 400; height: 240

    Lazer.WallpaperReveal {
        id: reveal
        anchors.fill: parent
        source: ""
        origin: Qt.point(40, 200)
        radius: 0

        // Reach the internals the way the renderer does: the masked result and
        // the mask container the host never touches. OpacityMask owns extra
        // helper nodes, so it is found by capability rather than by index.
        readonly property var revealMask: {
            for (var i = 0; i < children.length; i++) {
                if (children[i].maskSource !== undefined)
                    return children[i]
            }
            return null
        }
        readonly property var maskSource: revealMask ? revealMask.maskSource : null
    }

    TestCase {
        name: "WallpaperReveal"
        when: windowShown
        visible: true

        function test_coverRadiusReachesTheFarthestCorner() {
            // Centre origin: half-diagonal.
            var half = Math.sqrt(Math.pow(200, 2) + Math.pow(120, 2))
            compare(Reveal.coverRadius(200, 120, 400, 240), half)
            // Corner origin: the whole diagonal.
            compare(Reveal.coverRadius(0, 0, 400, 240), Math.sqrt(Math.pow(400, 2) + Math.pow(240, 2)))
            // Edge origin: the far side, plus half the short side.
            compare(Reveal.coverRadius(0, 120, 400, 240), Math.sqrt(Math.pow(400, 2) + Math.pow(120, 2)))
            // The radius must always cover the surface, whatever the origin.
            var corners = [[0, 0], [400, 0], [0, 240], [400, 240], [200, 120], [12, 7]]
            for (var i = 0; i < corners.length; i++) {
                var radius = Reveal.coverRadius(corners[i][0], corners[i][1], 400, 240)
                verify(radius >= 200 && radius >= 120, "radius must span the surface")
            }
        }

        function test_coverRadiusClampsDegenerateInput() {
            compare(Reveal.coverRadius(10, 10, 0, 240), 0)
            compare(Reveal.coverRadius(10, 10, 400, 0), 0)
            // Out-of-surface origins clamp to the surface instead of growing.
            compare(Reveal.coverRadius(-500, -500, 400, 240), Reveal.coverRadius(0, 0, 400, 240))
            compare(Reveal.coverRadius(9999, 9999, 400, 240), Reveal.coverRadius(400, 240, 400, 240))
        }

        function test_localOriginMapsGlobalPointOntoItsScreen() {
            // Primary screen at the origin.
            var local = Reveal.localOrigin(120, 60, 0, 0, 1920, 1080)
            compare(local.x, 120)
            compare(local.y, 60)
            // A second screen placed to the right gets its own local point.
            var right = Reveal.localOrigin(2120, 60, 1920, 0, 1920, 1080)
            compare(right.x, 200)
            compare(right.y, 60)
            // Edges and corners of the screen count as inside.
            compare(Reveal.localOrigin(0, 0, 0, 0, 1920, 1080).x, 0)
            compare(Reveal.localOrigin(1920, 1080, 0, 0, 1920, 1080).y, 1080)
        }

        function test_localOriginRejectsPointsFromOtherScreens() {
            // Off this screen entirely: the caller falls back to the centre.
            compare(Reveal.localOrigin(2400, 100, 0, 0, 1920, 1080), null)
            compare(Reveal.localOrigin(100, 1400, 0, 0, 1920, 1080), null)
            compare(Reveal.localOrigin(-10, 100, 0, 0, 1920, 1080), null)
            compare(Reveal.localOrigin(100, 100, 0, 0, 0, 0), null)
        }

        function test_revealIsIdleUntilItHasBothPixelsAndRadius() {
            compare(reveal.coverRadius, Reveal.coverRadius(40, 200, 400, 240))
            // No radius means the mask result stays hidden and nothing is drawn
            // over the settled wallpaper.
            verify(!reveal.revealMask.visible)
            compare(reveal.revealMask.source.status, Image.Null)
            reveal.source = "file:///tmp/does-not-exist.png"
            verify(!reveal.revealMask.visible)
            reveal.radius = 30
            // A missing file must not look like a decoded wallpaper.
            verify(reveal.revealMask.visible)
            compare(reveal.imageReady, false)
            compare(reveal.imageFailed, true)
            reveal.radius = 0
            verify(!reveal.revealMask.visible)
        }

        function test_revealDecodesSynchronouslySoTheCircleNeverOpensEarly() {
            // The host starts growing the circle right after assigning the
            // source, so the pixels have to exist by then; an async image would
            // open on an empty circle and re-decode at the handover.
            compare(reveal.revealMask.source.asynchronous, false)
            compare(reveal.revealMask.maskSource.width, 400)
            compare(reveal.revealMask.maskSource.height, 240)
        }
    }
}
