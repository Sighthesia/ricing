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

        function setStage(bands, body) {
            backdrop.bandsProgress = bands
            backdrop.bodyProgress = body
            wait(120)
            return grabImage(backdrop)
        }

        function test_bandsSweepBeforeBody() {
            tryCompare(backdrop, "imagesReady", true)
            // Bands sweep the screenshot while the body waits below.
            var sweeping = setStage(0.5, 0)
            verify(bandArea(sweeping) > 300, "bands must dominate before the body")
            verify(!isWallpaperBlue(sweeping.pixel(160, 230)), "body waits below")
            // Bands at rest wash the frame; the open frame stays screenshot.
            var wash = setStage(1, 0)
            compare(wash.pixel(160, 10), "#75293f", "pink wash at rest")
            // Body fades in over the wash, then settles clean.
            var covering = setStage(1, 0.5)
            var coveringBottom = covering.pixel(160, 230)
            verify(!isScreenshotRed(coveringBottom) && !isWallpaperBlue(coveringBottom),
                "body blends over the wash")
            var settled = setStage(1, 1)
            compare(bandArea(settled), 0, "no bands left at rest")
            var open = setStage(0, 0)
            compare(bandArea(open), 0, "no bands before the sweep")
        }

        function test_curtainBothDirections() {
            tryCompare(backdrop, "imagesReady", true)
            var stages = [[0, 0], [1, 0], [1, 1], [1, 0], [0, 0]]
            for (var i = 0; i < stages.length; ++i) {
                var image = setStage(stages[i][0], stages[i][1])
                var tag = "bands=" + stages[i][0] + " body=" + stages[i][1]
                if (stages[i][0] === 1 && stages[i][1] === 0) {
                    compare(image.pixel(160, 10), "#75293f", "wash " + tag)
                } else if (stages[i][1] === 1) {
                    compare(image.pixel(160, 10), "#0000ff", "top " + tag)
                    compare(image.pixel(160, 230), "#0000ff", "bottom " + tag)
                } else {
                    compare(image.pixel(160, 10), "#ff0000", "top " + tag)
                    compare(image.pixel(160, 230), "#ff0000", "bottom " + tag)
                }
            }
        }
    }
}
