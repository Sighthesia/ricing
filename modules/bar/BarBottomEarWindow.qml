import "../../services" as Services
import Quickshell
import Quickshell.Wayland
import QtQuick

// Render the side dockzone bottom ears in dedicated overlay windows.
Variants {
    id: root

    readonly property int earRadius: 24
    readonly property color fillColor: "#ffa742"
    readonly property color borderColor: "#14ffffff"

    model: Quickshell.screens

    // Group the overlay ear windows for the current screen.
    Item {
        id: screenOverlay

        required property var modelData
        readonly property bool showLeftEar: Services.BarLayoutService.sectionWidgets("left").length > 0
        readonly property bool showRightEar: Services.BarLayoutService.sectionWidgets("right").length > 0

        // Render the left bottom ear outside the main bar body.
        PanelWindow {
            screen: screenOverlay.modelData
            color: "transparent"
            visible: screenOverlay.showLeftEar
            implicitWidth: root.earRadius
            implicitHeight: root.earRadius
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
            }

            margins {
                top: Services.BarLayoutService.barHeight
                left: root.earRadius
            }

            // Paint the left bottom ear with a native downward-attached path.
            Canvas {
                anchors.fill: parent
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d");
                    var w = width;
                    var h = height;
                    var curve = Math.min(w, h);
                    ctx.clearRect(0, 0, w, h);
                    ctx.fillStyle = root.fillColor;
                    ctx.strokeStyle = root.borderColor;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(w, h);
                    ctx.lineTo(0, h);
                    ctx.lineTo(0, 0);
                    ctx.arc(w, 0, curve, Math.PI, Math.PI / 2, true);
                    ctx.closePath();
                    ctx.fill();
                    ctx.stroke();
                }
            }
        }

        // Render the right bottom ear outside the main bar body.
        PanelWindow {
            screen: screenOverlay.modelData
            color: "transparent"
            visible: screenOverlay.showRightEar
            implicitWidth: root.earRadius
            implicitHeight: root.earRadius
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                right: true
            }

            margins {
                top: Services.BarLayoutService.barHeight - 1
                right: 0
            }

            // Paint the right bottom ear with a native downward-attached path.
            Canvas {
                anchors.fill: parent
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d");
                    var w = width;
                    var h = height;
                    var curve = Math.min(w, h);
                    ctx.clearRect(0, 0, w, h);
                    ctx.fillStyle = root.fillColor;
                    ctx.strokeStyle = root.borderColor;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(w, 0);
                    ctx.lineTo(0, 0);
                    ctx.arc(0, h, curve, -Math.PI / 2, 0, false);
                    ctx.closePath();
                    ctx.fill();
                    ctx.stroke();
                }
            }
        }
    }
}
