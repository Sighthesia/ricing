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

    }

}
