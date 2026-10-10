pragma ComponentBehavior: Bound

import QtQuick
import "WaveSurfaceLogic.js" as Logic

// Render the reusable four-layer Wave reveal without owning its timing.
//
// The stack is pinned to the panel edge (`edge` = panel top): every layer
// rides at its push offset above the edge, so the panel pushes the whole fan
// ahead instead of swallowing the lower layers. Reduced motion keeps the
// absolute sweep (the edge never moves there, so pinning would park a band
// mid-screen behind the fading panel).
Item {
    id: root

    property real progress: 0
    // Panel top the fan is pushed by; 0 parks the stack at its rest shape.
    property real edge: 0
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
            progress: MotionTokens.reducedMotion ? root.progress : 1
            angle: Logic.waveAngle(index)
            anchorRight: (index % 2) === 1
            colour: index === 0 ? (root.palette.light4 || "transparent")
                    : index === 1 ? (root.palette.light3 || "transparent")
                    : index === 2 ? (root.palette.dark4 || "transparent")
                    : (root.palette.dark3 || "transparent")
            restOffset: MotionTokens.reducedMotion
                    ? Logic.waveFinalPosition(index)
                    : Logic.wavePushOffset(index) + root.edge
        }
    }
}
