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

    // Monotonic guard: only the newest dispatched refresh, or the session
    // alive when execution started, may commit state.
    property int _refreshToken: 0

    // Query edits re-request data for the newly parsed mode while open;
    // closed sessions ignore edits until the next open().
    onQueryChanged: {
        if (root.visible)
            root.refresh()
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

    function refresh() {
        if (!root.visible)
            return
        var parsed = LauncherLogic.parseQuery(query)
        var adapter = _adapterFor(parsed.mode)
        var token = ++_refreshToken
        root.loading = true
        root.error = ""
        adapter.refresh(parsed.text, parsed.mode, function(outcome) {
            root._completeRefresh(token, outcome)
        })
    }

    // Commits a finished refresh only while it is still the newest request.
    // Stale completions are dropped so they cannot replace newer query or
    // mode state, leaving the newer attempt's loading/error display intact.
    function _completeRefresh(token, outcome) {
        if (token !== _refreshToken)
            return
        root.loading = false
        if (outcome && !Array.isArray(outcome)) {
            root.error = _messageOr(outcome.error, "data source failed")
            return
        }
        root.error = ""
        root.results = LauncherLogic.sortResults(outcome || [])
        root.selectedIndex = LauncherLogic.clampSelection(0, root.results.length)
    }

    function selectNext() {
        root.selectedIndex = LauncherLogic.clampSelection(root.selectedIndex + 1, root.results.length)
    }

    function selectPrevious() {
        root.selectedIndex = LauncherLogic.clampSelection(root.selectedIndex - 1, root.results.length)
    }

    function executeSelected() {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.results.length)
            return
        root.execute(root.results[root.selectedIndex])
    }

    function execute(item) {
        if (!item || !root.visible)
            return
        var adapter = _adapterFor(mode)
        var sessionToken = _refreshToken
        adapter.execute(item, function(outcome) {
            root._completeExecute(sessionToken, outcome)
        })
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
