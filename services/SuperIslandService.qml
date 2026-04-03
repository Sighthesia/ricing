pragma Singleton

import Quickshell
import QtQuick
import qs.config
import qs.services

Singleton {
    id: root

    readonly property bool _debugLogging: false
    readonly property bool overlayVisible:
        IslandOverlayService.mode !== "none"
        && IslandOverlayService.state !== "closed"

    property var mainState: _idleEvent()
    property var flashEvent: ({})
    readonly property bool flashVisible: (activeEvent.id || "") !== ""

    property string mode: "idle"
    property var activeEvent: _idleEvent()

    readonly property int queueLength: _queue.length
    readonly property bool hasPendingEvents: queueLength > 0

    property var _queue: []
    property var _baselineState: ({})
    property var _snoozedGroups: ({})
    property bool _suppressExternalSources: false
    property string _lastNotificationId: ""
    property string _lastWorkspaceId: ""
    property string _lastFocusedWindowId: ""
    property string _lastMediaSignature: ""

    Timer {
        id: _activeTimer
        repeat: false
        onTriggered: root._finishTransient()
    }

    Timer {
        id: _pendingStartTimer
        interval: Theme.anim.moveDuration + 40
        repeat: false
        onTriggered: {
            if (root.activeEvent.type !== "idle" || root._queue.length === 0)
                return

            const next = root._queue[0]
            root._queue = []
            root._activateEvent(next)
        }
    }

    function _log(message, event) {
        if (!root._debugLogging)
            return

        if (!event) {
            console.log("SuperIslandService:", message)
            return
        }

        console.log(
            "SuperIslandService:", message,
            "id=", event.id || "",
            "type=", event.type || "",
            "priority=", event.priority || "",
            "groupKey=", event.groupKey || "",
            "title=", event.title || "",
            "subtitle=", event.subtitle || ""
        )
    }

    function _settings() {
        return SettingsService.data.superIsland || {
            enabled: true,
            defaultTimeout: 1500,
            importantTimeout: 1500,
            criticalTimeout: 1500,
            workspaceTimeout: 1500,
            notificationTimeout: 1500,
            mediaTimeout: 1500,
            maxQueue: 1,
            showMedia: true,
            showNotifications: true,
            showWorkspaceEvents: true
        }
    }

    function pushEvent(event) {
        if (!root._settings().enabled)
            return

        const normalized = root._normalizeEvent(event)
        if (!normalized || !root._isEventEnabled(normalized.type) || root._isSnoozed(normalized.groupKey))
            return

        root._routeEvent(normalized)
    }

    function showWindowHint(hint) {
        if (!root._settings().enabled || !hint || !hint.visible)
            return

        // Keep overlay sessions as the sole owner of SuperIsland geometry/state.
        if (root.overlayVisible)
            return

        const event = root._normalizeEvent({
            id: "window-hint",
            type: "window-hint",
            groupKey: "window-hint",
            priority: "important",
            title: hint.currentWindowTitle || "Window hint",
            subtitle: "",
            icon: hint.currentWindowIcon || "",
            workspaceLabel: hint.workspaceIndex > 0 ? hint.workspaceIndex.toString() : "",
            timeoutMs: 0,
            sticky: true,
            revision: hint.revision || 0
        })

        if (!event)
            return

        if (root.activeEvent.type === "window-hint") {
            root._log("updateWindowHint", event)
            root.activeEvent = event
            root.flashEvent = event
            root.mode = "hint"
            return
        }

        root._log("showWindowHint", event)
        _activeTimer.stop()
        _pendingStartTimer.stop()
        root.activeEvent = event
        root.flashEvent = event
        root.mode = "hint"
        root.mainState = root._resolveBaselineState()
    }

    function hideWindowHint() {
        if (root.activeEvent.type !== "window-hint")
            return

        root._log("hideWindowHint", root.activeEvent)
        _activeTimer.stop()
        _pendingStartTimer.stop()

        if (root._queue.length > 0) {
            const next = root._queue[0]
            root._queue = []
            root._activateEvent(next)
            return
        }

        root.activeEvent = root._idleEvent()
        root.flashEvent = ({})
        root.mode = "idle"
        root.mainState = root._resolveBaselineState()
    }

    function replaceEvent(groupKey, event) {
        const mergedEvent = {}
        for (let key in event)
            mergedEvent[key] = event[key]
        mergedEvent.groupKey = groupKey

        const normalized = root._normalizeEvent(mergedEvent)
        if (!normalized || !root._isEventEnabled(normalized.type) || root._isSnoozed(groupKey))
            return

        root._routeEvent(normalized)
    }

    function clearEvent(id) {
        if (!id)
            return

        if (root.activeEvent.id === id)
            root._finishTransient()

        if (root._queue.length > 0 && root._queue[0].id === id)
            root._queue = []
    }

    function snoozeGroup(groupKey, ms) {
        if (!groupKey)
            return

        root._snoozedGroups[groupKey] = Date.now() + Math.max(ms || 0, 0)
    }

    function _timeoutForPriority(priority) {
        const settings = root._settings()
        if (priority === "critical")
            return settings.criticalTimeout
        if (priority === "important")
            return settings.importantTimeout
        return settings.defaultTimeout
    }

    function _timeoutForNotification(urgency) {
        const n = SettingsService.data.notifications || {}
        const lowMs = n.lowDuration !== undefined ? n.lowDuration : 3000
        const normalMs = n.normalDuration !== undefined ? n.normalDuration : 5000
        const criticalMs = n.criticalDuration !== undefined ? n.criticalDuration : 0

        if (urgency === 0) return lowMs
        if (urgency === 2) return criticalMs
        return normalMs
    }

    function _timeoutForEvent(event) {
        const settings = root._settings()
        if (!event || !event.type)
            return settings.defaultTimeout

        if (event.type === "notification") {
            const urgency = event.urgency !== undefined ? event.urgency : 1
            const result = root._timeoutForNotification(urgency)
            if (result !== undefined && result !== null)
                return result
            return settings.notificationTimeout || settings.defaultTimeout
        }

        if (event.type === "media")
            return settings.mediaTimeout || settings.defaultTimeout

        if (event.type === "workspace" || event.type === "window")
            return settings.workspaceTimeout || settings.defaultTimeout

        return root._timeoutForPriority(event.priority)
    }

    function _overlayEvent(mode) {
        const overlayMode = mode === "settings"
            ? "settings"
            : (mode === "notifications" ? "notifications" : "launcher")

        return {
            id: "overlay:" + overlayMode,
            type: "overlay",
            groupKey: "overlay",
            priority: "important",
            title: overlayMode === "settings"
                ? "设置"
                : (overlayMode === "notifications" ? "通知中心" : "启动器"),
            subtitle: "",
            icon: overlayMode === "settings"
                ? "preferences-system"
                : (overlayMode === "notifications"
                    ? "preferences-system-notifications"
                    : "system-search"),
            timeoutMs: 24 * 60 * 60 * 1000
        }
    }

    function _isEventEnabled(type) {
        const settings = root._settings()
        if (type === "media")
            return settings.showMedia
        if (type === "notification")
            return settings.showNotifications
        if (type === "workspace" || type === "window")
            return settings.showWorkspaceEvents
        return true
    }

    function _reconcileVisibilitySettings() {
        const nextQueue = []
        for (let index = 0; index < root._queue.length; index++) {
            const queuedEvent = root._queue[index]
            if (root._isEventEnabled(queuedEvent.type))
                nextQueue.push(queuedEvent)
        }
        root._queue = nextQueue

        if (root.activeEvent.type !== "idle" && !root._isEventEnabled(root.activeEvent.type))
            root._finishTransient()
    }

    function _idleEvent() {
        return {
            id: "",
            type: "idle",
            groupKey: "idle",
            priority: "passive",
            presentation: "baseline",
            title: "",
            subtitle: "",
            icon: "",
            workspaceLabel: "",
            timeoutMs: 0,
            timestamp: 0
        }
    }

    function _defaultPresentation(eventType) {
        if (eventType === "idle")
            return "baseline"
        return "transient"
    }

    function _normalizeEvent(event) {
        if (!event)
            return null

        const priority = event.priority || "important"
        const type = event.type || "notification"
        const normalized = {
            id: event.id || type + ":" + Date.now(),
            type: type,
            groupKey: event.groupKey || type,
            priority: priority,
            presentation: event.presentation || root._defaultPresentation(type),
            title: event.title || "",
            subtitle: event.subtitle || "",
            icon: event.icon || "",
            workspaceLabel: event.workspaceLabel || "",
            urgency: event.urgency,
            sticky: !!event.sticky,
            revision: event.revision || 0,
            timestamp: Date.now()
        }

        if (event.timeoutMs !== undefined && event.timeoutMs !== null)
            normalized.timeoutMs = event.timeoutMs
        else
            normalized.timeoutMs = root._timeoutForEvent(normalized)

        return normalized
    }

    function _routeEvent(event) {
        root._log("routeEvent", event)

        if (root.activeEvent.type === "window-hint" && event.type !== "window-hint") {
            root._queue = [event]
            return
        }

        if (event.presentation === "baseline") {
            root._baselineState = event
            if (root.activeEvent.type === "idle")
                root.mainState = root._resolveBaselineState()
            return
        }

        if (event.type === "window" && root.activeEvent.type !== "idle" && root.activeEvent.type !== "window")
            return

        if (root.activeEvent.type === "window" && event.type !== "window") {
            root._queue = []
            root._activateEvent(event)
            return
        }

        if (event.groupKey === "window-focus" && root.activeEvent.groupKey === "window-focus") {
            root._activateEvent(event)
            return
        }

        if (root.activeEvent.type !== "idle") {
            root._queue = [event]
            return
        }

        root._activateEvent(event)
    }

    function _syncOverlayState() {
        if (root.overlayVisible) {
            const nextOverlayEvent = root._normalizeEvent(root._overlayEvent(IslandOverlayService.mode))
            const currentIsOverlay = root.activeEvent.groupKey === "overlay"

            root._suppressExternalSources = true

            if (currentIsOverlay && root.activeEvent.id === nextOverlayEvent.id)
                return

            _activeTimer.stop()
            _pendingStartTimer.stop()
            root.activeEvent = nextOverlayEvent
            root.flashEvent = nextOverlayEvent
            root.mode = "hint"
            root.mainState = root._resolveBaselineState()
            return
        }

        root._suppressExternalSources = false

        if (root.activeEvent.groupKey !== "overlay")
            return

        _activeTimer.stop()
        root.activeEvent = root._idleEvent()
        root.flashEvent = ({})
        root.mode = "idle"
        root.mainState = root._resolveBaselineState()

        if (root._queue.length > 0)
            _pendingStartTimer.restart()
    }

    function _resolveBaselineState() {
        if (root._baselineState && root._baselineState.presentation === "baseline")
            return root._baselineState
        return root._idleEvent()
    }

    function _activateEvent(event) {
        root._log("activateEvent", event)
        root.activeEvent = event
        root.flashEvent = event
        root.mode = "hint"
        root.mainState = root._resolveBaselineState()

        _pendingStartTimer.stop()
        _activeTimer.stop()
        _activeTimer.interval = event.timeoutMs > 0 ? event.timeoutMs : root._settings().defaultTimeout
        _activeTimer.restart()
    }

    function _finishTransient() {
        root._log("finishTransient", root.activeEvent)

        if (root._queue.length > 0) {
            const next = root._queue[0]
            const relayEvent = {}
            for (let key in next)
                relayEvent[key] = next[key]
            relayEvent.relayReplace = true
            root._queue = []
            root._activateEvent(relayEvent)
            return
        }

        _activeTimer.stop()
        root.activeEvent = root._idleEvent()
        root.flashEvent = ({})
        root.mode = "idle"
        root.mainState = root._resolveBaselineState()

        if (root._queue.length > 0)
            _pendingStartTimer.restart()
    }

    function _isSnoozed(groupKey) {
        if (!groupKey)
            return false

        const until = root._snoozedGroups[groupKey] || 0
        if (until <= Date.now()) {
            delete root._snoozedGroups[groupKey]
            return false
        }
        return true
    }

    function _activeWorkspace() {
        for (let index = 0; index < NiriService.workspaces.count; index++) {
            const workspace = NiriService.workspaces.get(index)
            if (workspace.isActive)
                return workspace
        }
        return null
    }

    function _workspaceIndexForId(workspaceId) {
        for (let index = 0; index < NiriService.workspaces.count; index++) {
            const workspace = NiriService.workspaces.get(index)
            if (workspace.wsId === workspaceId)
                return workspace.idx
        }
        return -1
    }

    function _focusedWindow() {
        for (let index = 0; index < NiriService.windows.count; index++) {
            const window = NiriService.windows.get(index)
            if (window.isFocused)
                return window
        }
        return null
    }

    function _iconPathForApp(appId) {
        if (!appId)
            return Quickshell.iconPath("application-x-executable")

        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable")

        return Quickshell.iconPath("application-x-executable")
    }

    function _mediaIcon() {
        if (MediaService.artUrl)
            return MediaService.artUrl
        if (MediaService.desktopEntry)
            return Quickshell.iconPath(MediaService.desktopEntry, "audio-x-generic")
        return Quickshell.iconPath("audio-x-generic")
    }

    function _focusedWindowEvent(window) {
        if (!window)
            return null

        const workspaceIndex = root._workspaceIndexForId(window.workspaceId)
        return {
            id: "window:" + window.winId,
            type: "window",
            groupKey: "window-focus",
            priority: "important",
            title: window.title || window.appId,
            subtitle: window.appId || "Focused window",
            icon: root._iconPathForApp(window.appId),
            workspaceLabel: workspaceIndex > 0 ? workspaceIndex.toString() : "",
            timeoutMs: root._settings().workspaceTimeout
        }
    }

    Connections {
        target: SettingsService.data.superIsland

        function onShowMediaChanged() { root._reconcileVisibilitySettings() }
        function onShowNotificationsChanged() { root._reconcileVisibilitySettings() }
        function onShowWorkspaceEventsChanged() { root._reconcileVisibilitySettings() }
    }

    Connections {
        target: IslandOverlayService

        function onModeChanged() { root._syncOverlayState() }
        function onStateChanged() { root._syncOverlayState() }
    }

    Connections {
        target: NotificationService.activeList
        function onCountChanged() {
            if (root._suppressExternalSources || !root._settings().showNotifications)
                return

            if (NotificationService.activeList.count <= 0)
                return

            const item = NotificationService.activeList.get(0)
            if (!item || item.id === root._lastNotificationId)
                return

            root._lastNotificationId = item.id
            root.pushEvent({
                id: "notification:" + item.id,
                type: "notification",
                groupKey: "notification",
                priority: item.urgency === 2 ? "critical" : "important",
                urgency: item.urgency !== undefined ? item.urgency : 1,
                title: (item.summary || item.appName || "Notification").replace(/\n/g, " "),
                subtitle: (item.body || "").replace(/\n/g, " "),
                icon: item.appIcon || "preferences-system-notifications"
            })
        }
    }

    Connections {
        target: NiriService
        function onWorkspaceActivated() {
            if (root._suppressExternalSources || !root._settings().showWorkspaceEvents)
                return

            const workspace = root._activeWorkspace()
            if (!workspace || workspace.wsId === root._lastWorkspaceId)
                return

            root._lastWorkspaceId = workspace.wsId

            const focusedWindow = root._focusedWindow()
            const event = root._focusedWindowEvent(focusedWindow)
            if (event)
                root.replaceEvent("window-focus", event)
        }

        function onWindowsUpdated() {
            if (root._suppressExternalSources || !root._settings().showWorkspaceEvents)
                return

            const focusedWindow = root._focusedWindow()
            if (!focusedWindow || focusedWindow.winId === root._lastFocusedWindowId)
                return

            root._lastFocusedWindowId = focusedWindow.winId
            const event = root._focusedWindowEvent(focusedWindow)
            if (event)
                root.replaceEvent("window-focus", event)
        }
    }

    Connections {
        target: MediaService
        function onMediaChanged() {
            if (root._suppressExternalSources || !root._settings().showMedia)
                return

            if (!MediaService.hasPlayer)
                return

            const signature = [
                MediaService.playerName,
                MediaService.title,
                MediaService.artist,
                MediaService.playbackState
            ].join("|")

            if (signature === root._lastMediaSignature)
                return

            root._lastMediaSignature = signature
            root.replaceEvent("media", {
                id: "media:" + signature,
                type: "media",
                priority: "important",
                title: MediaService.title || MediaService.playerName || "Media",
                subtitle: MediaService.artist || MediaService.playbackState,
                icon: root._mediaIcon(),
                urgency: 1
            })
        }
    }
}
