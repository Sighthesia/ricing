import QtQuick
import "../../services" as Services

// Overlay that draws the insertion indicator line during widget drag.
Item {
    id: dragOverlay

    anchors.fill: parent
    z: 999
    visible: Services.BarLayoutService.isDragging

    // Insertion indicator line at the ghost position.
    Rectangle {
        id: insertIndicator

        visible: Services.BarLayoutService.ghostIndex >= 0
            && Services.BarLayoutService.ghostSection !== ""
        width: 2
        height: Services.BarLayoutService.barHeight - 8
        anchors.verticalCenter: parent.verticalCenter
        radius: 1
        color: "#88ffffff"
        opacity: 0.9
        x: Services.BarLayoutService.dragVisualCenterX

        Behavior on x {
            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
        }
    }
}
