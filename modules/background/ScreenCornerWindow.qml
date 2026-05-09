import Quickshell
import Quickshell.Wayland
import QtQuick

// Paint faux display corners in tiny overlay windows instead of one full-screen mask.
Variants {
    id: root

    readonly property int screenCornerRadius: 24

    model: Quickshell.screens

    Item {
        id: screenCorners

        required property var modelData

        readonly property int cornerSize: Math.max(1, Math.round(root.screenCornerRadius))

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

            ScreenCornerMask {
                anchors.fill: parent
                angle: 0
            }
        }

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

            ScreenCornerMask {
                anchors.fill: parent
                angle: 90
            }
        }

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

            ScreenCornerMask {
                anchors.fill: parent
                angle: 270
            }
        }

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

            ScreenCornerMask {
                anchors.fill: parent
                angle: 180
            }
        }
    }
}
