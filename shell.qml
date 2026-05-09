import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            height: 28
            color: "#202020"

            Text {
                anchors.centerIn: parent
                text: "QuickShell"
                color: "#ffffff"
            }
        }
    }
}
