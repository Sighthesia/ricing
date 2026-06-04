pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services

// Manages launcher visibility, query input, and mode derivation.
// Now delegates to IslandService for the primary toggle path.
Singleton {
    id: root

    readonly property bool visible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "launcher"
    property string query: ""

    // Derived mode based on query prefix.
    readonly property string mode: {
        if (query.startsWith(">clip ")) return "clipboard"
        if (query.startsWith(">key ")) return "shortcuts"
        return "apps"
    }

    Component.onCompleted: NiriService.syncManagedHotkeys()

    function open() { Services.IslandService.showLauncher() }
    function close() {
        Services.IslandService.close()
        query = ""
    }
    function toggle() {
        if (visible)
            Services.IslandService.close()
        else
            Services.IslandService.showLauncher()
    }

    function openClipboard() {
        Services.IslandService.query = ">clip "
        Services.IslandService.showLauncher()
    }
    function openShortcuts() {
        Services.IslandService.query = ">key "
        Services.IslandService.showLauncher()
    }

    // IPC surface for niri keybind integration.
    IpcHandler {
        target: "launcher"
        function toggle() { LauncherService.toggle() }
        function openClipboard() { LauncherService.openClipboard() }
        function openShortcuts() { LauncherService.openShortcuts() }
    }
}
