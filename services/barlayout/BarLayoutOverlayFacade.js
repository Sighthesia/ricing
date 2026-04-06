.pragma library

.import "BarLayoutOverlaySync.js" as OverlaySyncUtils

function _applyNotificationHistory(root, nextNotificationHistoryOpen) {
    root._suppressNotificationHistoryMirror = true
    root.notificationHistoryOpen = nextNotificationHistoryOpen
    root._suppressNotificationHistoryMirror = false
}

function _applyActivePanel(root, nextActivePanel) {
    root._suppressPanelMirror = true
    root.activePanel = nextActivePanel
    root._suppressPanelMirror = false
}

function mirrorPanelToOverlay(root, overlayService) {
    if (root._suppressPanelMirror)
        return false

    if (root.activePanel === "config") {
        overlayService.openOverlay("settings", {
            source: "bar-panel"
        })
        return true
    }

    if (root.activePanel !== "config" && overlayService.mode === "settings" && overlayService.state !== "closed") {
        overlayService.closeOverlay("bar-panel")
        return true
    }

    return false
}

function mirrorNotificationHistoryToOverlay(root, overlayService) {
    if (root._suppressNotificationHistoryMirror)
        return false

    if (root.notificationHistoryOpen) {
        overlayService.openOverlay("notifications", {
            source: "notification-bell"
        })
        return true
    }

    if (overlayService.mode === "notifications" && overlayService.state !== "closed") {
        overlayService.closeOverlay("notification-bell")
        return true
    }

    return false
}

function syncNotificationHistoryFromOverlay(root, overlayService) {
    var result = OverlaySyncUtils.syncNotificationHistoryFromOverlay(
        overlayService.mode,
        overlayService.state,
        root.notificationHistoryOpen
    )
    if (!result.changed)
        return false

    _applyNotificationHistory(root, result.notificationHistoryOpen)
    return true
}

function syncPanelCloseFromOverlayState(root, overlayService) {
    var result = OverlaySyncUtils.panelCloseFromOverlayState(
        overlayService.mode,
        overlayService.state,
        root.activePanel
    )
    if (!result.shouldClosePanel)
        return false

    _applyActivePanel(root, result.activePanel)
    return true
}

function syncPanelStateFromOverlay(root, overlayService) {
    var result = OverlaySyncUtils.panelStateFromOverlay(overlayService.mode, root.activePanel)
    if (!result.changed)
        return false

    _applyActivePanel(root, result.activePanel)
    return true
}
