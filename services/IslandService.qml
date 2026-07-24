pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services

// Island state owner: expanded/collapsed toggle, query input, and mode derivation.
Singleton {
    id: root

    property bool expanded: false
    property string query: ""
    property string panelPage: "overview"
    property real clipboardPreviewWidth: 0
    property var centerSurfaceWidths: ({})
    property var centerHoverStates: ({})
    // Pre-filter text for the settings center when opened from a search
    // result. Set before showSettingsCenter() and consumed once by
    // SettingsContent on load, then reset.
    property string settingsInitialFilter: ""
    readonly property int ripplePulseToken: Services.RipplePulseService.token

    // Window-hint extension is active only in attached-island mode while the
    // hint is held; floating-capsule mode leaves the island untouched.
    readonly property bool windowHintActive: Services.SettingsService.appearance.windowHintMode === "attached-island"
        && Services.WindowHintService.hintVisible

    // Source driving the island's open geometry. Launcher takes priority over
    // the window hint when both want to expand.
    readonly property string expansionSource: expanded
        ? "island"
        : (windowHintActive ? "windowHint" : "none")

    // Derived mode based on query prefix (mirrors LauncherService convention).
    readonly property string mode: {
        if (query.startsWith(">clip ")) return "clipboard"
        return "apps"
    }
    readonly property bool launcherDetailActive: query.trim().length > 0
        || panelPage === "launcher"

    function setCenterSurfaceWidth(screenName, width) {
        var nextWidths = Object.assign({}, centerSurfaceWidths)

        if (screenName && width > 0)
            nextWidths[screenName] = width
        else if (screenName)
            delete nextWidths[screenName]

        centerSurfaceWidths = nextWidths
    }

    function centerSurfaceWidthFor(screenName) {
        if (!screenName)
            return 0

        return centerSurfaceWidths[screenName] || 0
    }

    function setCenterHover(screenName, hovered) {
        var nextStates = Object.assign({}, centerHoverStates)

        if (screenName)
            nextStates[screenName] = !!hovered

        centerHoverStates = nextStates
    }

    function centerHoverFor(screenName) {
        return !!(screenName && centerHoverStates[screenName])
    }

    function triggerRipplePulse() {
        if (!Services.SettingsService.appearance.ripplePulseEnabled)
            return

        Services.RipplePulseService.trigger()
    }

    // Delay query reset so mode stays stable during the collapse animation.
    property Timer _closeTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: root.query = ""
    }

    function open() {
        _closeTimer.stop()
        if (query.trim().length > 0)
            panelPage = "launcher"
        else if (panelPage !== "settings-center" && panelPage !== "notifications" && panelPage !== "media" && panelPage !== "calendar" && panelPage !== "weather")
            panelPage = "overview"

        expanded = true
    }

    function openPage(page) {
        if (page)
            panelPage = page

        open()
    }

    function showOverview() {
        openPage("overview")
    }

    function showLauncher() {
        openPage(query.trim().length > 0 ? "launcher" : "overview")
    }

    function showSettingsCenter() {
        openPage("settings-center")
    }

    function showNotifications() {
        Services.NotificationService.markAllRead()
        Services.NotificationService.clearStickyNotifications()
        openPage("notifications")
    }

    function openClipboard() {
        query = ">clip "
        openPage("launcher")
    }

    function openShortcuts() {
        query = ">key "
        openPage("launcher")
    }

    function close() {
        expanded = false
        panelPage = "overview"
        clipboardPreviewWidth = 0
        _closeTimer.restart()
    }

    onExpandedChanged: {
        if (expanded
            && panelPage !== "overview"
            && panelPage !== "launcher"
            && panelPage !== "settings-center"
            && panelPage !== "notifications"
            && panelPage !== "media"
            && panelPage !== "calendar"
            && panelPage !== "weather")
            panelPage = "overview"
    }

    onQueryChanged: {
        if (!expanded)
            return

        if (query.trim().length > 0) {
            if (panelPage === "overview")
                panelPage = "launcher"
        } else if (panelPage === "launcher") {
            panelPage = "overview"
        }
    }

    function toggle() {
        if (expanded) close()
        else open()
    }

    // IPC surface for niri keybind integration.
    IpcHandler {
        target: "launcher"
        function toggle() { root.toggle() }
        function open() { root.open() }
        function close() { root.close() }
        function openClipboard() { root.openClipboard() }
        function openShortcuts() { root.openShortcuts() }
    }

    // New IPC target used by the refactored island launcher flow.
    IpcHandler {
        target: "island"
        function toggle() { root.toggle() }
        function open() { root.open() }
        function close() { root.close() }
        function openClipboard() { root.openClipboard() }
        function openShortcuts() { root.openShortcuts() }
    }
}
