// Standalone launcher session state machine: visibility, query/mode
// derivation, refresh sequencing against pluggable data sources, selection,
// execution outcomes, and keyboard action handling. Deliberately free of
// Quickshell imports so it loads under plain qmltestrunner;
// LauncherService embeds it and owns the IPC surface.
import QtQml
import "../LauncherLogic.js" as LauncherLogic

QtObject {
    id: root

    // Observable session state for launcher surfaces.
    property bool visible: false
    property string query: ""
    readonly property string mode: LauncherLogic.parseQuery(query).mode
    property var results: []
    property bool loading: false
    property string error: ""
    property int selectedIndex: -1

    // True while navigation and execution are accepted; loading and error
    // sessions surface their state instead of accepting input actions.
    readonly property bool interactive: !loading && error === ""

    // Data-source seam keyed by mode ("apps", "clipboard", "shortcuts").
    // Each adapter exposes refresh(query, mode, done) and execute(item, done)
    // where query is the prefix-stripped search text; done receives either
    // an item array or { error } for refresh, and { ok, error } for execute.
    // Tests inject deterministic fixtures here instead of shelling out;
    // modes without a registered adapter resolve to an empty result set.
    property var _adapters: ({})

    // Clipboard service seam for thumbnail decoding; injected by the
    // production service, stubbed (or null) in tests.
    property var clipboardService: null

    function decodeThumbnail(id, mime, callback) {
        if (clipboardService)
            return clipboardService.decodeThumbnail(id, mime, callback)
        if (callback)
            callback("")
    }

    // Stable per-mode pool of every sorted item; text filtering runs locally
    // over this so result rows keep their identity across keystrokes and the
    // surface can fold/reveal instead of reloading the whole list.
    property var displayPool: []
    property string _pooledMode: ""

    // Monotonic guard: only the newest dispatched refresh, or the session
    // alive when execution started, may commit state.
    property int _refreshToken: 0

    // Query edits re-request data for the newly parsed mode while open;
    // closed sessions ignore edits until the next open().
    onQueryChanged: {
        if (root.visible)
            root.refresh()
    }

    // Clipboard history lands asynchronously (5s polling); while a
    // clipboard session is open, fresh data must reach the open list
    // without the user reopening the panel.
    property Connections _clipboardConn: Connections {
        target: root.clipboardService
        ignoreUnknownSignals: true
        function onListCompleted() {
            if (root.visible && !root.loading
                    && LauncherLogic.parseQuery(root.query).mode === "clipboard")
                root.refresh(true)
        }
    }

    function open() {
        if (root.visible)
            return
        root.visible = true
        root.refresh()
    }

    function close() {
        // Invalidate anything in flight before tearing the session down so
        // late completions cannot resurrect closed-session state.
        _refreshToken++
        root.visible = false
        root.query = ""
        root._pooledMode = ""
        root.results = []
        root.loading = false
        root.error = ""
        root.selectedIndex = -1
    }

    function toggle() {
        if (root.visible)
            root.close()
        else
            root.open()
    }

    function openClipboard() {
        query = ">clip "
        root.open()
    }

    function openShortcuts() {
        query = ">key "
        root.open()
    }

    // Refreshes the visible session. Text edits ride the pooled fast path
    // (the pool holds the full set for this open); callers announcing real
    // upstream changes - desktop-entry rescans, new clipboard history -
    // must pass forcePull so the pool is re-fetched from the source.
    function refresh(forcePull) {
        if (!root.visible)
            return
        var parsed = LauncherLogic.parseQuery(query)

        // Text-only edits inside a pooled mode never re-hit the data source;
        // the pool already holds the full sorted set for this open session.
        if (!forcePull && parsed.mode === _pooledMode && displayPool.length > 0) {
            var previous = root.results
            var filtered = LauncherLogic.filterResults(displayPool, parsed.text)
            // Clearing the query always lands back on the first row; only a
            // narrowing edit preserves the anchored selection.
            root.selectedIndex = parsed.text.length > 0
                    ? LauncherLogic.refilterSelection(previous, root.selectedIndex, filtered)
                    : LauncherLogic.clampSelection(0, filtered.length)
            // Keep the previous array when the ids did not change: a fresh
            // array fires resultsChanged and replays the refill cascade,
            // which read as the list jittering on every background poll.
            root.results = LauncherLogic.poolMatches(previous, filtered)
                    ? previous : filtered
            return
        }

        var adapter = _adapterFor(parsed.mode)
        var token = ++_refreshToken
        root.loading = true
        root.error = ""
        adapter.refresh("", parsed.mode, function(outcome) {
            root._completeRefresh(token, outcome, parsed.mode, parsed.text)
        })
    }

    // Commits a finished refresh only while it is still the newest request.
    // Stale completions are dropped so they cannot replace newer query or
    // mode state, leaving the newer attempt's loading/error display intact.
    function _completeRefresh(token, outcome, pooledMode, requestText) {
        if (token !== _refreshToken)
            return
        root.loading = false
        if (outcome && !Array.isArray(outcome)) {
            root.error = _messageOr(outcome.error, "data source failed")
            return
        }
        root.error = ""
        // Keep the pooled array (and its live delegates) when a pull returns
        // the same ordered ids, so redundant refreshes never rebuild the list.
        var sorted = LauncherLogic.sortResults(outcome || [])
        var poolStable = LauncherLogic.poolMatches(sorted, root.displayPool)
        var previous = root.results
        if (!poolStable)
            root.displayPool = sorted
        // The pooled-mode marker must be restored even when the content is
        // unchanged: close() clears it while the pool survives, and without
        // this every keystroke would re-hit the data source after a reopen.
        root._pooledMode = pooledMode
        var filtered = LauncherLogic.filterResults(root.displayPool, requestText)
        root.selectedIndex = requestText.length > 0
                ? LauncherLogic.refilterSelection(previous, root.selectedIndex, filtered)
                : LauncherLogic.clampSelection(0, filtered.length)
        // Same array-identity guard as the pooled path: unchanged ids must
        // not reassign results or the surface replays its refill animation.
        root.results = LauncherLogic.poolMatches(previous, filtered)
                ? previous : filtered
    }

    function selectNext() {
        root.selectedIndex = LauncherLogic.clampSelection(root.selectedIndex + 1, root.results.length)
    }

    function selectPrevious() {
        root.selectedIndex = LauncherLogic.clampSelection(root.selectedIndex - 1, root.results.length)
    }

    function executeSelected() {
        // Non-interactive sessions (loading / error) must not execute the
        // results still on screen; they are stale until a refresh commits.
        if (!root.interactive)
            return
        if (root.selectedIndex < 0 || root.selectedIndex >= root.results.length)
            return
        root.execute(root.results[root.selectedIndex])
    }

    function execute(item) {
        if (!item || !root.visible || !root.interactive)
            return
        var adapter = _adapterFor(mode)
        var sessionToken = _refreshToken
        // A throwing adapter must not swallow the completion callback: the
        // activated row is already hidden for its exit fling, so a lost
        // outcome would strand the surface with an invisible selection.
        try {
            adapter.execute(item, function(outcome) {
                root._completeExecute(sessionToken, outcome)
            })
        } catch (err) {
            root._completeExecute(sessionToken, { ok: false, error: String(err) })
        }
    }

    // Successful execution closes the surface; failures preserve the session
    // and report the error. Completions from dead sessions are dropped.
    function _completeExecute(sessionToken, outcome) {
        if (sessionToken !== _refreshToken)
            return
        if (outcome && outcome.ok) {
            root.close()
            return
        }
        root.error = _messageOr(outcome && outcome.error, "execution failed")
    }

    // Maps raw key names onto launcher actions through the shared contract
    // and applies them; returns the action for callers that need it.
    function handleKey(key) {
        var normalized = key == null ? "" : String(key).toLowerCase()
        if (normalized === "escape" || normalized === "esc") {
            // Clearing keeps the active route's prefix; an empty input
            // closes instead of falling back to the apps list.
            var esc = LauncherLogic.escapeAction(query)
            if (esc.action === "clear")
                query = esc.query
            else
                root.close()
            return esc.action
        }
        var action = LauncherLogic.keyboardAction(
            key,
            query.length > 0,
            root.selectedIndex >= 0,
            root.interactive
        )
        if (action === "clear")
            query = ""
        else if (action === "close")
            root.close()
        else if (action === "up")
            root.selectPrevious()
        else if (action === "down")
            root.selectNext()
        else if (action === "execute")
            root.executeSelected()
        return action
    }

    function _messageOr(value, fallback) {
        var text = value == null ? "" : String(value)
        return text.length > 0 ? text : fallback
    }

    function _adapterFor(modeKey) {
        var found = _adapters ? _adapters[String(modeKey)] : null
        if (found && typeof found.refresh === "function" && typeof found.execute === "function")
            return found
        // Neutral fallback keeps unconfigured modes inert instead of crashing.
        return {
            refresh: function(queryText, modeName, done) { done([]) },
            execute: function(item, done) { done({ ok: true }) }
        }
    }
}
