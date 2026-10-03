import QtQuick
import QtTest
import "../../modules/lock"

Item {
    id: harness
    width: 320
    height: 240

    // Stands in for the desktop behind the lock surface. The wave no longer paints
    // a wallpaper: it opens onto transparency, and this is what shows through —
    // which is exactly the mechanism that puts the real wallpaper on screen.
    Rectangle {
        id: desktop
        anchors.fill: parent
        color: "#0000ff"
    }

    // One host per temporary instance, so the sentinel behind it is the only
    // thing in its rectangle besides the instance itself.
    Component {
        id: instanceHostComponent
        Item {
            width: 320
            height: 240
            Rectangle {
                anchors.fill: parent
                color: "#0000ff"
            }
            property Item target: null
        }
    }

    LockBackdrop {
        id: backdrop
        anchors.fill: parent
        snapshotSource: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><rect width="320" height="240" fill="red"/></svg>')
    }

    // Temporary instances are parented here, above the shared `backdrop`. Parenting
    // them to `backdrop.parent` left them beside it instead of above it, and since
    // both fill the same rect the sibling declared later painted over the instance
    // under test — the grab then reported the shared fixture's red capture and the
    // assertion blamed the component.


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
        }
    }

    Component {
        id: foregroundProbeBackdrop
        LockBackdrop {
            width: 320
            height: 240
            snapshotSource: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><rect width="320" height="240" fill="red"/></svg>')

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

    // The session-start lock: no capture at all, so the wave opens straight onto
    // the desktop.
    Component {
        id: capturelessBackdrop
        LockBackdrop {
            width: 320
            height: 240
            captureExpected: false
        }
    }

    TestCase {
        name: "LockBackdropPixels"
        when: windowShown

        function test_localSnapshotReadyBeforeFirstFrame() {
            var item = instanceFor(coldBackdrop, {
                snapshotSource: Qt.resolvedUrl("../../modules/bar/icons/wifi.svg")
            })
            verify(item !== null)
            verify(item.snapshotReady, "local screenshot must be decoded before the first frame")
            // Readiness is the capture and nothing else. The wallpaper the wave
            // used to wait on is gone, so a decoded capture is immediately ready —
            // and a request with no capture at all is ready from the start, which
            // is what stops a session-start lock from burning its whole grace
            // window on an image that was never coming.
            verify(item.imagesReady === true, "a decoded capture is ready with no wallpaper to wait for")
        }

        // `grabImage` samples the grabbed item's rectangle rather than its own
        // subtree, so a sibling painted above the instance shows up in the capture.
        // Each temporary instance therefore gets a host of its own: the sentinel
        // directly behind it, and nothing above.
        function instanceFor(component, properties) {
            var host = createTemporaryObject(instanceHostComponent, harness)
            var instance = createTemporaryObject(component, host, properties)
            instance.z = 1
            return instance
        }

        function isThemeDark(c) { return c.r < 0.2 && c.g < 0.2 && c.b < 0.2 }
        function isThemeLight(c) { return c.r > 0.8 && c.g > 0.8 && c.b > 0.8 }
        // The wave no longer paints a wallpaper: what it opens is transparent, so
        // whatever is behind the surface shows through. Assert against a sentinel
        // desktop rather than alpha, because `grabImage` flattens transparency onto
        // white and would make an empty region indistinguishable from a white plate.
        function isDesktop(c) { return c.b > 0.9 && c.r < 0.1 && c.g < 0.1 }
        function isScreenshotRed(c) { return c.r > 0.9 && c.g < 0.1 && c.b < 0.1 }

        // Pixels that are neither the pre-lock screenshot nor the desktop carry
        // wave bands or the themed floor; their count measures how much is on
        // screen.
        function bandArea(image) {
            var bands = 0
            for (var x = 8; x < 320; x += 8)
                for (var y = 0; y < 240; y += 8) {
                    var c = image.pixel(x, y)
                    if (!isScreenshotRed(c) && !isDesktop(c))
                        ++bands
                }
            return bands
        }

        function test_maskTrailsBands() {
            var item = instanceFor(capturelessBackdrop)
            verify(item !== null)
            tryCompare(item, "imagesReady", true)
            compare(item.maskProgress, 0)
            item.progress = 0.3
            compare(item.maskProgress, 0)
            item.progress = 0.65
            verify(Math.abs(item.maskProgress - 0.5) < 0.001)
            item.progress = 1
            compare(item.maskProgress, 1)
        }

        function test_desktopUnveiledAtBandTail() {
            tryCompare(backdrop, "imagesReady", true)
            // Mid-sweep three zones read top to bottom: the pre-lock screenshot
            // ahead, pink bands, and the live desktop behind where the bands
            // swept past. The desktop reads as transparent here because nothing
            // is painted over it — which is exactly what lets the real wallpaper
            // show through on the surface.
            backdrop.progress = 0.5
            wait(120)
            var sweeping = grabImage(backdrop)
            compare(sweeping.pixel(160, 10), "#ff0000", "screenshot ahead")
            var midSweep = sweeping.pixel(160, 120)
            verify(!isScreenshotRed(midSweep) && !isDesktop(midSweep), "pink bands")
            verify(isDesktop(sweeping.pixel(160, 230)), "desktop behind")
            // Open and settled frames stay pure.
            backdrop.progress = 0
            wait(120)
            var open = grabImage(backdrop)
            compare(bandArea(open), 0, "no bands before the sweep")
            backdrop.progress = 1
            wait(120)
            var settled = grabImage(backdrop)
            compare(bandArea(settled), 0, "no bands left at rest")
            verify(isDesktop(settled.pixel(160, 10)), "settled desktop")
        }

        function test_foregroundContentUsesTheWallpaperRevealClip() {
            var item = instanceFor(foregroundProbeBackdrop)
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
                    verify(!isScreenshotRed(mid) && !isDesktop(mid), "bands at 0.5")
                    verify(isDesktop(image.pixel(160, 230)), "bottom at 0.5")
                } else {
                    if (stages[i] === 1) {
                        verify(isDesktop(image.pixel(160, 10)), "top at 1")
                        verify(isDesktop(image.pixel(160, 230)), "bottom at 1")
                    } else {
                        compare(image.pixel(160, 10), "#ff0000", "top screenshot at 0")
                        compare(image.pixel(160, 230), "#ff0000", "bottom screenshot at 0")
                    }
                }
            }
        }

        function test_themedFloorOnlyShowsWithoutAScreenshot() {
            var item = instanceFor(lightBackdrop)
            verify(item !== null)
            tryCompare(item, "imagesReady", true)
            item.progress = 0
            wait(80)
            var closed = grabImage(item)
            compare(closed.pixel(160, 10), "#ff0000", "light scheme still uses the screenshot")
            item.progress = 1
            wait(120)
            verify(isDesktop(grabImage(item).pixel(160, 230)), "desktop remains revealed")
        }

        function test_missingSnapshotFallsBackToTheThemedFloor() {
            var item = instanceFor(coldBackdrop)
            verify(item !== null)
            item.progress = 0
            wait(80)
            var closed = grabImage(item)
            verify(isThemeDark(closed.pixel(160, 10)), "dark floor without a capture")
            verify(isThemeDark(closed.pixel(160, 230)), "dark floor without a capture")

            var light = instanceFor(coldBackdrop, { lightScheme: true })
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
            var item = instanceFor(capturelessBackdrop)
            verify(item !== null)
            tryCompare(item, "imagesReady", true)

            // Before the sweep the themed floor is all there is to show.
            item.progress = 0
            wait(80)
            var closed = grabImage(item)
            // Ahead of the sweep the whole surface is still the opaque floor, so
            // the sentinel desktop behind it must not show anywhere — that is what
            // keeps a lock from exposing the desktop before its first frame.
            verify(!isDesktop(closed.pixel(160, 10)), "floor ahead of the sweep")
            verify(!isDesktop(closed.pixel(160, 230)), "floor ahead of the sweep")
            compare(closed.pixel(160, 10), closed.pixel(160, 230),
                   "the floor is one flat surface ahead of the sweep")

            item.progress = 1
            wait(120)
            var settled = grabImage(item)
            compare(bandArea(settled), 0, "no bands left at rest")
            verify(isDesktop(settled.pixel(160, 10)), "desktop unveiled")
            verify(isDesktop(settled.pixel(160, 230)), "desktop unveiled")
        }

        // The backdrop decodes exactly one image: the pre-lock capture.
        //
        // It used to decode two. The wallpaper was painted here as well, and it
        // never reached the screen: on a `WlSessionLockSurface` the image reported
        // Ready with correct geometry and the mask fully open, and the lock screen
        // stayed on the themed plate — the same "object exists, properties
        // correct, never renders" trap this shell already documents for Repeater
        // delegates. Removing the clip did not fix it, which is what proved the
        // image itself was the problem.
        //
        // So there is no wallpaper layer any more. The wave opens onto
        // transparency and the desktop behind the surface shows through, which is
        // both what was asked for and a whole full-screen decode cheaper on the
        // one frame the lock screen is judged on. Pinning the absence matters:
        // offscreen this component renders a wallpaper perfectly well, so every
        // pixel test here would pass with the layer restored.
        function test_theBackdropDecodesNoWallpaper() {
            var images = findImages(backdrop)
            verify(images.length === 1,
                   "only the pre-lock capture may be decoded, found " + images.length)
            verify(String(images[0].source).indexOf("red") >= 0,
                   "the one image is the capture, not a wallpaper")

            // And no property may reintroduce one: a caller wiring a wallpaper
            // back in would silently reintroduce the decode.
            verify(backdrop.wallpaperSource === undefined,
                   "the backdrop must not accept a wallpaper source at all")
        }

        function findImages(node) {
            var found = []
            if (!node)
                return found
            if (node.toString().indexOf("Image") >= 0 && node.source !== undefined)
                found.push(node)
            var kids = node.children
            for (var i = 0; kids && i < kids.length; i++)
                found = found.concat(findImages(kids[i]))
            return found
        }

        // A capture that was expected and never arrived keeps its bounded wait,
        // which is what keeps a failed grim capture from exposing the desktop
        // the instant the surface appears.
        function test_expectedButMissingCaptureStillWaits() {
            var item = instanceFor(coldBackdrop)
            verify(item !== null)
            verify(item.captureExpected === true)
            verify(item.imagesReady === false, "a pending capture still gates the reveal")
        }
    }
}
