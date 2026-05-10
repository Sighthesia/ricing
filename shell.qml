import QtQuick
import Quickshell
import Quickshell.Wayland
import "modules/background" as Background

// Keep the shell root minimal while layering reusable screen surfaces.
ShellRoot {
    // Preserve the screen-corner overlays alongside the new center island.
    Background.ScreenCornerWindow {
    }

    // Render one transparent top panel per screen.
    Variants {
        model: Quickshell.screens

        // Host the center dock zone on the current screen.
        PanelWindow {
            required property var modelData

            screen: modelData
            color: "transparent"
            implicitHeight: dockZone.implicitHeight + 6

            anchors {
                top: true
                left: true
                right: true
            }

            // Place the adaptive island in the middle of the panel.
            Background.DynamicIslandDockZone {
                id: dockZone

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
            }

        }

    }

}
