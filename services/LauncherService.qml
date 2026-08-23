pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services
import "launcher"
import "launcher/LauncherAdapters.js" as LauncherAdapters

// Standalone launcher entry point: owns the niri keybind IPC surface and
// re-exposes the LauncherSession state machine. Launcher visibility, query,
// mode, results, and execution outcomes live entirely in this service; no
// Island state is read or written.
Singleton {
    id: root

    // Production data-source adapters installed on the session seam: real
    // desktop-entry applications, cliphist clipboard history, and niri
    // shortcut binds. Unavailable sources resolve to explicit errors.
    readonly property var _adapters: LauncherAdapters.createAdapters({
        appsSource: DesktopEntries.applications,
        launchCounts: Services.LaunchCountService,
        clipboardBackend: Services.ClipboardService,
        shortcutsBackend: Services.NiriShortcutService,
        iconResolver: function(name) { return name ? String(Quickshell.iconPath(name, true)) : "" },
        ipcHelperPath: Quickshell.shellDir + "/scripts/afloat-ipc",
        actionRunner: root._runShortcutAction
    })

    // Quickshell populates the desktop-entry model lazily; holding a live
    // binding keeps the scan materialized so launcher queries see entries.
    readonly property int _desktopEntryCount: DesktopEntries.applications.values.length

    // Re-query apps when entries arrive while the launcher is already open,
    // so an early open cannot strand the user on an empty result set. The
    // scan reports every entry individually; coalesce the storm into one
    // refresh instead of committing a growing pool per entry.
    Timer {
        id: entryScanRefreshTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (session.visible && session.mode === "apps" && !session.loading)
                session.refresh()
        }
    }
    on_DesktopEntryCountChanged: entryScanRefreshTimer.restart()

    // Quickshell-free session core (unit tested directly under qmltestrunner).
    LauncherSession {
        id: session
        _adapters: root._adapters
    }

    // Observable session state.
    readonly property alias visible: session.visible
    property alias query: session.query
    readonly property alias mode: session.mode
    property alias results: session.results
    // Stable per-mode pool the surface renders; text filtering is local.
    property alias displayPool: session.displayPool
    readonly property alias loading: session.loading
    readonly property alias error: session.error
    readonly property alias selectedIndex: session.selectedIndex

    // Completion callback of the most recently started shortcut action.
    property var _shortcutDone: null

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

    // Runs one shortcut-action command at a time through a dedicated process
    // and reports its exit outcome; overlapping runs are rejected so outcomes
    // stay paired with their requests.
    function _runShortcutAction(argv, done) {
        if (typeof done !== "function")
            return
        if (!argv || !argv.length) {
            done({ ok: false, error: "no command given" })
            return
        }
        if (_shortcutProc.running || _shortcutDone) {
            done({ ok: false, error: "another action is still running" })
            return
        }
        _shortcutDone = done
        var command = []
        for (var index = 0; index < argv.length; index++)
            command.push(String(argv[index]))
        _shortcutProc.command = command
        _shortcutProc.running = true
    }

    // IPC surface for the launcher entry and niri keybind integration.
    IpcHandler {
        target: "launcher"
        function toggle() { root.toggle() }
        function openClipboard() { root.openClipboard() }
        function openShortcuts() { root.openShortcuts() }
    }

    Process {
        id: _shortcutProc
        command: []
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: exitCode => {
            var done = root._shortcutDone
            root._shortcutDone = null
            if (typeof done !== "function")
                return
            if (exitCode === 0)
                done({ ok: true })
            else
                done({ ok: false, error: "action exited with code " + exitCode })
        }
    }
}
