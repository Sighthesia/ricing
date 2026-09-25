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

        function test_maskTrailsBands() {
            tryCompare(backdrop, "imagesReady", true)
            compare(backdrop.maskProgress, 0)
            backdrop.progress = 0.3
            compare(backdrop.maskProgress, 0)
            backdrop.progress = 0.65
            verify(Math.abs(backdrop.maskProgress - 0.5) < 0.001)
            backdrop.progress = 1
            compare(backdrop.maskProgress, 1)
            backdrop.progress = 0
        }

        function test_wallpaperUnveiledAtBandTail() {
            tryCompare(backdrop, "imagesReady", true)
            // Mid-sweep three zones read top to bottom: screenshot ahead,
            // pink bands, wallpaper behind where the bands swept past.
            backdrop.progress = 0.5
            wait(120)
            var sweeping = grabImage(backdrop)
            compare(sweeping.pixel(160, 10), "#ff0000", "screenshot ahead")
            var midSweep = sweeping.pixel(160, 120)
            verify(!isScreenshotRed(midSweep) && !isWallpaperBlue(midSweep), "pink bands")
            compare(sweeping.pixel(160, 230), "#0000ff", "wallpaper behind")
            // Open and settled frames stay pure.
            backdrop.progress = 0
            wait(120)
            var open = grabImage(backdrop)
            compare(bandArea(open), 0, "no bands before the sweep")
            backdrop.progress = 1
            wait(120)
            var settled = grabImage(backdrop)
            compare(bandArea(settled), 0, "no bands left at rest")
            compare(settled.pixel(160, 10), "#0000ff", "settled wallpaper")
        }

        function test_curtainBothDirections() {
            tryCompare(backdrop, "imagesReady", true)
            var stages = [0, 0.5, 1, 0.5, 0]
            for (var i = 0; i < stages.length; ++i) {
                backdrop.progress = stages[i]
                wait(80)
                var image = grabImage(backdrop)
                if (stages[i] === 0.5) {
                    compare(image.pixel(160, 10), "#ff0000", "top at 0.5")
                    var mid = image.pixel(160, 120)
                    verify(!isScreenshotRed(mid) && !isWallpaperBlue(mid), "bands at 0.5")
                    compare(image.pixel(160, 230), "#0000ff", "bottom at 0.5")
                } else {
                    compare(image.pixel(160, 10), stages[i] === 1 ? "#0000ff" : "#ff0000", "top at " + stages[i])
                    compare(image.pixel(160, 230), stages[i] === 1 ? "#0000ff" : "#ff0000", "bottom at " + stages[i])
                }
            }
        }
    }
}
