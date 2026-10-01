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

    Component {
        id: lightBackdrop
        LockBackdrop {
            width: 320
            height: 240
            lightScheme: true
            snapshotSource: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><rect width="320" height="240" fill="red"/></svg>')
            wallpaperSource: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><rect width="320" height="240" fill="blue"/></svg>')
        }
    }

    Component {
        id: foregroundProbeBackdrop
        LockBackdrop {
            width: 320
            height: 240
            snapshotSource: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><rect width="320" height="240" fill="red"/></svg>')
            wallpaperSource: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><rect width="320" height="240" fill="blue"/></svg>')

            // Test markers share the wallpaper reveal clip with production content.
            Rectangle {
                width: 320
                height: 24
                color: "#00ff00"
            }
            Rectangle {
                y: 216
                width: 320
                height: 24
                color: "#00ff00"
            }
        }
    }

    // The session-start lock: no capture at all, only the wallpaper to unveil.
    Component {
        id: capturelessBackdrop
        LockBackdrop {
            width: 320
            height: 240
            captureExpected: false
            wallpaperSource: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><rect width="320" height="240" fill="blue"/></svg>')
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

        function isThemeDark(c) { return c.r < 0.2 && c.g < 0.2 && c.b < 0.2 }
        function isThemeLight(c) { return c.r > 0.8 && c.g > 0.8 && c.b > 0.8 }
        function isWallpaperBlue(c) { return c.b > 0.9 && c.r < 0.1 && c.g < 0.1 }
        function isScreenshotRed(c) { return c.r > 0.9 && c.g < 0.1 && c.b < 0.1 }

        // Pixels that are neither the pre-lock screenshot nor the wallpaper
        // carry wave bands; their count measures how much band is on screen.
        function bandArea(image) {
            var bands = 0
            for (var x = 8; x < 320; x += 8)
                for (var y = 0; y < 240; y += 8) {
                    var c = image.pixel(x, y)
                    if (!isScreenshotRed(c) && !isWallpaperBlue(c))
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
            // Mid-sweep three zones read top to bottom: the pre-lock screenshot
            // ahead, pink bands, wallpaper behind where the bands swept past.
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

        function test_foregroundContentUsesTheWallpaperRevealClip() {
            var item = createTemporaryObject(foregroundProbeBackdrop, backdrop.parent)
            verify(item !== null)
            tryCompare(item, "imagesReady", true)

            item.progress = 0
            wait(80)
            var closed = grabImage(item)
            verify(closed.pixel(160, 12) !== "#00ff00", "top content stays hidden")
            verify(closed.pixel(160, 228) !== "#00ff00", "bottom content stays hidden")

            item.progress = 0.5
            wait(120)
            var partial = grabImage(item)
            verify(partial.pixel(160, 12) !== "#00ff00", "top content follows the clip")
            compare(partial.pixel(160, 228), "#00ff00", "bottom content follows the clip")

            item.progress = 1
            wait(120)
            var open = grabImage(item)
            compare(open.pixel(160, 12), "#00ff00", "full content is revealed")
            compare(open.pixel(160, 228), "#00ff00", "bottom content remains revealed")
        }

        function test_curtainBothDirections() {
            tryCompare(backdrop, "imagesReady", true)
            var stages = [0, 0.5, 1, 0.5, 0]
            for (var i = 0; i < stages.length; ++i) {
                backdrop.progress = stages[i]
                wait(80)
                var image = grabImage(backdrop)
                if (stages[i] === 0.5) {
                    compare(image.pixel(160, 10), "#ff0000", "screenshot at 0.5")
                    var mid = image.pixel(160, 120)
                    verify(!isScreenshotRed(mid) && !isWallpaperBlue(mid), "bands at 0.5")
                    compare(image.pixel(160, 230), "#0000ff", "bottom at 0.5")
                } else {
                    if (stages[i] === 1) {
                        compare(image.pixel(160, 10), "#0000ff", "top at 1")
                        compare(image.pixel(160, 230), "#0000ff", "bottom at 1")
                    } else {
                        compare(image.pixel(160, 10), "#ff0000", "top screenshot at 0")
                        compare(image.pixel(160, 230), "#ff0000", "bottom screenshot at 0")
                    }
                }
            }
        }

        function test_themedFloorOnlyShowsWithoutAScreenshot() {
            var item = createTemporaryObject(lightBackdrop, backdrop.parent)
            verify(item !== null)
            tryCompare(item, "imagesReady", true)
            item.progress = 0
            wait(80)
            var closed = grabImage(item)
            compare(closed.pixel(160, 10), "#ff0000", "light scheme still uses the screenshot")
            item.progress = 1
            wait(120)
            compare(grabImage(item).pixel(160, 230), "#0000ff", "wallpaper remains revealed")
        }

        function test_missingSnapshotFallsBackToTheThemedFloor() {
            var item = createTemporaryObject(coldBackdrop, backdrop.parent)
            verify(item !== null)
            item.progress = 0
            wait(80)
            var closed = grabImage(item)
            verify(isThemeDark(closed.pixel(160, 10)), "dark floor without a capture")
            verify(isThemeDark(closed.pixel(160, 230)), "dark floor without a capture")

            var light = createTemporaryObject(coldBackdrop, backdrop.parent, { lightScheme: true })
            verify(light !== null)
            light.progress = 0
            wait(80)
            var lightClosed = grabImage(light)
            verify(isThemeLight(lightClosed.pixel(160, 10)), "light floor without a capture")
            verify(isThemeLight(lightClosed.pixel(160, 230)), "light floor without a capture")
        }

        // A request that expects no capture must not be gated on an image that
        // will never arrive: the surface waits for `imagesReady` and falls back
        // to its bounded wait, so an always-false gate would hold the reveal.
        function test_capturelessRequestIsNotGatedOnAScreenshot() {
            var item = createTemporaryObject(capturelessBackdrop, backdrop.parent)
            verify(item !== null)
            tryCompare(item, "imagesReady", true)

            // Before the sweep the themed floor is all there is to show.
            item.progress = 0
            wait(80)
            var closed = grabImage(item)
            verify(isThemeDark(closed.pixel(160, 10)), "floor ahead of the sweep")
            verify(isThemeDark(closed.pixel(160, 230)), "floor ahead of the sweep")

            item.progress = 1
            wait(120)
            var settled = grabImage(item)
            compare(bandArea(settled), 0, "no bands left at rest")
            compare(settled.pixel(160, 10), "#0000ff", "wallpaper unveiled")
            compare(settled.pixel(160, 230), "#0000ff", "wallpaper unveiled")
        }

        // A capture that was expected and never arrived keeps its bounded wait,
        // which is what keeps a failed grim capture from exposing the wallpaper
        // the instant the surface appears.
        function test_expectedButMissingCaptureStillWaits() {
            var item = createTemporaryObject(coldBackdrop, backdrop.parent)
            verify(item !== null)
            verify(item.captureExpected === true)
            verify(item.imagesReady === false, "a pending capture still gates the reveal")
        }
    }
}
