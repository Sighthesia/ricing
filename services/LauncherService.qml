pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services
import "launcher"
import "launcher/LauncherAdapters.js" as LauncherAdapters
import "launcher/LauncherCategories.js" as LauncherCategories

// Standalone launcher entry point: owns the niri keybind IPC surface and
// re-exposes the LauncherSession state machine. Launcher visibility, query,
// mode, results, and execution outcomes live entirely in this service; no
// Island state is read or written.
Singleton {
    id: root

    // Gap between result batches. Short enough that the tail of a 750-row
    // history lands within a few frames of the head, long enough that the
    // list actually paints between batches instead of growing behind a
    // stalled frame. Not a motion token: this paces a data pipeline, not an
    // animation.
    readonly property int batchInterval: 8
    // One step per tick, queued rather than replaced: a visible list and a
    // background read (the clipboard metadata merge) can stream at the same
    // time, and a shared slot would starve whichever arrived second.
    property var _batchQueue: []
    Timer {
        id: batchTimer
        interval: root.batchInterval
        repeat: false
        onTriggered: {
            var step = root._batchQueue.shift()
            if (typeof step === "function")
                step()
            if (root._batchQueue.length > 0)
                batchTimer.restart()
        }
    }

    // Batch scheduler handed to the adapters: they call done() with the first
    // slice synchronously and hand the rest here, so one mapping batch per
    // frame and no frame is ever blown by the whole set at once.
    function _scheduleBatch(step) {
        _batchQueue.push(step)
        batchTimer.restart()
    }

    // Foreground priority for the clipboard's background work (metadata counts,
    // content signatures). Those queues exist to enrich a history that is
    // already on screen, so an open session holds them off rather than letting
    // them compete with the frame the user is waiting on.
    Timer {
        id: foregroundHoldTimer
        interval: 400
        repeat: false
        onTriggered: session.setForegroundBusy(false)
    }
    Connections {
        target: session
        function onVisibleChanged() { root._syncForegroundGate() }
        function onModeChanged() { root._syncForegroundGate() }
        function onLoadingMoreChanged() { root._syncForegroundGate() }
    }

    function _syncForegroundGate() {
        var busy = session.visible
                && session.mode === "clipboard"
                && (session.loading || session.loadingMore)
        root._holdForeground(busy)
    }

    function _holdForeground(busy) {
        var backend = Services.ClipboardService
        if (!backend || typeof backend.setForegroundBusy !== "function")
            return
        backend.setForegroundBusy(busy)
        if (busy)
            foregroundHoldTimer.restart()
        else
            foregroundHoldTimer.stop()
    }

    // Production data-source adapters installed on the session seam: real
    // desktop-entry applications, cliphist clipboard history, and niri
    // shortcut binds. Unavailable sources resolve to explicit errors.
    // Category classifiers travel with the adapters so every pooled item
    // carries the id the chip bar filters on: desktop Categories for apps,
    // content heuristics for clipboard, and the parser's own bind category
    // for shortcuts (which needs no resolver).
    readonly property var _adapters: LauncherAdapters.createAdapters({
        appsSource: DesktopEntries.applications,
        launchCounts: Services.LaunchCountService,
        clipboardBackend: Services.ClipboardService,
        shortcutsBackend: Services.NiriShortcutService,
        iconResolver: function(name) {
            // `check = false` on purpose. The checked form asks Quickshell
            // whether the name exists, and that check does not see the user's
            // icon theme: with Papirus configured, every app whose icon ships
            // only in Papirus came back "" (firefox, obsidian, blender, btop,
            // inkscape, clash-verge, nvtop's neighbours…) while the handful that
            // also exist under hicolor resolved fine — so the launcher showed an
            // empty 40px rail for most of the list and read as a broken row.
            //
            // The unchecked form always hands back the `image://icon/<name>`
            // URL, and the `image://` provider resolves it through the real
            // theme chain, which is the only place that knows the answer. A name
            // that genuinely has no icon now resolves to an image that fails to
            // paint, and the row's existing `iconFailed` handling takes it from
            // there — the decision belongs to the image loader, not to a
            // lookup that cannot see the theme.
            return name ? String(Quickshell.iconPath(name, false)) : ""
        },
        appCategoryResolver: LauncherCategories.appCategoryOf,
        clipCategoryResolver: LauncherCategories.clipCategoryOf,
        commands: LauncherAdapters.builtinCommands(),
        schedule: function(step) { root._scheduleBatch(step) },
        ipcHelperPath: Quickshell.shellDir + "/scripts/afloat-ipc",
        actionRunner: root._runShortcutAction
    })

    // Quickshell populates the desktop-entry model lazily; holding a live
    // binding keeps the scan materialized so launcher queries see entries.
    readonly property int _desktopEntryCount: DesktopEntries.applications.values.length

    // The scan reports every entry individually, so it is coalesced into
    // pulls instead of one per entry. The leading-edge pass matters most: it
    // puts the first apps on screen within a frame or two of the scan
    // starting, and the trailing pass settles the remainder behind it.
    Timer {
        id: entryScanLeadingTimer
        interval: 120
        repeat: false
        onTriggered: session.revalidatePool()
    }
    Timer {
        id: entryScanRefreshTimer
        interval: 400
        repeat: false
        onTriggered: session.revalidatePool()
    }
    on_DesktopEntryCountChanged: {
        if (!entryScanLeadingTimer.running)
            entryScanLeadingTimer.restart()
        entryScanRefreshTimer.restart()
        if (!session.visible && session.displayPool.length === 0)
            session.primeApps()
    }

    // Launch-count changes - a just-recorded launch or the persisted maps
    // landing - must re-rank the pooled apps list. recordLaunch runs before
    // the post-launch close, so refreshing directly on the signal would
    // supersede the close completion and strand the surface open; a short
    // coalescing timer fires strictly after that synchronous settle.
    Timer {
        id: rankingRevalidateTimer
        interval: 300
        repeat: false
        onTriggered: session.revalidatePool()
    }
    Connections {
        target: Services.LaunchCountService
        function onCountsChanged() { rankingRevalidateTimer.restart() }
        function onLastAtChanged() { rankingRevalidateTimer.restart() }
        function onPersistenceReady() { rankingRevalidateTimer.restart() }
    }

    // Quickshell-free session core (kept separate so it loads standalone).
    LauncherSession {
        id: session
        _adapters: root._adapters
        clipboardService: Services.ClipboardService
    }

    // Observable session state.
    readonly property alias visible: session.visible
    // Clipboard thumbnail decoding passthrough for result rows.
    function decodeThumbnail(id, mime, callback) { return session.decodeThumbnail(id, mime, callback) }
    // Full-content clipboard preview decode passthrough for the preview pane.
    signal textPreviewDecoded(string id, string content)
    function requestTextPreview(id) { return session.requestTextPreview(id) }
    // Clipboard metadata-merge relay: surfaces bind this signal name on the
    // service object, so it must be re-emitted here like the preview relay.
    signal clipboardMetadataMerged()
    Connections {
        target: session
        function onTextPreviewDecoded(id, content) { root.textPreviewDecoded(id, content) }
        function onClipboardMetadataMerged() { root.clipboardMetadataMerged() }
    }
    property alias query: session.query
    readonly property alias mode: session.mode
    // Active category chip; "" is the unfiltered "All" chip.
    property alias category: session.category
    // Published chip counts for the current pool and query; the page builds
    // its chip bar from this, so it must be re-exposed like category itself.
    readonly property alias categorySummary: session.categorySummary
    property alias results: session.results
    // Stable per-mode pool the surface renders; text filtering is local.
    property alias displayPool: session.displayPool
    readonly property alias loading: session.loading
    // True while result batches are still streaming in behind the footer
    // spinner; the first batch has already cleared `loading`.
    readonly property alias loadingMore: session.loadingMore
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
    function primeApps() { return session.primeApps() }

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

    // Which chrome the wave overlay wears: "blocks" (the osu wiki three-band
    // stack — masthead, page bar, content) or "rail" (masthead, collapsible
    // vertical navigation, content).
    //
    // Both are kept as first-class code paths because the choice is a judgement
    // call the source cannot settle: the rail spends width on navigation and
    // gives the height back, the page bar does the opposite, and which reads
    // better depends on the display and on habit.
    //
    // "rail" is the default because on this desktop it reads better: the
    // launcher is the one surface where the eye is already scanning a vertical
    // list, and there a mode switch costing 44px of height costs more than the
    // 170px of width the rail takes — with the collapsed rail costing less
    // still. AFLOAT_LAUNCHER_CHROME=blocks names the other one, and `chrome()`
    // flips it live, so both can be compared against the same open session
    // without restarting the shell.
    property string chromeLayout: (Quickshell.env("AFLOAT_LAUNCHER_CHROME") || "rail").trim() === "blocks"
            ? "blocks" : "rail"

    function toggleChrome() {
        root.chromeLayout = root.chromeLayout === "rail" ? "blocks" : "rail"
        // Printed rather than returned: Quickshell rejects a non-void IPC
        // handler and calls it with no receiver, so a returning `chrome()`
        // would look like a silent no-op.
        console.log("[launcher] chrome layout ->", root.chromeLayout)
    }

    // Sidebar rail collapse state, persisted across restarts. Toggles are
    // human-scale rare, so it persists immediately like launch counts
    // rather than through a debounced queue.
    property bool railExpanded: true
    property bool _railAdopted: false

    function _adoptRailState(text) {
        if (root._railAdopted)
            return
        var expanded = true
        try {
            if (text) {
                var parsed = JSON.parse(String(text))
                if (parsed && typeof parsed.railExpanded === "boolean")
                    expanded = parsed.railExpanded
            }
        } catch (err) {
            console.warn("LauncherService: unreadable launcher.json:", err)
            return
        }
        root._railAdopted = true
        root.railExpanded = expanded
    }

    onRailExpandedChanged: {
        if (root._railAdopted)
            railStateFile.setText(JSON.stringify({ railExpanded: root.railExpanded }))
    }

    FileView {
        id: railStateFile
        path: Quickshell.statePath("launcher.json")
        blockLoading: true
        watchChanges: false
        onLoaded: root._adoptRailState(railStateFile.text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn("LauncherService: failed to load launcher.json:", error)
                return
            }
            // Materialize defaults so only the very first boot logs the
            // missing file; later restarts read it back cleanly.
            railStateFile.setText(JSON.stringify({ railExpanded: root.railExpanded }))
            root._adoptRailState("")
        }
    }

    // IPC surface for the launcher entry and niri keybind integration.
    IpcHandler {
        target: "launcher"
        function toggle() { root.toggle() }
        function openClipboard() { root.openClipboard() }
        function openShortcuts() { root.openShortcuts() }
        function chrome() { root.toggleChrome() }
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
