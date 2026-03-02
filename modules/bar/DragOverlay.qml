import QtQuick
import qs.config
import qs.services

Item {
    id: dragOverlay

    anchors.fill: parent
    visible: BarLayoutService.settingsMode
    z: 999

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
}
