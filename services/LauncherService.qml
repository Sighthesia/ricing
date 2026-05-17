pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Manages launcher visibility, query input, and mode derivation.
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
    function toggle() { visible ? close() : open() }

    function openClipboard() { query = ">clip "; open() }
    function openShortcuts() { query = ">key "; open() }

    // IPC surface for niri keybind integration.
    IpcHandler {
        target: "launcher"
        function toggle() { LauncherService.toggle() }
        function openClipboard() { LauncherService.openClipboard() }
        function openShortcuts() { LauncherService.openShortcuts() }
    }
}
