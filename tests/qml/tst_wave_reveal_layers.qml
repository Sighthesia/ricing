import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Mount the reusable wave layers at a fixed viewport for geometry assertions.
Item {
    width: 800
    height: 600

    // Exercise the visual-only four-layer renderer with a deterministic palette.
    Lazer.WaveRevealLayers {
        id: layers
        anchors.fill: parent
        palette: ({ light4: "#111111", light3: "#222222", dark4: "#333333", dark3: "#444444" })
    }

    // Verify the extracted layer contract independently from the surface host.
    TestCase {
        name: "WaveRevealLayers"

        function test_fourLayersAndAngles() {
            compare(layers.waveRepeater.count, 4)
            compare(layers.waveRepeater.itemAt(0).angle, 13)
            compare(layers.waveRepeater.itemAt(1).angle, -7)
            compare(layers.waveRepeater.itemAt(2).angle, 4)
            compare(layers.waveRepeater.itemAt(3).angle, -2)
            verify(layers.waveRepeater.itemAt(0).clip)
        }

        function test_progressReachesFinalGeometry() {
            layers.progress = 0
            compare(layers.waveRepeater.itemAt(0).progress, 0)
            layers.progress = 1
            compare(layers.waveRepeater.itemAt(0).progress, 1)
            compare(layers.waveRepeater.itemAt(0).opacity, 1)
        }
    }
}
