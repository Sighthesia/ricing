import QtQuick
import qs.config
import qs.services

Item {
    id: dragOverlay

    anchors.fill: parent
    z: 999

    // Fade in/out when entering or leaving layout mode — prevents an abrupt
    // appearance that would be jarring against the existing bar content.
    visible: opacity > 0
    enabled: BarLayoutService.settingsMode
    opacity: BarLayoutService.settingsMode ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Easing.OutQuad
        }
    }

    // Widget source registry (passed from BarContent)
    property var widgetRegistry: ({})

    // Drop zone indicators: three sections.
    // Height is capped to Theme.barHeight so that the WorkspaceWidget's
    // dynamic downward flash-extension does not stretch the zone borders.
    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.barPadding
        anchors.rightMargin: Theme.barPadding
        height: Theme.barHeight

        DropZone {
            id: leftZone
            zoneName: "left"
            width: parent.width / 3
            height: parent.height
        }

        DropZone {
            id: centerZone
            zoneName: "center"
            width: parent.width / 3
            height: parent.height
        }

        DropZone {
            id: rightZone
            zoneName: "right"
            width: parent.width / 3
            height: parent.height
        }
    }

    // Floating copy of the dragged widget
    Item {
        id: floatingCopy
        visible: BarLayoutService.isDragging && BarLayoutService.draggedWidgetId !== ""
        x: BarLayoutService.dragVisualX
        anchors.verticalCenter: parent.verticalCenter
        width: BarLayoutService.ghostWidth
        height: parent.height
        scale: Theme.dragScale
        opacity: Theme.dragOpacity

        Loader {
            id: floatingLoader
            anchors.verticalCenter: parent.verticalCenter
            source: {
                if (!floatingCopy.visible) return "";
                let wid = BarLayoutService.draggedWidgetId;
                return dragOverlay.widgetRegistry[wid] || "";
            }
            active: source !== ""
        }
    }
}
