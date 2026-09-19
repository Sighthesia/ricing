import QtQuick
import QtTest
import "../../modules/lock"

Item {
    width: 320
    height: 240

    LockBackdrop {
        id: backdrop
        anchors.fill: parent
        snapshotSource: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><rect width="320" height="240" fill="red"/></svg>')
        wallpaperSource: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><rect width="320" height="240" fill="blue"/></svg>')
    }

    Component {
        id: coldBackdrop
        LockBackdrop {
            width: 320
            height: 240
        }
    }

    TestCase {
        name: "LockBackdropPixels"
        when: windowShown

        function test_localSnapshotReadyBeforeFirstFrame() {
            var item = createTemporaryObject(coldBackdrop, backdrop.parent, {
                snapshotSource: Qt.resolvedUrl("../../modules/bar/icons/wifi.svg")
            })
            verify(item !== null)
            verify(item.snapshotReady, "local screenshot must be decoded before the first frame")
            verify(item.imagesReady === false)
        }

        function isScreenshotRed(c) { return c.r > 0.9 && c.g < 0.1 && c.b < 0.1 }
        function isWallpaperBlue(c) { return c.b > 0.9 && c.r < 0.1 && c.g < 0.1 }

        // Pixels that are neither screenshot-red nor wallpaper-blue carry
        // wave bands; their count measures how much band is on screen.
        function bandArea(image) {
            var bands = 0
            for (var x = 8; x < 320; x += 8)
                for (var y = 0; y < 240; y += 8) {
                    var c = image.pixel(x, y)
                    var isRed = c.r > 0.9 && c.g < 0.1 && c.b < 0.1
                    var isBlue = c.b > 0.9 && c.r < 0.1 && c.g < 0.1
                    if (!isRed && !isBlue)
                        ++bands
                }
            return bands
        }

        function test_twoPhaseReveal() {
            tryCompare(backdrop, "imagesReady", true)
            // Phase one: bands sweep the screenshot alone, no wallpaper yet.
            backdrop.progress = 0.25
            wait(120)
            var phaseOne = grabImage(backdrop)
            verify(bandArea(phaseOne) > 300, "bands must dominate phase one")
            verify(!isWallpaperBlue(phaseOne.pixel(160, 230)), "wallpaper waits during phase one")
            // Handoff: bands at rest wash the frame pink edge to edge.
            backdrop.progress = 0.5
            wait(120)
            var handoff = grabImage(backdrop)
            compare(handoff.pixel(160, 10), "#75293f", "pink wash at handoff")
            var handoffBottom = handoff.pixel(160, 230)
            verify(!isScreenshotRed(handoffBottom) && !isWallpaperBlue(handoffBottom),
                "full pink wash at handoff")
            // Phase two: wallpaper sweeps over the pink, then settles clean.
            backdrop.progress = 0.75
            wait(120)
            var phaseTwo = grabImage(backdrop)
            compare(phaseTwo.pixel(160, 230), "#0000ff", "wallpaper leads phase two")
            backdrop.progress = 1
            wait(120)
            compare(bandArea(grabImage(backdrop)), 0, "no bands left at rest")
        }

        function test_curtainBothDirections() {
            tryCompare(backdrop, "imagesReady", true)
            var stages = [0, 0.5, 1, 0.5, 0]
            for (var i = 0; i < stages.length; ++i) {
                backdrop.progress = stages[i]
                wait(80)
                var image = grabImage(backdrop)
                // Mid-sweep the settled bands wash the frame pink; the open
                // and settled frames stay screenshot/wallpaper pure.
                if (stages[i] === 0.5) {
                    compare(image.pixel(160, 10), "#75293f", "top at 0.5")
                    var bottomMid = image.pixel(160, 230)
                    verify(!isScreenshotRed(bottomMid) && !isWallpaperBlue(bottomMid), "bottom bands at 0.5")
                } else {
                    compare(image.pixel(160, 10), stages[i] === 1 ? "#0000ff" : "#ff0000", "top at " + stages[i])
                    compare(image.pixel(160, 230), stages[i] === 1 ? "#0000ff" : "#ff0000", "bottom at " + stages[i])
                }
            }
        }
    }
}
