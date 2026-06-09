import QtQuick
import Quickshell
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services
import "../common" as Common

// Shared notification-center page: history list with sticky toggle and hover preview.
Item {
    id: root

    readonly property var historyModel: Services.NotificationService.historyList

    function _previewText(entry) {
        if (!entry)
            return ""
        return entry.body && entry.body !== "" ? entry.body : (entry.summary || "")
    }

    // Drive read state when the notification page becomes visible.
    Component.onCompleted: Services.NotificationService.markAllRead()

    Connections {
        target: Services.IslandService

        function onPanelPageChanged() {
            if (Services.IslandService.expanded && Services.IslandService.panelPage === "notifications")
                Services.NotificationService.markAllRead()
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10

        // Notification center header.
        Rectangle {
            width: parent.width
            height: 48
            radius: 14
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
            border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.55)
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "通知中心"
                    color: Services.Color.mOnSurface
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.NotificationService.unreadCount > 0
                        ? (Services.NotificationService.unreadCount + " 条未读")
                        : "已读"
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 11
                }
            }
        }

        // History list.
        ListView {
            id: historyListView

            width: parent.width
            height: parent.height - 58
            clip: true
            spacing: 8
            model: root.historyModel

            delegate: NotificationHistoryCard {
                width: ListView.view ? ListView.view.width : 200
                notificationEntry: ({
                    notifId: notifId,
                    appName: appName,
                    summary: summary,
                    body: body,
                    icon: icon,
                    timestamp: timestamp,
                    read: read,
                    sticky: sticky,
                    defaultSticky: defaultSticky,
                    sourceName: sourceName
                })
                onToggleStickyRequested: Services.NotificationService.toggleSticky(notifId)
            }
        }
    }
}
