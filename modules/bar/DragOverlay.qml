import QtQuick
import qs.config
import qs.services

Item {
    id: dragOverlay

    anchors.fill: parent
    visible: BarLayoutService.settingsMode
    z: 999

    // Widget source registry (passed from BarContent)
    property var widgetRegistry: ({})

    // Drop zone indicators: three sections
    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.barPadding
        anchors.rightMargin: Theme.barPadding

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
        scale: 1.05
        opacity: 0.9

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
