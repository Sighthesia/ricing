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

        function isPinkBand(c) {
            return c.r > 0.75 && c.g < 0.63 && c.b > 0.31 && c.b < 0.82
        }

        function test_waveDecorationBands() {
            tryCompare(backdrop, "imagesReady", true)
            // Mid-sweep the pink bands peek ahead of the wallpaper edge.
            backdrop.progress = 0.5
            wait(120)
            var sweeping = grabImage(backdrop)
            var pinkSeen = false
            for (var y = 40; y <= 80; y += 4) {
                if (isPinkBand(sweeping.pixel(160, y)))
                    pinkSeen = true
            }
            verify(pinkSeen, "pink wave bands must lead the wallpaper edge mid-sweep")
            // The settled frame stays pure wallpaper with no bands left over.
            backdrop.progress = 1
            wait(120)
            var settled = grabImage(backdrop)
            for (var y2 = 0; y2 < 240; y2 += 8)
                verify(!isPinkBand(settled.pixel(160, y2)), "no pink bands at rest y=" + y2)
        }

        function test_curtainBothDirections() {
            tryCompare(backdrop, "imagesReady", true)
            var stages = [0, 0.5, 1, 0.5, 0]
            for (var i = 0; i < stages.length; ++i) {
                backdrop.progress = stages[i]
                wait(80)
                var image = grabImage(backdrop)
                compare(image.pixel(160, 10), stages[i] === 1 ? "#0000ff" : "#ff0000", "top at " + stages[i])
                compare(image.pixel(160, 230), stages[i] === 0 ? "#ff0000" : "#0000ff", "bottom at " + stages[i])
            }
        }
    }
}
