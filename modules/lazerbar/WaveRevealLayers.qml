pragma ComponentBehavior: Bound

import QtQuick
import "WaveSurfaceLogic.js" as Logic

// Render the reusable four-layer Wave reveal without owning its timing.
Item {
    id: root

    property real progress: 0
    // `final` keeps this intentional name from shadowing Item.palette.
    final property var palette: ({})
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
            anchorRight: (index % 2) === 1
            colour: index === 0 ? (root.palette.light4 || "transparent")
                    : index === 1 ? (root.palette.light3 || "transparent")
                    : index === 2 ? (root.palette.dark4 || "transparent")
                    : (root.palette.dark3 || "transparent")
            restOffset: Logic.waveFinalPosition(index)
        }
    }
}
