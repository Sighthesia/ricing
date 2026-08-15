pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Receive D-Bus notifications and maintain a popup queue (auto-dismiss).
Singleton {
    id: root

    property bool dndEnabled: SettingsService.notifications.dnd
    property ListModel popupList: ListModel {}
    property ListModel historyList: ListModel {}
    property ListModel stickyList: ListModel {}
    property int unreadCount: 0
    property int stickyCarouselIndex: 0
    property bool summaryDismissed: false
    property string latestAppName: ""
    property string latestSummary: ""
    property string latestBody: ""
    property string latestIcon: ""
    property string latestOpencodeId: ""
    property string latestOpencodeAppName: ""
    property string latestOpencodeSummary: ""
    property string latestOpencodeBody: ""
    property string latestOpencodeIcon: ""
    property bool latestOpencodeSticky: false

    readonly property int maxHistoryEntries: 120
    readonly property int messageCount: historyList.count
    readonly property int stickyCount: stickyList.count
    // Export one normalized placement contract for notification hosts.
    readonly property string notificationPosition: {
        const value = String(SettingsService.notifications.position || "top-right")
        return ["top-left", "top-right", "bottom-left", "bottom-right"].indexOf(value) >= 0
                ? value : "top-right"
    }
    readonly property bool notificationTop: notificationPosition.indexOf("top-") === 0
    readonly property bool notificationBottom: !notificationTop
    readonly property bool notificationLeft: notificationPosition.indexOf("-left") >= 0
    readonly property bool notificationRight: !notificationLeft

    // Remove transient popups from one deterministic timer owned by the service.
    property Timer popupExpiryTimer: Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            const now = Date.now()
            const timeout = Math.max(0, Number(SettingsService.notifications.timeout) || 0)
            for (let i = root.popupList.count - 1; i >= 0; --i) {
                const entry = root.popupList.get(i)
                if (timeout <= 0 || now - Number(entry.timestamp || 0) >= timeout)
                    root.popupList.remove(i)
            }
        }
    }

    function _normalizedSourceName(appName) {
        return (appName || "").toLowerCase()
    }

    function _defaultStickyForSource(appName) {
        return root._normalizedSourceName(appName) === "opencode"
    }

    function _findHistoryIndex(notifId) {
        for (let i = 0; i < historyList.count; i++) {
            if (historyList.get(i).notifId === notifId)
                return i
        }

        return -1
    }

    function _findStickyIndex(notifId) {
        for (let i = 0; i < stickyList.count; i++) {
            if (stickyList.get(i).notifId === notifId)
                return i
        }

        return -1
    }

    function currentStickyNotification() {
        if (stickyList.count <= 0)
            return null

        const index = Math.max(0, Math.min(stickyCarouselIndex, stickyList.count - 1))
        return stickyList.get(index)
    }

    function latestNotification() {
        if (historyList.count <= 0)
            return null

        return historyList.get(0)
    }

    function advanceStickyCarousel() {
        if (stickyList.count <= 1)
            return

        stickyCarouselIndex = (stickyCarouselIndex + 1) % stickyList.count
    }

    function setStickyCarouselIndex(index) {
        if (stickyList.count <= 0) {
            stickyCarouselIndex = 0
            return
        }

        stickyCarouselIndex = Math.max(0, Math.min(stickyList.count - 1, index))
    }

    function _refreshDerivedState() {
        const latest = root.latestNotification()
        latestAppName = latest ? (latest.appName || "") : ""
        latestSummary = latest ? (latest.summary || "") : ""
        latestBody = latest ? (latest.body || "") : ""
        latestIcon = latest ? (latest.icon || "") : ""

        const currentSticky = root.currentStickyNotification()
        const currentStickyId = currentSticky ? currentSticky.notifId : ""

        stickyList.clear()
        for (let i = 0; i < historyList.count; i++) {
            const entry = historyList.get(i)
            if (entry.sticky) {
                stickyList.append({
                    notifId: entry.notifId,
                    appName: entry.appName || "",
                    sourceName: entry.sourceName || "",
                    summary: entry.summary || "",
                    body: entry.body || "",
                    icon: entry.icon || "",
                    timestamp: entry.timestamp || 0,
                    read: !!entry.read,
                    sticky: !!entry.sticky,
                    defaultSticky: !!entry.defaultSticky
                })
            }
        }

        if (stickyList.count <= 0) {
            stickyCarouselIndex = 0
        } else if (currentStickyId !== "") {
            const retainedIndex = root._findStickyIndex(currentStickyId)
            stickyCarouselIndex = retainedIndex >= 0 ? retainedIndex : Math.min(stickyCarouselIndex, stickyList.count - 1)
        } else {
            stickyCarouselIndex = Math.min(stickyCarouselIndex, stickyList.count - 1)
        }

        for (let i = 0; i < historyList.count; i++) {
            const entry = historyList.get(i)

            if (root._normalizedSourceName(entry.appName) === "opencode") {
                latestOpencodeId = entry.notifId || ""
                latestOpencodeAppName = entry.appName || ""
                latestOpencodeSummary = entry.summary || ""
                latestOpencodeBody = entry.body || ""
                latestOpencodeIcon = entry.icon || ""
                latestOpencodeSticky = !!entry.sticky
                return
            }
        }

        latestOpencodeId = ""
        latestOpencodeAppName = ""
        latestOpencodeSummary = ""
        latestOpencodeBody = ""
        latestOpencodeIcon = ""
        latestOpencodeSticky = false
    }

    function _appendHistoryEntry(entry) {
        if (historyList.count >= maxHistoryEntries) {
            const removed = historyList.get(historyList.count - 1)
            if (removed && !removed.read && unreadCount > 0)
                unreadCount -= 1
            historyList.remove(historyList.count - 1)
        }

        historyList.insert(0, entry)
        unreadCount += 1
        _refreshDerivedState()
    }

    function _updateHistoryEntry(index, entry) {
        historyList.setProperty(index, "appName", entry.appName)
        historyList.setProperty(index, "summary", entry.summary)
        historyList.setProperty(index, "body", entry.body)
        historyList.setProperty(index, "icon", entry.icon)
        historyList.setProperty(index, "timestamp", entry.timestamp)
        historyList.setProperty(index, "read", entry.read)
        historyList.setProperty(index, "sticky", entry.sticky)
        historyList.setProperty(index, "sourceName", entry.sourceName)
        historyList.setProperty(index, "defaultSticky", entry.defaultSticky)
        _refreshDerivedState()
    }

    function recordNotification(n) {
        summaryDismissed = false

        const sourceName = root._normalizedSourceName(n.appName || n.desktopEntry || "")
        const entry = {
            notifId: n.id,
            appName: n.appName || n.desktopEntry || "",
            sourceName: sourceName,
            summary: n.summary || "",
            body: n.body || "",
            icon: n.appIcon || n.image || "",
            timestamp: Date.now(),
            read: false,
            sticky: root._defaultStickyForSource(sourceName),
            defaultSticky: root._defaultStickyForSource(sourceName)
        }

        const existingIndex = root._findHistoryIndex(entry.notifId)

        if (existingIndex >= 0) {
            const existing = historyList.get(existingIndex)
            entry.read = existing.read === undefined ? false : !!existing.read
            entry.sticky = existing.sticky === undefined ? entry.sticky : !!existing.sticky
            entry.defaultSticky = existing.defaultSticky === undefined ? entry.defaultSticky : !!existing.defaultSticky
            root._updateHistoryEntry(existingIndex, entry)
        } else {
            root._appendHistoryEntry(entry)
        }
    }

    function removeNotification(notifId) {
        for (let i = 0; i < popupList.count; i++) {
            if (popupList.get(i).notifId === notifId) {
                popupList.remove(i)
                return
            }
        }
    }

    // Expose the popup-specific dismissal contract used by notification hosts.
    function dismissPopup(notifId) {
        removeNotification(notifId)
    }

    function setSticky(notifId, sticky) {
        const index = root._findHistoryIndex(notifId)
        if (index < 0)
            return

        historyList.setProperty(index, "sticky", !!sticky)
        _refreshDerivedState()
    }

    function clearStickyNotifications() {
        let changed = false

        for (let i = 0; i < historyList.count; i++) {
            const entry = historyList.get(i)
            if (!entry.sticky)
                continue

            historyList.setProperty(i, "sticky", false)
            changed = true
        }

        if (!changed)
            summaryDismissed = true
        else
            summaryDismissed = true

        stickyCarouselIndex = 0
        _refreshDerivedState()
    }

    function toggleSticky(notifId) {
        const index = root._findHistoryIndex(notifId)
        if (index < 0)
            return

        root.setSticky(notifId, !historyList.get(index).sticky)
    }

    function markRead(notifId) {
        const index = root._findHistoryIndex(notifId)
        if (index < 0)
            return

        const entry = historyList.get(index)
        if (entry.read)
            return

        historyList.setProperty(index, "read", true)
        unreadCount = Math.max(0, unreadCount - 1)
    }

    function markAllRead() {
        if (unreadCount <= 0)
            return

        for (let i = 0; i < historyList.count; i++) {
            if (!historyList.get(i).read)
                historyList.setProperty(i, "read", true)
        }

        unreadCount = 0
    }

    function latestNotificationForSource(sourceName) {
        const normalized = root._normalizedSourceName(sourceName)

        for (let i = 0; i < historyList.count; i++) {
            const entry = historyList.get(i)
            if (root._normalizedSourceName(entry.appName) === normalized)
                return entry
        }

        return null
    }

    property NotificationServer _server: NotificationServer {
        onNotification: n => {
            root.recordNotification(n)

            if (root.dndEnabled)
                return

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
