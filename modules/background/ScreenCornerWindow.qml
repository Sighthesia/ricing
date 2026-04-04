import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services

// Paints faux display corners above each screen without covering the whole input region.
Variants {
    id: root

    model: Quickshell.screens

    Item {
        id: screenCorners

        required property var modelData

        readonly property int _cornerSize: Math.max(1, Math.round(SettingsService.data.appearance.screenCornerRadius))

        // Keep each faux corner in its own tiny window so we do not need a
        // full-screen input mask just to paint the arc.
        PanelWindow {
            screen: screenCorners.modelData
            color: "transparent"
            implicitWidth: screenCorners._cornerSize
            implicitHeight: screenCorners._cornerSize
            anchors.top: true
            anchors.left: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            ScreenCornerMask {
                anchors.fill: parent
                angle: 0
            }
        }

        PanelWindow {
            screen: screenCorners.modelData
            color: "transparent"
            implicitWidth: screenCorners._cornerSize
            implicitHeight: screenCorners._cornerSize
            anchors.top: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            ScreenCornerMask {
                anchors.fill: parent
                angle: 90
            }
        }

        PanelWindow {
            screen: screenCorners.modelData
            color: "transparent"
            implicitWidth: screenCorners._cornerSize
            implicitHeight: screenCorners._cornerSize
            anchors.bottom: true
            anchors.left: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            ScreenCornerMask {
                anchors.fill: parent
                angle: 270
            }
        }

        PanelWindow {
            screen: screenCorners.modelData
            color: "transparent"
            implicitWidth: screenCorners._cornerSize
            implicitHeight: screenCorners._cornerSize
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            ScreenCornerMask {
                anchors.fill: parent
                angle: 180
            }
        }
    }
}
