import "."
import "../../services" as Services
import QtQuick
import Quickshell
import Quickshell.Wayland

// Own one transparent bar window per screen.
Variants {
    id: root

    model: Quickshell.screens

    // Host the reusable bar content on the current screen.
    PanelWindow {
        required property var modelData

        screen: modelData
        color: "transparent"
        implicitHeight: Services.BarLayoutService.barHeight

        anchors {
            top: true
            left: true
            right: true
        }

        BarContent {
            anchors.fill: parent
        }

        // Keep a temporary fixed entry point for the minimal widget picker.
        Rectangle {
            id: widgetPickerButton

            width: 26
            height: 26
            radius: 13
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.rightMargin: 8
            color: "#2b2b2b"
            border.color: "#5a5a5a"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "+"
                color: "white"
                font.pixelSize: 18
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Services.BarLayoutService.toggleWidgetPicker("center")
            }
        }

    }

}
