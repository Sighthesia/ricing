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

    function close() {
        expanded = false
        _closeTimer.restart()
    }

    function toggle() {
        if (expanded) close()
        else open()
    }

    // IPC surface for niri keybind integration.
    IpcHandler {
        target: "island"
        function toggle() { root.toggle() }
        function open() { root.open() }
        function close() { root.close() }
    }
}
