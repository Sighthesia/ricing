// Standalone launcher session state machine: visibility, query/mode
// derivation, refresh sequencing against pluggable data sources, selection,
// execution outcomes, and keyboard action handling. Deliberately free of
// Quickshell imports so it loads standalone;
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

    // Category lens applied on top of the text filter; "" is the unfiltered
    // "All" chip. The id space is per-mode (apps read .desktop Categories,
    // clipboard reads entry content), so the session treats it as a view
    // filter over the pooled data instead of a query: it never reaches the
    // data source, and results stay consistent with what the surface folds.
    property string category: ""
    // Set while a mode switch rewinds the lens; the pending refresh already
    // reads category at commit time, so the reset must not pull again.
    property bool _categoryResetInFlight: false

    function resetCategory() {
        if (root.category === "")
            return
        root._categoryResetInFlight = true
        root.category = ""
        root._categoryResetInFlight = false
    }

    onCategoryChanged: {
        if (root._categoryResetInFlight || !root.visible)
            return
        root.noteInput()
        // A lens change rides the pooled fast path: the full sorted set for
        // this mode is already here, so no adapter call is needed.
        root.publishCategorySummary(true)
        root.refresh()
    }

    onModeChanged: root.resetCategory()

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

    // Full-content preview decode for the clipboard preview pane: routes a
    // text decode request through the clipboard service and relays the
    // decoded content back as a session signal, so surfaces never need the
    // concrete service (tests and embedded sessions stay null-safe).
    signal textPreviewDecoded(string id, string content)

    function requestTextPreview(id) {
        if (clipboardService && typeof clipboardService.requestPreview === "function")
            clipboardService.requestPreview(id, false)
    }

    // Stable per-mode pool of every sorted item; text filtering runs locally
    // over this so result rows keep their identity across keystrokes and the
    // surface can fold/reveal instead of reloading the whole list.
    property var displayPool: []
    property string _pooledMode: ""

    // True while the current refresh is still streaming batches. The first
    // batch ends the loading state and paints; the rest append behind a
    // footer spinner, which is what "front to back" loading looks like.
    property bool loadingMore: false
    // Set while a refresh is mid-stream, so a following batch appends to the
    // pool instead of replacing it. Cleared when the stream completes.
    property bool _streamActive: false

    // A pooled clipboard reopen keeps its old rows visible while the fresh
    // history stream is collected. Replacing the pool with its first batch
    // made the opening animation visibly shrink and rebuild the list.
    property bool _staleRefresh: false
    property var _staleRefreshItems: []

    // ---- Input priority ---------------------------------------------------
    // An appended batch costs a full re-filter of the pool, a results swap and
    // a stretch of the row list. Doing that while the user is typing or
    // arrowing through the list is what makes an open feel heavy under the
    // fingers, so a tail that lands during input waits for it to settle.
    property bool _inputActive: false
    property var _heldBatches: []
    readonly property int _inputSettleMs: 140
    property double _inputDeadline: 0
    property bool _inputWatchScheduled: false

    // Set while a foreground-only read is in flight, so the host can hold its
    // service's background queues off. Raised for a clipboard session that is
    // open or still streaming; every other host may ignore it.
    property bool foregroundBusy: false

    // Category chip counts for the current pool and query. Published, not
    // derived: a binding would recompute the whole pool's summary on every
    // arriving batch, which is both a full second pass per commit and a set of
    // numbers the user watches tick up from a partial set to the real one as
    // the tail streams in. So it is published when it means something - when
    // the data is whole, and when a query or lens change makes it wrong.
    property var categorySummary: ({ total: 0, categories: [] })
    // Running tally for the set currently streaming in. Counting a batch as it
    // arrives costs one pass over that batch; recounting the pool per batch cost
    // a pass over all of it, six times over, on the frames the list is filling.
    property var _categoryTally: null

    // Publishes the counts for what has arrived so far, from the running tally
    // when there is one. `final` says the stream is over, which drops the tally
    // so the next set starts clean.
    function publishCategorySummary(final) {
        if (root._categoryTally) {
            root.categorySummary = LauncherLogic.categoryTallyToSummary(root._categoryTally)
        } else {
            root.categorySummary = LauncherLogic.categorySummary(
                root.displayPool, LauncherLogic.parseQuery(root.query).text)
        }
        if (final === true)
            root._categoryTally = null
    }

    // Counts a batch into the running tally without publishing it.
    function tallyCategorySummary(batch) {
        if (!root._categoryTally)
            root._categoryTally = LauncherLogic.newCategoryTally()
        LauncherLogic.tallyCategories(root._categoryTally, batch,
                LauncherLogic.parseQuery(root.query).text)
    }

    function setForegroundBusy(busy) {
        root.foregroundBusy = !!busy
    }

    // Marks the session busy with the user. A QtObject cannot host a Timer
    // (no default property), and this component deliberately has no children,
    // so the settle window is polled on the shared call-later queue instead:
    // the ping only exists for the length of the window.
    function noteInput() {
        if (!root.visible)
            return
        root._inputActive = true
        root._inputDeadline = Date.now() + root._inputSettleMs
        if (root._inputWatchScheduled)
            return
        root._inputWatchScheduled = true
        Qt.callLater(root._checkInputWindow)
    }

    function _checkInputWindow() {
        if (!root._inputActive) {
            root._inputWatchScheduled = false
            return
        }
        if (Date.now() < root._inputDeadline) {
            Qt.callLater(root._checkInputWindow)
            return
        }
        root._inputWatchScheduled = false
        root.drainHeldBatches()
    }

    // Commits everything that waited out the input window, in arrival order.
    function drainHeldBatches() {
        var held = root._heldBatches
        root._heldBatches = []
        root._inputActive = false
        root._categoryTally = null
        for (var index = 0; index < held.length; index++)
            root._applyBatch(held[index][0], held[index][1], held[index][2],
                             held[index][3], held[index][4])
    }

    // Monotonic guard: only the newest dispatched refresh, or the session
    // alive when execution started, may commit state.
    property int _refreshToken: 0
    property bool _executionInFlight: false
    property bool _appsPrimeInFlight: false
    property bool _metadataRefreshPending: false
    // The service now resolves clipboard metadata in batches, and each batch
    // ends with a metadataUpdated signal. Merging per signal meant re-mapping
    // the whole history once per batch - dozens of rounds per pass, each of them
    // mapping every row, which is exactly the background churn a settle window
    // is for. The merge waits for the stream to go quiet instead, so a pass
    // costs one round however finely it was split.
    readonly property int _metadataQuietMs: 180
    property double _metadataQuietDeadline: 0
    property bool _metadataWatchScheduled: false
    // Clipboard metadata (exact counts, image dimensions) arrives after the
    // first paint without changing item ids or order. Merging it into the
    // live pool must not replace the pooled arrays: a swap rebuilds every
    // delegate and replays the refill cascade, which reads as stutter while
    // the batch lands entry by entry.
    signal clipboardMetadataMerged()

    // Query edits re-request data for the newly parsed mode while open;
    // closed sessions ignore edits until the next open().
    onQueryChanged: {
        if (root.visible) {
            root.noteInput()
            root.publishCategorySummary(true)
            root.refresh()
        }
    }

    // Clipboard history lands asynchronously (5s polling); while a
    // clipboard session is open, fresh data must reach the open list
    // without the user reopening the panel. Preview decodes relay to the
    // session signal so consumers never bind the concrete service.
    property Connections _clipboardConn: Connections {
        target: root.clipboardService
        ignoreUnknownSignals: true
        function onListCompleted() {
            // A poll that lands while the list is still filling must not restart
            // it: the force pull supersedes the in-flight stream, so the tail
            // it had not delivered yet is thrown away and the whole set starts
            // arriving again - the counts step backwards and the open never
            // settles. `loading` only covers the wait before the first batch, so
            // the streaming half has to be asked for separately.
            if (root.visible && !root.loading && !root.loadingMore
                    && LauncherLogic.parseQuery(root.query).mode === "clipboard")
                root.refresh(true)
        }
        function onMetadataUpdated() {
            root._noteMetadataUpdate()
        }
        function onPreviewDecoded(id, contentOrPath) {
            root.textPreviewDecoded(String(id == null ? "" : id),
                                    String(contentOrPath == null ? "" : contentOrPath))
        }
    }

    // Restarts the quiet window on every batch and keeps one watcher alive until
    // the window closes, then runs a single merge round. Polled on the shared
    // call-later queue rather than a Timer: this component is a QtObject and
    // deliberately has no children.
    function _noteMetadataUpdate() {
        if (!root.visible || LauncherLogic.parseQuery(root.query).mode !== "clipboard")
            return
        root._metadataQuietDeadline = Date.now() + root._metadataQuietMs
        if (root._metadataWatchScheduled)
            return
        root._metadataWatchScheduled = true
        Qt.callLater(root._checkMetadataQuiet)
    }

    function _checkMetadataQuiet() {
        if (root._metadataQuietDeadline <= 0) {
            root._metadataWatchScheduled = false
            return
        }
        if (Date.now() < root._metadataQuietDeadline) {
            Qt.callLater(root._checkMetadataQuiet)
            return
        }
        // Metadata is enrichment, not the foreground list. During an initial
        // or stale clipboard stream the page is already committing the full
        // history; starting another adapter refresh here would map that same
        // history a second time into the opening frame. Keep the quiet watcher
        // alive and merge only after the visible stream has settled.
        if (root.loading || root.loadingMore || root._streamActive || root._staleRefresh) {
            root._metadataQuietDeadline = Date.now() + root._metadataQuietMs
            Qt.callLater(root._checkMetadataQuiet)
            return
        }
        root._metadataWatchScheduled = false
        // A merge round still in flight means the rows it is reading are the
        // ones being enriched; wait for it rather than dropping the window on
        // the floor, which is what a plain early return used to do.
        if (root._metadataRefreshPending) {
            root._metadataQuietDeadline = Date.now() + root._metadataQuietMs
            Qt.callLater(root._checkMetadataQuiet)
            return
        }
        root._metadataQuietDeadline = 0
        root._metadataRefreshPending = true
        Qt.callLater(function() {
            root._metadataRefreshPending = false
            root._mergeClipboardMetadata()
        })
    }

    // Merge freshly resolved clipboard metadata into the live pool without
    // replacing it: display fields are copied onto the kept row objects (the
    // surface re-reads them through its metadata revision) while array and
    // object identity stay intact, so no delegate is rebuilt and no cascade
    // replays. Entries that vanished or reordered fall through to the normal
    // refresh path on the next list poll.
    function _mergeClipboardMetadata() {
        if (!root.visible || LauncherLogic.parseQuery(root.query).mode !== "clipboard")
            return
        if (root.loading || root.loadingMore || root._streamActive || root._staleRefresh) {
            root._metadataQuietDeadline = Date.now() + root._metadataQuietMs
            if (!root._metadataWatchScheduled) {
                root._metadataWatchScheduled = true
                Qt.callLater(root._checkMetadataQuiet)
            }
            return
        }
        var adapter = _adapterFor("clipboard")
        // The metadata merge needs every row, not just the first batch, so it
        // accumulates the stream before touching the pool.
        var batches = []
        adapter.refresh("", "clipboard", function(outcome, complete) {
            if (Array.isArray(outcome))
                batches.push(outcome)
            if (complete === false)
                return
            var rows = []
            for (var b = 0; b < batches.length; b++)
                rows = rows.concat(batches[b])
            if (!rows.length || !root.displayPool.length)
                return
            var keptById = ({})
            for (var keptIndex = 0; keptIndex < root.displayPool.length; keptIndex++) {
                var kept = root.displayPool[keptIndex]
                if (kept)
                    keptById[String(kept.id)] = kept
            }
            var merged = false
            for (var freshIndex = 0; freshIndex < rows.length; freshIndex++) {
                var fresh = rows[freshIndex]
                if (!fresh)
                    continue
                var target = keptById[String(fresh.id)]
                if (!target)
                    continue
                target.displayName = fresh.displayName
                target.description = fresh.description
                target.searchText = fresh.searchText
                target.icon = fresh.icon
                merged = true
            }
            if (merged)
                root.clipboardMetadataMerged()
        })
    }

    function open() {
        if (root.visible)
            return
        root.visible = true
        // Publish visibility before pulling the first result pool so the
        // surface can claim keyboard focus in the same event-loop turn.
        var openToken = ++root._refreshToken
        Qt.callLater(function() {
            if (openToken !== root._refreshToken || !root.visible)
                return
            root.refresh()
        })
    }

    function close() {
        // Invalidate anything in flight before tearing the session down so
        // late completions cannot resurrect closed-session state.
        _refreshToken++
        root.visible = false
        // The apps pool is the expensive one to rebuild (a full source pull
        // with per-entry icon theme lookups); keep it pooled across closes
        // so the next plain open serves results locally without re-pulling.
        // Clipboard history is also kept pooled so a reopen serves the last
        // rows instantly instead of blanking on "Searching..." plus a full
        // entrance wave; freshness still arrives through the 5s poll and the
        // list-completed background refresh, which commit without flashing
        // loading over stale rows.
        // Retain only when the closing query agrees with the pooled marker:
        // closing mid-load (or a stale extra close) must not re-label a pool
        // built for another mode, or the next open would serve that pool's
        // rows under the wrong mode (e.g. apps rows under ">clip ").
        var closingMode = LauncherLogic.parseQuery(root.query).mode
        if (closingMode === root._pooledMode)
            root._pooledMode = (closingMode === "apps" || closingMode === "clipboard") ? closingMode : ""
        root.query = ""
        // A closed session always reopens unfiltered: a lens left over from
        // the previous run would silently hide most of the list.
        root.category = ""
        // Freeze the last visible set instead of zeroing results: an empty
        // array tears down every live row delegate, and the next open would
        // rebuild the whole list on its first frame — the idle-cold reopen
        // stall. Deriving the frozen set from the pool keeps the exact item
        // objects (and their delegates) alive while hidden; a pooled reopen
        // then commits the same ordered ids, the previous array identity
        // wins, and nothing is rebuilt at all.
        root.results = LauncherLogic.filterResults(root.displayPool, "", root.category)
        root.loading = false
        root.loadingMore = false
        root._streamActive = false
        root._heldBatches = []
        root._staleRefresh = false
        root._staleRefreshItems = []
        root._inputActive = false
        root._metadataQuietDeadline = 0
        root.error = ""
        root.selectedIndex = -1
        root._executionInFlight = false
    }

    function toggle() {
        if (root.visible)
            root.close()
        else
            root.open()
    }

    // Build the apps pool while the shell is idle so the first visible open
    // only filters already-normalized rows and creates its delegates.
    function primeApps() {
        if (root.visible || root._appsPrimeInFlight)
            return
        var adapter = _adapterFor("apps")
        root._appsPrimeInFlight = true
        var collected = []
        var answered = false
        adapter.refresh("", "apps", function(outcome, complete) {
            if (outcome && Array.isArray(outcome)) {
                collected = collected.concat(outcome)
                answered = true
            }
            if (complete === false)
                return
            root._appsPrimeInFlight = false
            if (root.visible || !answered)
                return
            var sorted = LauncherLogic.preferStableIcons(
                root.displayPool, LauncherLogic.sortResults(collected))
            root.displayPool = sorted
            root._pooledMode = "apps"
            root.publishCategorySummary(true)
            root.results = LauncherLogic.filterResults(sorted, "", root.category)
            root.selectedIndex = LauncherLogic.clampSelection(0, root.results.length)
        })
    }

    function openClipboard() {
        var servingPooled = root._pooledMode === "clipboard" && root.displayPool.length > 0
        query = ">clip "
        root.open()
        if (!servingPooled)
            return
        Qt.callLater(function() {
            if (!root.visible || LauncherLogic.parseQuery(root.query).mode !== "clipboard")
                return
            // The pooled snapshot predates history that landed while closed:
            // re-pull through the adapter (synchronous from live backend data
            // when healthy, so nothing flashes) instead of painting stale rows
            // until a background fetch heals them, then kick one backend fetch
            // so the very latest copies land promptly. Null-safe for doubles.
            root.refresh(true)
            if (clipboardService && typeof clipboardService.list === "function")
                clipboardService.list()
        })
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
            var filtered = LauncherLogic.filterResults(displayPool, parsed.text, root.category)
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
        // Stale-while-revalidate for clipboard only: history polls land every
        // few seconds, and raising loading would hide the list behind
        // "Searching..." on each of them. When same-mode rows are already on
        // screen the fetch commits in the background instead. First paints
        // and mode switches have no stale rows and keep the loading state;
        // apps keeps its existing refresh semantics untouched.
        var hasStaleRows = parsed.mode === "clipboard" && root._pooledMode === "clipboard"
                && root.displayPool.length > 0 && root.results && root.results.length > 0
        root.loading = !hasStaleRows
        root.error = ""
        root.loadingMore = false
        root._streamActive = false
        root._heldBatches = []
        root._staleRefresh = hasStaleRows
        root._staleRefreshItems = []
        if (hasStaleRows) {
            root._streamActive = true
            root.loadingMore = true
        }
        adapter.refresh("", parsed.mode, function(outcome, complete) {
            root._applyBatch(token, outcome, complete !== false, parsed.mode, parsed.text)
        })
    }

    // Commits one batch of a refresh while it is still the newest request.
    // Batches arrive in their final order (the adapters pre-sort the source),
    // so the first one replaces the pool and every later one appends: no
    // reshuffle, no rebuilt delegates, and the head of the list is usable
    // while the tail is still streaming.
    function _applyBatch(token, outcome, complete, pooledMode, requestText) {
        if (token !== _refreshToken)
            return
        // A stale clipboard pool is already useful content. Collect the fresh
        // stream off to the side and commit it only once it is complete, so a
        // small head never replaces a full visible history during an open.
        if (root._staleRefresh) {
            if (outcome && !Array.isArray(outcome)) {
                root._staleRefresh = false
                root._staleRefreshItems = []
                root._streamActive = false
                root.loading = false
                root.loadingMore = false
                root.error = _messageOr(outcome.error, "data source failed")
                return
            }
            root._staleRefreshItems = root._staleRefreshItems.concat(outcome || [])
            if (complete !== true)
                return
            outcome = root._staleRefreshItems
            root._staleRefreshItems = []
            root._staleRefresh = false
            root._streamActive = false
            root.loadingMore = false
            complete = true
        }
        // Only a tail append waits. The first batch of a refresh replaces the
        // pool - it is the content the new query or the new mode asked for -
        // so it always lands, or a mode switch would show an empty list for
        // the length of the input window.
        if (root._inputActive && root._streamActive && root.displayPool.length > 0) {
            root._heldBatches.push([token, outcome, complete, pooledMode, requestText])
            return
        }
        if (outcome && !Array.isArray(outcome)) {
            // A failure is terminal whatever the adapter claimed about the
            // rest of the stream.
            root._streamActive = false
            root.loadingMore = false
            root.loading = false
            root.error = _messageOr(outcome.error, "data source failed")
            return
        }
        var batch = outcome || []
        var appending = root._streamActive
        root._streamActive = !complete
        root.loadingMore = !complete
        // Any batch means data arrived: the full loading state only covers
        // the wait before the very first one.
        root.loading = false
        root.error = ""
        // Keep the pooled array (and its live delegates) when a pull returns
        // the same ordered ids, so redundant refreshes never rebuild the list.
        var sorted = appending ? root.displayPool.concat(batch)
                                : (complete ? LauncherLogic.sortResults(batch) : batch)
        sorted = LauncherLogic.preferStableIcons(root.displayPool, sorted)
        var poolStable = appending ? false : LauncherLogic.poolMatches(sorted, root.displayPool)
        var previous = root.results
        if (!poolStable)
            root.displayPool = sorted
        // The pooled-mode marker must be restored even when the content is
        // unchanged: a clipboard-mode close clears it while the pool
        // survives, and without this every keystroke would re-hit the data
        // source after a reopen.
        root._pooledMode = pooledMode
        var filtered = LauncherLogic.filterResults(root.displayPool, requestText, root.category)
        // A first batch is a fresh commit and starts at the top like any
        // other; a batch that only appends keeps the row the user is on, and
        // falls back to clamping the old index when that row is gone.
        root.selectedIndex = appending
                ? LauncherLogic.preservedSelection(previous, root.selectedIndex, filtered)
                : (requestText.length > 0
                   ? LauncherLogic.refilterSelection(previous, root.selectedIndex, filtered)
                   : LauncherLogic.clampSelection(0, filtered.length))
        // Same array-identity guard as the pooled path: unchanged ids must
        // not reassign results or the surface replays its refill animation.
        root.results = LauncherLogic.poolMatches(previous, filtered)
                ? previous : filtered
        // The chip counts follow the data, but only where they are true: the
        // opening batch is what the rail can show at all, and the completing
        // batch is when the numbers are final. The batches in between are only
        // counted into the running tally - a pass over the batch rather than
        // over everything - and publish nothing, so the numbers do not step
        // while the list is still filling.
        root.tallyCategorySummary(batch)
        if (!appending || complete)
            root.publishCategorySummary(complete === true)
    }

    // Background revalidation for change announcers (desktop-entry rescans,
    // launch-count updates): the pooled apps list is refreshed on demand
    // when the underlying data changes instead of on every open. Visible
    // sessions ride the normal force-pull commit (loading/error/cascade
    // semantics); closed sessions swap only the pooled array so the next
    // open starts from fresh data without touching visible state.
    //
    // Neither idle path streams: nothing is on screen to paint progressively,
    // and a background swap wants one atomic compare-and-set.
    function revalidatePool() {
        if (root.visible) {
            if (root.mode === "apps")
                root.refresh(true)
            return
        }
        if (root._pooledMode !== "apps" || root.displayPool.length === 0)
            return
        // Only a registered adapter may answer; the neutral fallback would
        // resolve to an empty set and silently wipe the pool.
        var registered = root._adapters ? root._adapters["apps"] : null
        if (!registered || typeof registered.refresh !== "function")
            return
        var adapter = root._adapterFor("apps")
        var token = ++_refreshToken
        var collected = []
        var answered = false
        adapter.refresh("", "apps", function(outcome, complete) {
            if (token !== _refreshToken)
                return
            if (Array.isArray(outcome)) {
                collected = collected.concat(outcome)
                answered = true
            }
            if (complete === false)
                return
            // While closed there is no error surface; keep the stale pool
            // rather than dropping it on a transient source failure.
            if (!answered)
                return
            // Same transient-empty protection as the visible path: a
            // background pull that resolves an app to an empty icon must
            // not wipe the healthy pooled row, or the next open serves
            // a batch of blank icons.
            var sorted = LauncherLogic.preferStableIcons(
                root.displayPool, LauncherLogic.sortResults(collected))
            if (!LauncherLogic.poolMatches(sorted, root.displayPool)) {
                root.displayPool = sorted
                root.publishCategorySummary(true)
            }
        })
    }

    function selectNext() {
        root.noteInput()
        root.selectedIndex = LauncherLogic.clampSelection(root.selectedIndex + 1, root.results.length)
    }

    function selectPrevious() {
        root.noteInput()
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
        if (!item || !root.visible || !root.interactive || root._executionInFlight)
            return
        root._executionInFlight = true
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
        root._executionInFlight = false
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
