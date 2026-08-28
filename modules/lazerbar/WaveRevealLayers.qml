import QtQuick
import "WaveSurfaceLogic.js" as Logic

// Render the reusable four-layer Wave reveal without owning its timing.
Item {
    id: root

    property real progress: 0
    property var palette: ({})
    property bool fullscreen: false
    property alias waveRepeater: waveRepeater

    anchors.fill: parent

    // Keep each angled wave inside the consumer-provided viewport.
    Repeater {
        id: waveRepeater
        model: 4

        // Paint one palette layer with the established Wave geometry.
        delegate: FullscreenWave {
            required property int index
            anchors.fill: parent
            progress: root.progress
            angle: Logic.waveAngle(index)
            colour: index === 0 ? (root.palette.light4 || "transparent")
                    : index === 1 ? (root.palette.light3 || "transparent")
                    : index === 2 ? (root.palette.dark4 || "transparent")
                    : (root.palette.dark3 || "transparent")
            restOffset: -parent.height * ([0.72, 0.5, 0.32, 0.16][index])
        }
    }
}
