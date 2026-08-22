pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "launcher"

// Standalone launcher entry point: owns the niri keybind IPC surface and
// re-exposes the LauncherSession state machine. Launcher visibility, query,
// mode, results, and execution outcomes live entirely in this service; no
// Island state is read or written.
Singleton {
    id: root

    // Quickshell-free session core (unit tested directly under qmltestrunner).
    LauncherSession {
        id: session
    }

    // Observable session state.
    readonly property alias visible: session.visible
    property alias query: session.query
    readonly property alias mode: session.mode
    property alias results: session.results
    readonly property alias loading: session.loading
    readonly property alias error: session.error
    readonly property alias selectedIndex: session.selectedIndex

    function open() { return session.open() }
    function close() { return session.close() }
    function toggle() { return session.toggle() }
    function refresh() { return session.refresh() }
    function selectNext() { return session.selectNext() }
    function selectPrevious() { return session.selectPrevious() }
    function executeSelected() { return session.executeSelected() }
    function execute(item) { return session.execute(item) }
    function openClipboard() { return session.openClipboard() }
    function openShortcuts() { return session.openShortcuts() }

    // IPC surface for the launcher entry and niri keybind integration.
    IpcHandler {
        target: "launcher"
        function toggle() { root.toggle() }
        function openClipboard() { root.openClipboard() }
        function openShortcuts() { root.openShortcuts() }
    }
}
