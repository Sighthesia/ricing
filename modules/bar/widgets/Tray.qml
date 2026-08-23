import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../../lazerbar"

// StatusNotifier tray icons with activate and secondary actions.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    implicitWidth: trayRow.implicitWidth
    implicitHeight: LazerTheme.targetSize

    Row {
        id: trayRow

        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: SystemTray.items && SystemTray.items.values
                   ? SystemTray.items.values : []

            // One hover square per tray item; icons stay theme-provided.
            delegate: Item {
                id: trayIcon

                required property var modelData

                readonly property bool hovered: iconHover.hovered
                readonly property string label:
                    modelData.title || modelData.tooltipTitle || modelData.id || "Tray item"

                width: LazerTheme.barWidgetHeight
                height: LazerTheme.barWidgetHeight
                Accessible.role: Accessible.Button
                Accessible.name: label

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: trayIcon.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                IconImage {
                    anchors.centerIn: parent
                    width: LazerTheme.barGlyphSize - 4
                    height: LazerTheme.barGlyphSize - 4
                    asynchronous: true
                    source: trayIcon.modelData.icon
                }

                HoverHandler {
                    id: iconHover
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: trayIcon.modelData.activate()
                }

                // Right click triggers the SNI secondary action until a
                // dedicated menu window is rebuilt for this bar.
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: trayIcon.modelData.secondaryActivate()
                }
            }
        }
    }
}
