import QtQuick
import Quickshell
import "../../lazerbar"
import "../../../services" as Services

// Workspace overview squares with click-to-focus.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: LazerTheme.targetSize

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: LazerTheme.inlineGap

        Repeater {
            model: Services.NiriService.workspaces

            // One sharp square per workspace; the active one fills with accent.
            delegate: Item {
                id: workspaceSquare

                required property var modelData

                readonly property bool hovered: hoverHandler.hovered

                width: 24
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: workspaceSquare.modelData.isActive
                           ? LazerTheme.activeFill
                           : workspaceSquare.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // Active workspaces keep a thin accent strip along the bottom.
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: workspaceSquare.modelData.isActive ? parent.width - 8 : 0
                    height: 2
                    color: LazerTheme.osuGreen

                    Behavior on width { NumberAnimation { duration: MotionTokens.fast } }
                }

                Text {
                    anchors.centerIn: parent
                    text: workspaceSquare.modelData.idx
                    color: workspaceSquare.modelData.isActive
                           ? LazerTheme.textPrimary
                           : workspaceSquare.hovered ? LazerTheme.hoverForeground : LazerTheme.iconInactive
                    font.pixelSize: 11
                    font.bold: workspaceSquare.modelData.isActive
                }

                HoverHandler {
                    id: hoverHandler
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: Quickshell.execDetached([
                        "niri", "msg", "action", "focus-workspace",
                        String(workspaceSquare.modelData.idx)
                    ])
                }
            }
        }
    }
}
