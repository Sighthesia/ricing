pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Island state owner: expanded/collapsed toggle, query input, and mode derivation.
Singleton {
    id: root

    property bool expanded: false
    property string query: ""

    // Derived mode based on query prefix (mirrors LauncherService convention).
    readonly property string mode: {
        if (query.startsWith(">clip ")) return "clipboard"
        return "apps"
    }

    function open() {
        expanded = true
    }

    function close() {
        expanded = false
        query = ""
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
