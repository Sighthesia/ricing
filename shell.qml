import Quickshell
import Quickshell.Wayland
import QtQuick
import "modules/background" as Background

ShellRoot {
    Background.ScreenCornerWindow {}

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

            implicitHeight: 28
            color: "#202020"

            Text {
                anchors.centerIn: parent
                text: "QuickShell"
                color: "#ffffff"
            }
        }
    }
}
