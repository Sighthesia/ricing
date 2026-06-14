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
    property string panelPage: "launcher"
    property var centerSurfaceWidths: ({})
    readonly property int ripplePulseToken: Services.RipplePulseService.token

    // Window-hint extension is active only in attached-island mode while the
    // hint is held; floating-capsule mode leaves the island untouched.
    readonly property bool windowHintActive: Services.SettingsService.appearance.windowHintMode === "attached-island"
        && Services.WindowHintService.hintVisible

    // Source driving the island's open geometry. Launcher takes priority over
    // the window hint when both want to expand.
    readonly property string expansionSource: expanded
        ? "launcher"
        : (windowHintActive ? "windowHint" : "none")

    // Derived mode based on query prefix (mirrors LauncherService convention).
    readonly property string mode: {
        if (query.startsWith(">clip ")) return "clipboard"
        return "apps"
    }

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
        expanded = true
    }

    function openPage(page) {
        if (page)
            panelPage = page

        open()
    }

    function showLauncher() {
        openPage("launcher")
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
        showLauncher()
    }

    function openShortcuts() {
        query = ">key "
        showLauncher()
    }

    function close() {
        expanded = false
        _closeTimer.restart()
    }

    onExpandedChanged: {
        if (expanded
            && panelPage !== "launcher"
            && panelPage !== "settings-center"
            && panelPage !== "notifications")
            panelPage = "launcher"
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
