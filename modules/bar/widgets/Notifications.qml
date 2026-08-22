import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Notification bell with an unread diamond and do-not-disturb toggle.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property bool dnd: Services.NotificationService.dndEnabled
    readonly property int unread: Services.NotificationService.unreadCount

    onClicked: Services.NotificationService.dndEnabled = !root.dnd

    implicitWidth: bellHost.width + 12

    Item {
        id: bellHost

        anchors.centerIn: parent
        width: 20
        height: 20

        Image {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: "../../lazerbar/icons/bell.svg"
            opacity: root.dnd ? 0.4 : 0.9

            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }

        // Unread state uses a sharp accent diamond, never a rounded badge.
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            width: 7
            height: 7
            radius: 0
            rotation: 45
            color: LazerTheme.osuPink
            visible: root.unread > 0 && !root.dnd
        }
    }
}
