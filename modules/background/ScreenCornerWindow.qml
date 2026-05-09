import Quickshell
import Quickshell.Wayland
import QtQuick

// Paint faux display corners in tiny overlay windows instead of one full-screen mask.
Variants {
    id: root

    readonly property int screenCornerRadius: 24

    model: Quickshell.screens

    // Group the four overlay windows for the current screen.
    Item {
        id: screenCorners

        required property var modelData

        readonly property int cornerSize: Math.max(1, Math.round(root.screenCornerRadius))

        // Render the top-left corner mask.
        PanelWindow {
            screen: screenCorners.modelData
            color: "transparent"
            implicitWidth: screenCorners.cornerSize
            implicitHeight: screenCorners.cornerSize
            anchors.top: true
            anchors.left: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Draw the masked corner fill inside the overlay.
            ScreenCornerMask {
                anchors.fill: parent
                angle: 0
            }
        }

        // Render the top-right corner mask.
        PanelWindow {
            screen: screenCorners.modelData
            color: "transparent"
            implicitWidth: screenCorners.cornerSize
            implicitHeight: screenCorners.cornerSize
            anchors.top: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Draw the masked corner fill inside the overlay.
            ScreenCornerMask {
                anchors.fill: parent
                angle: 90
            }
        }

        // Render the bottom-left corner mask.
        PanelWindow {
            screen: screenCorners.modelData
            color: "transparent"
            implicitWidth: screenCorners.cornerSize
            implicitHeight: screenCorners.cornerSize
            anchors.bottom: true
            anchors.left: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Draw the masked corner fill inside the overlay.
            ScreenCornerMask {
                anchors.fill: parent
                angle: 270
            }
        }

        // Render the bottom-right corner mask.
        PanelWindow {
            screen: screenCorners.modelData
            color: "transparent"
            implicitWidth: screenCorners.cornerSize
            implicitHeight: screenCorners.cornerSize
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Draw the masked corner fill inside the overlay.
            ScreenCornerMask {
                anchors.fill: parent
                angle: 180
            }
        }
    }
}
