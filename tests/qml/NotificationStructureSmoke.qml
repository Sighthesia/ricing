import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.modules.notifications as NotificationParts
import qs.modules.bar as BarParts

// Smoke harness for notification popup/history structural contracts.
ShellRoot {
    id: root

    NotificationParts.NotificationPopupWindow {
        id: popupWindow
    }

    BarParts.NotificationHistoryPanel {
        id: historyPanel
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function _resetState() {
        NotificationService.activeList.clear()
        NotificationService.historyList.clear()
        BarLayoutService.notificationHistoryOpen = false
    }

    Component.onCompleted: {
        root._resetState()

        root._assert(popupWindow.visible === false,
            "NotificationPopupWindow should stay hidden with no active notifications")
        root._assert(popupWindow.implicitWidth > 0,
            "NotificationPopupWindow should expose a positive implicit width")
        root._assert(typeof NotificationService.markAllSeen === "function",
            "NotificationService should expose markAllSeen()")
        root._assert(typeof NotificationService.clearHistory === "function",
            "NotificationService should expose clearHistory()")
        root._assert(typeof NotificationService.removeFromHistory === "function",
            "NotificationService should expose removeFromHistory()")
        root._assert(typeof NotificationService.notificationsAvailable === "boolean",
            "NotificationService should expose notification availability diagnostics")
        root._assert(typeof NotificationService.notificationOwner === "string",
            "NotificationService should expose the current notification owner")
        root._assert(typeof NotificationService.notificationDiagnosticMessage === "string",
            "NotificationService should expose a human-readable diagnostic message")

        NotificationService.activeList.append({
            id: "smoke-active",
            appName: "Smoke",
            summary: "Active notification",
            body: "Body",
            appIcon: "",
            urgency: 1,
            actionsJson: "[]",
            timestamp: Date.now()
        })
        NotificationService.historyList.append({
            id: "smoke-history",
            appName: "Smoke",
            summary: "History notification",
            body: "Body",
            appIcon: "",
            urgency: 1,
            actionsJson: "[]",
            timestamp: Date.now()
        })

        Qt.callLater(function() {
            root._assert(popupWindow.visible === true,
                "NotificationPopupWindow should become visible when active notifications exist")
            root._assert(popupWindow.implicitHeight >= 16,
                "NotificationPopupWindow should include internal column height and padding")
            root._assert(popupWindow._isTop === true,
                "NotificationPopupWindow should default to top anchoring")
            root._assert(popupWindow._isRight === true,
                "NotificationPopupWindow should default to right anchoring")
            root._assert(historyPanel.implicitWidth === 400,
                "NotificationHistoryPanel should keep its fixed structural width")
            root._assert(historyPanel.implicitHeight === 480,
                "NotificationHistoryPanel should keep its fixed structural height")
            root._assert(historyPanel.active === false,
                "NotificationHistoryPanel should start closed")

            BarLayoutService.notificationHistoryOpen = true

            Qt.callLater(function() {
                root._assert(historyPanel.active === true,
                    "NotificationHistoryPanel should follow BarLayoutService.notificationHistoryOpen")

                root._resetState()
                console.log("NotificationStructure smoke test passed")
                Qt.callLater(Qt.quit)
            })
        })
    }
}
