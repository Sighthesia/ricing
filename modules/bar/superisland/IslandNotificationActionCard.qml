import QtQuick
import qs.services
import "." as SuperIslandParts

// Wraps notification card visuals with the default activation behavior.
Item {
    id: root

    required property var event
    required property string iconSource

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    SuperIslandParts.IslandNotificationCard {
        id: card

        event: root.event
        iconSource: root.iconSource
        anchors.fill: parent
    }

    Connections {
        target: card

        function onActivated() {
            const eventId = String(root.event && root.event.id ? root.event.id : "")
            const prefix = "notification:"
            if (eventId.startsWith(prefix) && NotificationService.invokeDefaultAction(eventId.slice(prefix.length)))
                return

            BarLayoutService.notificationHistoryOpen = true
        }
    }
}
