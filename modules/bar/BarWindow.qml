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
            id: barContent

            screenName: modelData.name
            anchors.fill: parent
        }

        // Keep the minimal widget picker attached to the shared dock zone surface.
        BarDockZoneBackground {
            id: widgetPickerButton

            screenName: modelData.name
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.rightMargin: 8

            surfaceHeight: Services.BarLayoutService.barHeight
            contentWidth: 26
            contentHeight: 26
            horizontalPadding: 8
            verticalPadding: 8
            earRadius: 10
            bodyRadius: 10

            // Render the plus action on the background surface.
            Text {
                anchors.centerIn: parent
                text: "+"
                color: "white"
                font.pixelSize: 18
            }

            // Capture clicks across the shared surface so the picker still opens reliably.
            MouseArea {
                anchors.fill: parent
                onClicked: Services.BarLayoutService.toggleWidgetPicker("center")
            }
        }

    }

}
