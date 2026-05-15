pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Receive D-Bus notifications and maintain a popup queue (auto-dismiss).
Singleton {
    id: root

    property bool dndEnabled: SettingsService.notifications.dnd
    property ListModel popupList: ListModel {}

    function removeNotification(notifId) {
        for (let i = 0; i < popupList.count; i++) {
            if (popupList.get(i).notifId === notifId) {
                popupList.remove(i)
                return
            }
        }
    }

    property NotificationServer _server: NotificationServer {
        onNotification: n => {
            if (root.dndEnabled) return

            // Cap at configured max visible popups
            if (root.popupList.count >= SettingsService.notifications.maxVisible)
                root.popupList.remove(0)

            root.popupList.append({
                notifId: n.id,
                appName: n.appName || "",
                summary: n.summary || "",
                body: n.body || "",
                icon: n.appIcon || n.image || "",
                timestamp: Date.now()
            })
        }
    }
}
