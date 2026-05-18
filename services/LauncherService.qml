pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Manages launcher visibility, query input, and mode derivation.
// Now delegates to IslandService for the primary toggle path.
Singleton {
    id: root

    property bool visible: false
    property string query: ""

    // Derived mode based on query prefix.
    readonly property string mode: {
        if (query.startsWith(">clip ")) return "clipboard"
        if (query.startsWith(">key ")) return "shortcuts"
        return "apps"
    }

    Component.onCompleted: NiriService.syncManagedHotkeys()

    function open() { visible = true }
    function close() { visible = false; query = "" }
    function toggle() { IslandService.toggle() }

    function openClipboard() { IslandService.query = ">clip "; IslandService.open() }
    function openShortcuts() { query = ">key "; open() }

    // IPC surface for niri keybind integration.
    IpcHandler {
        target: "launcher"
        function toggle() { LauncherService.toggle() }
        function openClipboard() { LauncherService.openClipboard() }
        function openShortcuts() { LauncherService.openShortcuts() }
    }
}
