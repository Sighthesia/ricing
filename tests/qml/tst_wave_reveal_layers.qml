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

        function test_leadOffsetShiftsRestGeometry() {
            compare(layers.leadOffset, 0)
            layers.leadOffset = -60
            compare(layers.waveRepeater.itemAt(0).restOffset, -600 * 0.72 - 60)
            compare(layers.waveRepeater.itemAt(3).restOffset, -600 * 0.16 - 60)
            layers.leadOffset = 0
        }

        function test_reverseOrderPutsLightBandOnTop() {
            compare(layers.reverseOrder, false)
            layers.reverseOrder = true
            compare(layers.waveRepeater.itemAt(0).z, 3)
            compare(layers.waveRepeater.itemAt(3).z, 0)
            layers.reverseOrder = false
            compare(layers.waveRepeater.itemAt(0).z, 0)
            compare(layers.waveRepeater.itemAt(3).z, 3)
        }

        function test_opacityRampForwardsToBands() {
            compare(layers.opacityRamp, 1.6)
            compare(layers.waveRepeater.itemAt(0).opacityRamp, 1.6)
            layers.opacityRamp = 8
            compare(layers.waveRepeater.itemAt(0).opacityRamp, 8)
            layers.opacityRamp = 1.6
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
