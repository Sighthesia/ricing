import QtQuick
import Quickshell
import Quickshell.Wayland

// Reserve the workspace and paint the continuous top-bar silhouette.
PanelWindow {
    id: root
    required property var targetScreen
    screen: targetScreen
    color: "transparent"
    implicitHeight: LazerTheme.barHeight
    exclusiveZone: LazerTheme.barHeight
    anchors { top: true; left: true; right: true }
    mask: Region {}

    Rectangle {
        anchors.fill: parent
        color: LazerTheme.bgDark
        bottomLeftRadius: LazerTheme.bottomRadius
        bottomRightRadius: LazerTheme.bottomRadius
    }
}
