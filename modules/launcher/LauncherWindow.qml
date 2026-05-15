import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// One overlay panel per screen
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData

        visible: Services.LauncherService.visible
        color: "transparent"
        exclusiveZone: -1

        anchors { top: true; left: true; right: true; bottom: true }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "afloat-launcher"

        // Dim backdrop
        Rectangle {
            anchors.fill: parent
            color: "#cc000000"

            // Click-away to dismiss
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: Services.LauncherService.close()
            }

            // Centered launcher content
            LauncherContent {
                anchors.centerIn: parent
                width: 600
                height: parent.height * 0.7
            }
        }
    }
}
