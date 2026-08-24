import QtQuick
import "../lazerbar"
import "../../../services" as Services

// Quick actions for the notifications hover popup: do-not-disturb toggle
// and mark-all-read, in the shared sharp row language.
Rectangle {
    id: root

    readonly property bool dnd: Services.NotificationService.dndEnabled
    readonly property int unread: Services.NotificationService.unreadCount

    implicitWidth: 240
    implicitHeight: actionColumn.implicitHeight + 16
    radius: 10
    color: LazerTheme.popupBackground
    border.width: 1
    border.color: LazerTheme.popupBorder

    Column {
        id: actionColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        topPadding: 8
        bottomPadding: 8
        spacing: 2

        // Do-not-disturb toggle row with a two-state indicator block.
        Item {
            width: parent.width
            height: 34

            Rectangle {
                anchors.fill: parent
                radius: 5
                color: dndHover.hovered ? LazerTheme.settingsMenuHover : "transparent"

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Do not disturb"
                color: LazerTheme.textPrimary
                font.pixelSize: 13
            }

            // State block: green when silent, muted outline when open.
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 16
                radius: 4
                color: root.dnd ? LazerTheme.activeFill : LazerTheme.settingsToggleOff
                border.width: 1
                border.color: root.dnd ? LazerTheme.osuGreen : LazerTheme.divider

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }

                Text {
                    anchors.centerIn: parent
                    text: root.dnd ? "ON" : "OFF"
                    color: root.dnd ? LazerTheme.osuGreen : LazerTheme.textMuted
                    font.pixelSize: 9
                }
            }

            HoverHandler {
                id: dndHover
            }

            TapHandler {
                onTapped: Services.NotificationService.dndEnabled =
                          !Services.NotificationService.dndEnabled
            }

            Accessible.role: Accessible.CheckBox
            Accessible.name: "Do not disturb"
            Accessible.checked: root.dnd
        }

        // Mark all read; only actionable while something is unread.
        Item {
            width: parent.width
            height: 34
            opacity: root.unread > 0 ? 1 : MotionTokens.disabledOpacity

            Rectangle {
                anchors.fill: parent
                radius: 5
                color: clearHover.hovered && root.unread > 0
                       ? LazerTheme.settingsMenuHover : "transparent"

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Mark all read"
                color: LazerTheme.textPrimary
                font.pixelSize: 13
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: String(root.unread)
                color: LazerTheme.textMuted
                font.pixelSize: 11
                visible: root.unread > 0
            }

            HoverHandler {
                id: clearHover
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: if (root.unread > 0) {
                              Services.NotificationService.markAllRead()
                              Services.BarPopupService.close()
                          }
            }
        }
    }
}
