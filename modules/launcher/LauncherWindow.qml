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

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? launcherBlurRegion : null

        // Blur only the visible launcher panel, not the full-screen dim layer.
        Region {
            id: launcherBlurRegion

            item: Services.LauncherService.visible ? launcherPanelBlurSource : null
            radius: launcherPanelSurface.radius
        }

        // Dim backdrop
        Rectangle {
            id: launcherBackdrop

            anchors.fill: parent
            color: "#66000000"

            // Click-away to dismiss
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: Services.LauncherService.close()
            }

        }

        // Center the actual launcher glass panel above the dim backdrop.
        Rectangle {
            id: launcherPanelSurface

            anchors.centerIn: parent
            width: 600
            height: parent.height * 0.7
            radius: 18
            color: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)

            // Full-size blur source — covers the entire visible fill geometry.
            Item {
                id: launcherPanelBlurSource

                anchors.fill: parent
            }

            LauncherContent {
                anchors.fill: parent
                anchors.margins: 12
            }

            // Border overlay rendered above all content.
            Rectangle {
                anchors.fill: parent
                radius: launcherPanelSurface.radius
                color: "transparent"
                border.color: Services.Color.mOutline
                border.width: 1
            }
        }
    }
}
