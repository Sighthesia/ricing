.pragma library

function syncNotificationHistoryFromOverlay(mode, state, currentNotificationHistoryOpen) {
    var shouldShowNotifications = mode === "notifications" && state !== "closed"

    return {
        changed: currentNotificationHistoryOpen !== shouldShowNotifications,
        notificationHistoryOpen: shouldShowNotifications
    }
}

function panelStateFromOverlay(mode, currentActivePanel) {
    if (mode === "settings") {
        if (currentActivePanel === "config") {
            return {
                changed: false,
                activePanel: currentActivePanel
            }
        }

        return {
            changed: true,
            activePanel: "config"
        }
    }

    if (currentActivePanel !== "config") {
        return {
            changed: false,
            activePanel: currentActivePanel
        }
    }

    return {
        changed: true,
        activePanel: "none"
    }
}

function panelCloseFromOverlayState(mode, state, currentActivePanel) {
    var shouldClosePanel = mode === "settings"
        && state === "closed"
        && currentActivePanel === "config"

    return {
        shouldClosePanel: shouldClosePanel,
        activePanel: shouldClosePanel ? "none" : currentActivePanel
    }
}
