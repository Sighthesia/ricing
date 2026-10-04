pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "launcher/LauncherAdapters.js" as LauncherAdapters

// Clipboard history backed by cliphist; polled on a timer so the UI stays fresh.
Singleton {
    id: root

    readonly property string _userCacheRoot: (Quickshell.env("XDG_CACHE_HOME") || ((Quickshell.env("HOME") || "") + "/.cache"))
    readonly property string _cacheDir: root._userCacheRoot + "/afloat"
    readonly property string _firstSeenCachePath: root._cacheDir + "/clipboard-first-seen.json"
    readonly property string _metadataCachePath: root._cacheDir + "/clipboard-metadata.json"

    property bool available: false
    // Mirrors _listProc.listing: a cliphist list fetch is in flight.
    property bool listing: false
    // True once the startup cliphist probe has exited, so consumers can
    // distinguish "still probing" from "definitively unavailable".
    property bool probeFinished: false
    property var items: []
    property int revision: 0
    property int firstSeenRevision: 0
    property int firstSeenDisplayRevision: 0
    property int metadataRevision: 0
    property var _firstSeenById: ({})
    property var _firstSeenBySignature: ({})
    property var _metadataCacheById: ({})
    property bool _metadataDirty: false
    property bool _metadataCacheReady: false
    property bool _createMetadataCache: false
    property var _metadataQueueIds: []
    property bool _metadataBusy: false
    // A fetch that landed while a metadata batch was running: the queue is
    // rebuilt against the newer rows once that batch returns, instead of
    // leaving them without metadata until the next poll.
    property bool _metadataRestartPending: false
    property var _pendingSignatureIds: []
    property var _pendingSignatureRows: ({})
    property var _signaturePendingById: ({})
    // Copy seeds: entries the shell just copied back are recreated by
    // cliphist with a fresh id; unknown ids matching a seed inherit its
    // timestamp so the row never jumps to the top before the async
    // content-signature recovery confirms the same timestamp.
    property var _recentCopySeeds: []
    property bool _firstSeenDirty: false
    property bool _firstSeenCacheReady: false
    property bool _createFirstSeenCache: false
    property bool _initialFirstSeenRecovery: false
    property bool _firstListLoaded: false

    // ---- List parse state ------------------------------------------------
    // A 750-row history parsed in one turn blocked the event loop for tens of
    // milliseconds, which a launcher open landing in that window paid in full.
    // The parse therefore publishes slices: the first slice is exactly one
    // consumer batch (LauncherAdapters.clipboardChunkSize is 64), the rest
    // follows a slice per turn, and no turn's cost grows with history length.
    property var _parseLines: []
    property var _parseRows: []
    property int _parseIndex: 0
    property bool _parseRunning: false
    property bool _parsePublished: false
    // id -> row for the published history. The metadata merge and first-seen
    // confirmation both look rows up by id; scanning the array instead made
    // every one of the ~750 signature completions walk all 750 rows.
    property var _itemById: ({})

    // ---- Background work pacing ------------------------------------------
    // Not motion tokens: these pace a data pipeline, not an animation. They
    // bound how much of the event loop the background queues may take when the
    // foreground is idle, and the queues stop entirely while it is not.
    readonly property int _parseFirstSliceRows: 64
    readonly property int _parseSliceRows: 192
    readonly property int _metadataBatchSize: 16
    readonly property int _metadataGapMs: 24
    readonly property int _signatureGapMs: 16
    // How long a gated queue waits before looking again, so a foreground that
    // stops touching the service can never strand the queue.
    readonly property int _foregroundRetryMs: 120
    // Held after any foreground-only entry point (preview, thumbnail, a
    // consumer's explicit hint) so a burst of foreground reads is one yield,
    // not one yield per row.
    readonly property int _foregroundHoldMs: 250

    // ---- Foreground priority ---------------------------------------------
    // A launcher open pulls rows and metadata merges through this service and
    // requests previews and thumbnails; those are foreground-only paths, so
    // they are what the background queues yield to. setForegroundBusy() lets a
    // consumer hold the gate for a whole open instead of relying on touches.
    property bool _foregroundBusy: false
    readonly property bool _foregroundActive: root._foregroundBusy || _foregroundHoldTimer.running

    property Process _cacheDirProc: Process {
        command: ["mkdir", "-p", root._cacheDir]
        running: false
        onExited: code => {
            if (code === 0 && root._createFirstSeenCache) {
                root._createFirstSeenCache = false
                firstSeenFile.writeAdapter()
            }
            if (code === 0 && root._createMetadataCache) {
                root._createMetadataCache = false
                metadataFile.writeAdapter()
            }
        }
    }

    Timer {
        id: firstSeenSaveTimer
        interval: 500
        repeat: false
        onTriggered: firstSeenFile.writeAdapter()
    }

    Timer {
        id: metadataSaveTimer
        interval: 1000
        repeat: false
        onTriggered: metadataFile.writeAdapter()
    }

    FileView {
        id: firstSeenFile
        path: root._firstSeenCachePath
        blockLoading: true
        onLoaded: root._finishFirstSeenCacheLoad(firstSeenAdapter.firstSeenMap)
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root._createFirstSeenCache = true
                if (!_cacheDirProc.running)
                    _cacheDirProc.running = true
                root._finishFirstSeenCacheLoad({})
            } else {
                console.warn("ClipboardService: failed to load first-seen cache, error =", error)
                root._finishFirstSeenCacheLoad({})
            }
        }

        JsonAdapter {
            id: firstSeenAdapter
            property var firstSeenMap: ({})
        }
    }

    FileView {
        id: metadataFile
        path: root._metadataCachePath
        blockLoading: true
        onLoaded: root._finishMetadataCacheLoad(metadataAdapter.metadataMap)
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root._createMetadataCache = true
                if (!_cacheDirProc.running)
                    _cacheDirProc.running = true
                root._finishMetadataCacheLoad({})
            } else {
                console.warn("ClipboardService: failed to load metadata cache, error =", error)
                root._finishMetadataCacheLoad({})
            }
        }

        JsonAdapter {
            id: metadataAdapter
            property var metadataMap: ({})
        }
    }

    signal listCompleted
    signal firstSeenUpdated(string id, real firstSeenMs)
    signal metadataUpdated(string id)

    // Probe for cliphist at startup so we never attempt commands on missing tools.
    property Process _checkProc: Process {
        command: ["sh", "-c", "command -v cliphist"]
        running: false

        stdout: StdioCollector {}

        onExited: code => {
            root.probeFinished = true
            root.available = (code === 0)
            // Pre-fetch history immediately so the first panel open is not blank.
            if (root.available) root.list()
        }
    }

    // Fetches the full history; output is line-separated "<id>\t<preview>" entries.
    property Process _listProc: Process {
        id: listProc
        command: ["cliphist", "list"]
        running: false

        // True while a cliphist list is in flight, so consumers can wait
        // for fresh data instead of binding a stale snapshot.
        property bool listing: false
        onListingChanged: root.listing = listing
        onRunningChanged: listing = running

        stdout: StdioCollector {
            // Everything expensive about a list lands here, so it hands the
            // output to the slice pump instead of parsing it inline: the first
            // slice is published in this same turn and the rest follows one
            // turn at a time.
            onStreamFinished: root._beginListParse(this.text)
        }
    }

    // ---- Incremental list parse ------------------------------------------
    // Rows are built and published in slices so a consumer never waits for the
    // whole history and no single turn's cost grows with its length. The
    // published array is always a prefix of the finished list in the same
    // order, so a consumer that reads mid-parse sees a valid ordered subset.
    // listCompleted still fires only once the full list is committed, and
    // revision still moves exactly once per fetch, which is what
    // LauncherAdapters' refresh() uses to tell "never loaded" from "loading".
    property Timer _parseTimer: Timer {
        interval: 0
        repeat: false
        onTriggered: root._pumpListParse()
    }

    function _beginListParse(text) {
        // A fetch that arrives mid-parse replaces the pending one: same
        // last-fetch-wins rule the single-turn parse had.
        root._parseLines = text.trim().split("\n")
        root._parseRows = []
        root._parseIndex = 0
        root._parsePublished = false
        root._parseRunning = true
        root._itemById = ({})
        root._pumpListParse()
    }

    function _pumpListParse() {
        if (!root._parseRunning)
            return
        var lines = root._parseLines
        var limit = root._parsePublished ? root._parseSliceRows : root._parseFirstSliceRows
        var end = Math.min(lines.length, root._parseIndex + limit)
        for (var index = root._parseIndex; index < end; index++)
            root._appendListRow(lines[index], index)
        root._parseIndex = end
        root._publishParsedRows()
        if (root._parseIndex < lines.length) {
            root._parseTimer.restart()
            return
        }
        root._finishListParse()
    }

    // One history row.
    function _appendListRow(line, lineIndex) {
        let parsed = LauncherAdapters.splitClipboardListLine(line)
        if (!parsed)
            return
        // cliphist separates id and preview with a tab
        let id = parsed.id
        let preview = parsed.preview
        let isImage = LauncherAdapters.isClipboardImagePreview(preview)
        if (!root._firstSeenById[id]) {
            // Entries the shell just copied back surface here with
            // a fresh id; inherit the original timestamp so the row
            // keeps its position instead of jumping to the top
            // until signature recovery confirms the same value.
            var seededMs = LauncherAdapters.matchClipboardCopySeed(
                root._recentCopySeeds, preview, isImage, Date.now())
            root._firstSeenById[id] = seededMs > 0 ? seededMs : Date.now()
            root._firstSeenDirty = true
            root._enqueueFirstSeenSignature(id, lineIndex)
        }
        let mime = LauncherAdapters.clipboardMimeForPreview(preview, isImage)
        let row = { id: id, preview: preview, isImage: isImage, mime: mime,
                    firstSeenMs: root._firstSeenById[id] }
        root._itemById[id] = row
        root._parseRows.push(row)
    }

    function _publishParsedRows() {
        // A fresh array per publish: consumers may hold on to the array they
        // read, and a snapshot is what lets the parse keep appending.
        root.items = root._parseRows.slice()
        root._parsePublished = true
    }

    function _finishListParse() {
        root._parseRunning = false
        root._parseLines = []
        root.revision++
        root._startMetadataQueue()
        if (!root._firstListLoaded) {
            root._firstListLoaded = true
            // Pre-seeded rows skip the assign path above, so enqueue
            // them here for signature learning (dedup skips the ones
            // just enqueued): a later copy-back then resolves to the
            // original timestamp instead of learning the jump time.
            for (var learnIndex = 0; learnIndex < root.items.length; learnIndex++)
                root._enqueueFirstSeenSignature(String(root.items[learnIndex].id), learnIndex)
            root._initialFirstSeenRecovery = true
            root._finishInitialFirstSeenRecovery()
        }
        root.listCompleted()
    }

    property Process _firstSeenSignatureProc: Process {
        id: firstSeenSignatureProc
        command: []
        running: false
        stdout: StdioCollector {}
        onExited: code => {
            var id = root._currentSignatureId
            var rowIndex = root._currentSignatureRow
            var signature = stdout.text.trim()
            root._currentSignatureId = ""
            root._currentSignatureRow = -1
            if (id)
                delete root._signaturePendingById[id]
            if (id && code === 0 && signature) {
                var firstSeenMs = root._firstSeenBySignature[signature]
                if (!firstSeenMs) {
                    firstSeenMs = root._firstSeenById[id] || Date.now()
                    root._firstSeenBySignature[signature] = firstSeenMs
                    root._firstSeenDirty = true
                }
                root._firstSeenById[id] = firstSeenMs
                root._applyFirstSeenToItems(id, firstSeenMs)
                if (rowIndex >= 0)
                    delete root._pendingSignatureRows[rowIndex]
                root._persistFirstSeenMap()
            }
            // The next job is not started here: going straight back into the
            // pump is what turned this queue into a back-to-back spawn loop.
            // The gate timer keeps one decode per _signatureGapMs.
            root._armSignatureGate(root._signatureGapMs)
            root._finishInitialFirstSeenRecovery()
        }
    }

    // Resolve exact text lengths and image dimensions after the lightweight
    // cliphist list has reached the UI. This keeps first paint independent of
    // per-entry decoding while making metadata authoritative when it lands.
    //
    // The queue runs in batches rather than as one long-lived process over the
    // whole history: a single pass decodes every uncached row back to back for
    // as long as it takes, which is the other half of the background load the
    // foreground used to sit behind. Batches are resumable (the pending ids
    // live in the service), rate limited between batches, and yield entirely
    // while a consumer is reading.
    property Timer _metadataBatchTimer: Timer {
        interval: root._metadataGapMs
        repeat: false
        onTriggered: root._pumpMetadataQueue()
    }

    property Process _metadataProc: Process {
        id: metadataProc
        command: []
        running: false
        stdout: StdioCollector {}
        onExited: exitCode => {
            root._metadataBusy = false
            if (exitCode === 0)
                root._mergeMetadataBatch(stdout.text)
            if (root._metadataRestartPending) {
                root._metadataRestartPending = false
                root._rebuildMetadataQueue()
            }
            if (root._metadataQueueIds.length) {
                root._armMetadataGate(root._metadataGapMs)
            } else {
                // One announcement per completed pass, as before: a consumer's
                // metadata merge re-reads the whole history, so announcing per
                // batch would multiply a ~100 ms merge by the batch count.
                root._persistMetadataCache()
                root.metadataUpdated("")
            }
        }
    }

    function _armMetadataGate(intervalMs) {
        root._metadataBatchTimer.interval = intervalMs
        root._metadataBatchTimer.restart()
    }

    // Merges one batch's output. Bounded by the batch size: rows are reached
    // through the id index instead of rescanning the whole history.
    function _mergeMetadataBatch(output) {
        var byId = ({})
        var outputLines = String(output).split("\n")
        for (var lineIndex = 0; lineIndex < outputLines.length; lineIndex++) {
            var line = outputLines[lineIndex]
            var parts = line.trim().split("|")
            if (parts.length < 3)
                continue
            byId[parts[0]] = parts.slice(1)
        }
        for (var id in byId) {
            if (!Object.prototype.hasOwnProperty.call(byId, id))
                continue
            var item = root._itemById[id]
            if (!item)
                continue
            var metadata = byId[id]
            var updated = false
            if (metadata[0] === "image" && metadata.length >= 6) {
                item.imageFormat = metadata[1]
                item.imageWidth = Number(metadata[2])
                item.imageHeight = Number(metadata[3])
                item.imageBytes = Number(metadata[4])
                item.metadataReady = true
                updated = true
            } else if (metadata[0] === "text" && /^\d+$/.test(metadata[1])) {
                item.textCharCount = Number(metadata[1])
                item.metadataReady = true
                updated = true
            }
            if (!updated)
                continue
            if (item.isImage) {
                root._metadataCacheById[id] = {
                    preview: item.preview,
                    isImage: true,
                    format: item.imageFormat,
                    width: item.imageWidth,
                    height: item.imageHeight,
                    bytes: item.imageBytes
                }
            } else {
                root._metadataCacheById[id] = {
                    preview: item.preview,
                    isImage: false,
                    textCharCount: item.textCharCount
                }
            }
            root._metadataDirty = true
            root.metadataRevision++
        }
        root._persistMetadataCache()
    }

    function _pruneMetadataCache() {
        var pruned = false
        var liveIds = ({})
        for (var index = 0; index < root.items.length; index++) {
            liveIds[String(root.items[index].id)] = true
        }
        for (var cachedId in root._metadataCacheById) {
            if (!liveIds[cachedId]) {
                delete root._metadataCacheById[cachedId]
                pruned = true
            }
        }
        if (pruned)
            root._persistMetadataCache()
    }

    function _persistMetadataCache() {
        if (!root._metadataDirty)
            return
        root._metadataDirty = false
        metadataAdapter.metadataMap = root._metadataCacheById
        metadataSaveTimer.restart()
    }

    function _startMetadataQueue() {
        if (!root.items.length || !root.available)
            return
        // The cached metadata is cheap and applies to the rows the consumer is
        // reading right now, so it goes on even when a batch is in flight.
        root._rebuildMetadataQueue()
        if (root._metadataBusy) {
            root._metadataRestartPending = true
            return
        }
        root._pumpMetadataQueue()
    }

    function _rebuildMetadataQueue() {
        if (!root.items.length)
            return
        root._pruneMetadataCache()
        LauncherAdapters.applyClipboardMetadataCache(root.items, root._metadataCacheById)
        var ids = []
        for (var index = 0; index < root.items.length; index++) {
            // Images already carry synchronous preview metadata; their exact
            // bytes are resolved when their visible thumbnail is decoded.
            if (root.items[index].metadataReady || root.items[index].isImage)
                continue
            ids.push(String(root.items[index].id))
        }
        root._metadataQueueIds = ids
    }

    function _pumpMetadataQueue() {
        if (root._metadataBusy || !root._metadataQueueIds.length || !root.available)
            return
        if (root._foregroundActive) {
            root._armMetadataGate(root._foregroundRetryMs)
            return
        }
        var take = Math.min(root._metadataBatchSize, root._metadataQueueIds.length)
        var args = ["sh", "-c",
            ""
                + "while [ \"$#\" -gt 0 ]; do "
                + "id=\"$1\"; shift; "
                + "count=$(cliphist decode \"$id\" 2>/dev/null | wc -m); "
                + "printf '%s|text|%s\\n' \"$id\" \"$count\"; done",
            "afloat-clipboard-meta"]
        for (var index = 0; index < take; index++)
            args.push(root._metadataQueueIds[index])
        root._metadataQueueIds = root._metadataQueueIds.slice(take)
        metadataProc.command = args
        root._metadataBusy = true
        metadataProc.running = true
    }
    property string _currentSignatureId: ""
    property int _currentSignatureRow: -1

    // Fire-and-forget action processes; no output needed, errors are silently ignored
    // because clipboard ops are best-effort from the shell's perspective.
    property Process _actionProc: Process {
        id: actionProc
        command: []
        running: false
    }

    property Timer _pollTimer: Timer {
        interval: 5000
        repeat: true
        running: root.available
        onTriggered: root.list()
    }

    function list() {
        if (!root.available || !root._firstSeenCacheReady || listProc.running) return
        listProc.running = true
    }

    // Explicit startup hook: constructing the singleton begins cache loading
    // and the cliphist probe before the first clipboard launcher open.
    function warmup() {
        return root.available
    }

    // ---- Foreground priority ---------------------------------------------
    // Background decode queues (metadata counts, content signatures) exist to
    // enrich the history after it is already on screen, so they must never be
    // the reason a launcher open waits. A consumer that is reading the service
    // can hold the gate for the whole read; the foreground-only entry points
    // below (preview decodes, thumbnail decodes) hold it implicitly for a
    // moment after each request, which covers an open that only scrolls.
    property Timer _foregroundHoldTimer: Timer {
        interval: root._foregroundHoldMs
        repeat: false
        onTriggered: root._resumeBackgroundWork()
    }

    function setForegroundBusy(busy) {
        root._foregroundBusy = !!busy
        if (!root._foregroundBusy)
            root._resumeBackgroundWork()
    }

    function _noteForegroundTouch() {
        root._foregroundHoldTimer.restart()
    }

    // Called when the implicit hold lapses, and when a consumer releases the
    // explicit gate: both queues look again immediately instead of waiting out
    // their next gap.
    function _resumeBackgroundWork() {
        root._pumpMetadataQueue()
        root._pumpSignatureQueue()
    }

    function _finishFirstSeenCacheLoad(firstSeenMap) {
        if (root._firstSeenCacheReady)
            return
        var split = LauncherAdapters.splitFirstSeenCache(firstSeenMap)
        root._firstSeenBySignature = split.signatures
        // Pre-seed row timestamps so the first paint already carries correct
        // dates and order; signature recovery then only confirms silently.
        root._firstSeenById = split.ids
        root._firstSeenCacheReady = true
        root._maybeStartClipboardProbe()
    }

    function _finishMetadataCacheLoad(metadataMap) {
        if (root._metadataCacheReady)
            return
        root._metadataCacheById = metadataMap || ({})
        root._metadataCacheReady = true
        root._maybeStartClipboardProbe()
    }

    function _maybeStartClipboardProbe() {
        if (!root._firstSeenCacheReady || !root._metadataCacheReady)
            return
        if (root.probeFinished || _checkProc.running)
            return
        _checkProc.running = true
    }

    // ---- First-seen signature queue --------------------------------------
    // One cliphist decode per pending id, strictly one at a time, and now rate
    // limited: a bare pump on every enqueue spawned a process from inside the
    // list parse and then kept spawning back-to-back for the whole drain.
    property Timer _signatureGateTimer: Timer {
        interval: root._signatureGapMs
        repeat: false
        onTriggered: root._pumpSignatureQueue()
    }

    function _armSignatureGate(intervalMs) {
        root._signatureGateTimer.interval = intervalMs
        root._signatureGateTimer.restart()
    }

    function _enqueueFirstSeenSignature(id, rowIndex) {
        if (!id || root._signaturePendingById[id])
            return
        root._signaturePendingById[id] = true
        root._pendingSignatureRows[rowIndex] = true
        // Pushed in place. The queue drains at a bounded rate, so it grows to
        // hundreds of entries while the list parse runs; copying it per
        // enqueue made the parse quadratic.
        root._pendingSignatureIds.push({ id: id, rowIndex: rowIndex })
        if (!root._signatureGateTimer.running)
            root._armSignatureGate(root._signatureGapMs)
    }

    function _pumpSignatureQueue() {
        if (firstSeenSignatureProc.running || !root._pendingSignatureIds.length)
            return
        if (root._foregroundActive) {
            // Yield to the foreground and look again shortly: the queue is
            // resumable, so waiting costs nothing but time.
            root._armSignatureGate(root._foregroundRetryMs)
            return
        }
        var next = root._pendingSignatureIds.shift()
        root._currentSignatureId = next.id
        root._currentSignatureRow = next.rowIndex
        firstSeenSignatureProc.command = [
            "sh", "-c",
            'cliphist decode "$1" | sha256sum | cut -d" " -f1',
            "afloat-clip-first-seen",
            next.id,
        ]
        firstSeenSignatureProc.running = true
    }

    function _applyFirstSeenToItems(id, firstSeenMs) {
        if (!id || !root.items.length)
            return
        var item = root._itemById[id]
        if (!item || String(item.id) !== String(id))
            return
        if (item.firstSeenMs === firstSeenMs)
            return
        item.firstSeenMs = firstSeenMs
        root.firstSeenRevision++
        if (!root._initialFirstSeenRecovery)
            root.firstSeenDisplayRevision++
        root.firstSeenUpdated(id, firstSeenMs)
    }

    function _finishInitialFirstSeenRecovery() {
        if (!root._initialFirstSeenRecovery || firstSeenSignatureProc.running || root._pendingSignatureIds.length)
            return
        root._initialFirstSeenRecovery = false
        root.firstSeenDisplayRevision++
    }

    function firstSeenMsForId(id) {
        if (!id)
            return 0
        return root._firstSeenById[id] || 0
    }

    function _persistFirstSeenMap() {
        if (!root._firstSeenDirty)
            return
        root._firstSeenDirty = false
        firstSeenAdapter.firstSeenMap = LauncherAdapters.packFirstSeenCache(
            root._firstSeenBySignature, root._firstSeenById, root.items)
        firstSeenSaveTimer.restart()
    }

    function copyItem(id: string) {
        if (!root.available) return
        root._rememberCopySeed(id)
        actionProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"]
        actionProc.running = true
    }

    // Decode image entries to cached files and report their paths. Jobs run
    // through ONE persistent process (a transient Qt.createQmlObject process
    // gets garbage-collected before exiting and silently drops callbacks);
    // repeat requests skip cliphist via the on-disk cache test.
    property var _thumbQueue: []
    property bool _thumbBusy: false

    function _clipboardItemById(id) {
        var wanted = String(id == null ? "" : id)
        return root._itemById[wanted] || null
    }

    function _storeImageMetadata(item, format, width, height, bytes) {
        if (!item || !item.isImage)
            return false
        var imageWidth = Number(width)
        var imageHeight = Number(height)
        var imageBytes = Number(bytes)
        if (!format || imageWidth <= 0 || imageHeight <= 0 || !(imageBytes >= 0))
            return false
        item.imageFormat = format
        item.imageWidth = imageWidth
        item.imageHeight = imageHeight
        item.imageBytes = imageBytes
        item.metadataReady = true
        root._metadataCacheById[String(item.id)] = {
            preview: item.preview,
            isImage: true,
            format: item.imageFormat,
            width: item.imageWidth,
            height: item.imageHeight,
            bytes: item.imageBytes
        }
        root._metadataDirty = true
        root.metadataRevision++
        return true
    }

    function decodeThumbnail(id: string, mime: string, callback: var) {
        var safeId = String(id == null ? "" : id)
        if (!root.available || !/^[0-9]+$/.test(safeId)) {
            if (callback) callback("")
            return
        }
        // A thumbnail is only ever decoded for a row the user can see, so it is
        // a foreground signal like a preview.
        root._noteForegroundTouch()
        var ext = "png"
        var m = String(mime == null ? "" : mime).toLowerCase()
        if (m.indexOf("jpeg") >= 0 || m.indexOf("jpg") >= 0) ext = "jpg"
        else if (m.indexOf("webp") >= 0) ext = "webp"
        else if (m.indexOf("gif") >= 0) ext = "gif"
        var dir = root._cacheDir + "/clipboard-thumbs"
        var path = dir + "/" + safeId + "." + ext
        root._thumbQueue.push({ path: path, clipId: safeId, cb: callback })
        root._pumpThumbQueue()
    }

    function _pumpThumbQueue() {
        if (root._thumbBusy || !root._thumbQueue.length)
            return
        var job = root._thumbQueue.shift()
        root._thumbBusy = true
        thumbProc.job = job
        var target = root._clipboardItemById(job.clipId)
        var probeImage = !!target && target.isImage && !target.metadataReady
        thumbProc.probeImage = probeImage
        var ensureThumbnail = "mkdir -p '" + root._cacheDir + "/clipboard-thumbs' && { test -f '" + job.path + "' || cliphist decode " + job.clipId + " > '" + job.path + "'; }"
        if (probeImage) {
            ensureThumbnail += " && dims=$(identify -format '%m|%w|%h' '" + job.path + "' 2>/dev/null);"
                + " bytes=$(wc -c < '" + job.path + "' 2>/dev/null | tr -d ' ');"
                + " [ -n \"$dims\" ] && [ -n \"$bytes\" ] && printf '%s|%s' \"$dims\" \"$bytes\""
        }
        thumbProc.command = ["sh", "-c", ensureThumbnail]
        thumbProc.running = true
    }

    property Process thumbProc: Process {
        id: thumbProc
        command: []
        running: false
        property var job: null
        property bool probeImage: false
        stdout: StdioCollector {}
        onExited: {
            var done = job
            var probeOutput = stdout.text.trim().split("|")
            job = null
            probeImage = false
            root._thumbBusy = false
            if (done && done.cb)
                done.cb(done.path)
            if (done && probeOutput.length >= 4) {
                var target = root._clipboardItemById(done.clipId)
                if (root._storeImageMetadata(target, probeOutput[0], probeOutput[1], probeOutput[2], probeOutput[3])) {
                    root._persistMetadataCache()
                    root.metadataUpdated(String(done.clipId))
                }
            }
            root._pumpThumbQueue()
        }
    }

    function pasteItem(id: string) {
        if (!root.available) return
        // Decode into clipboard then synthesise the paste shortcut via wtype
        root._rememberCopySeed(id)
        actionProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy && wtype -M ctrl -M shift v"]
        actionProc.running = true
    }

    // Records the timestamp of the entry being copied back so its cliphist
    // recreation (fresh id, same content) inherits the original position.
    function _rememberCopySeed(id) {
        var key = String(id == null ? "" : id)
        var item = key ? root._clipboardItemById(key) : null
        var seen = Number(root._firstSeenById[key]) || 0
        if (!(seen > 0) && item)
            seen = Number(item.firstSeenMs) || 0
        root._recentCopySeeds = LauncherAdapters.rememberClipboardCopySeed(
            root._recentCopySeeds,
            item ? item.preview : "",
            item ? !!item.isImage : false,
            seen,
            Date.now())
    }

    // Separate process for delete so we can reliably refresh after exit.
    property Process _deleteProc: Process {
        id: deleteProc
        command: []
        running: false
        stdout: StdioCollector {}
        onExited: root.list()
    }

    function deleteItem(id: string) {
        if (!root.available) return
        deleteProc.command = ["sh", "-c", "echo " + id + " | cliphist delete"]
        deleteProc.running = true
    }

    function wipeAll() {
        if (!root.available) return
        Quickshell.execDetached(["cliphist", "wipe"])
        root.items = []
        root._itemById = ({})
        root._firstSeenById = ({})
        root._recentCopySeeds = []
        root._metadataCacheById = ({})
        // A wipe invalidates every queue: the pending ids, rows and signature
        // jobs all refer to entries that no longer exist.
        root._parseRunning = false
        root._parseLines = []
        root._parseRows = []
        root._parseIndex = 0
        root._parsePublished = false
        root._parseTimer.running = false
        root._metadataQueueIds = []
        root._metadataRestartPending = false
        root._metadataBatchTimer.running = false
        root._pendingSignatureIds = []
        root._pendingSignatureRows = ({})
        root._signaturePendingById = ({})
        root._signatureGateTimer.running = false
        root._initialFirstSeenRecovery = false
        root._metadataDirty = true
        root._persistMetadataCache()
        root._firstSeenDirty = true
        root._persistFirstSeenMap()
        root.revision++
    }

    // ---- Preview support: decode an item for inline preview. ----
    // Decodes run one at a time through a small queue; every completion
    // keeps its own id so rapid selection changes preview the current item
    // instead of misattributing in-flight content to the newest request.
    property string _previewRequestId: ""
    // Tracks which id the currently running process belongs to.
    property string _runningDecodeId: ""
    property string _runningDecodePath: ""
    property var _previewQueue: []
    property int _previewRevision: 0
    signal previewDecoded(string id, string contentOrPath)

    property Process _previewDecodeProc: Process {
        id: previewDecodeProc
        command: []
        running: false
        stdout: StdioCollector {}
        onExited: (code) => {
            var runningId = root._runningDecodeId
            var runningPath = root._runningDecodePath
            root._runningDecodeId = ""
            root._runningDecodePath = ""
            if (runningId && code === 0) {
                if (root._previewDecodeIsImage) {
                    // Image was piped to a temp file by the shell command.
                    root._previewRevision++
                    root.previewDecoded(runningId, "file://" + runningPath + "?rev=" + root._previewRevision)
                } else {
                    root.previewDecoded(runningId, stdout.text)
                }
            }
            root._pumpPreviewQueue()
        }
    }
    property bool _previewDecodeIsImage: false

    // Initiate async decoding of an item for preview.
    // For images the result is a file:// URL; for text the raw content string.
    function requestPreview(id, isImage) {
        if (!root.available || !id) return
        var key = String(id)
        root._previewRequestId = key
        root._noteForegroundTouch()
        // A decode already in flight keeps its own identity; queue behind it
        // instead of overwriting the running id.
        if (previewDecodeProc.running) {
            if (root._runningDecodeId === key)
                return
            root._previewQueue = LauncherAdapters.queuePreviewDecode(root._previewQueue, key, isImage)
            return
        }
        root._startPreviewDecode(key, !!isImage)
    }

    // Runs queued preview decodes newest-first (popped at start so a failed
    // head still drains) so rapid navigation previews the current selection
    // within one decode while every queued decode still fills its cache.
    function _pumpPreviewQueue() {
        if (previewDecodeProc.running)
            return
        var next = LauncherAdapters.takeNewestPreviewDecode(root._previewQueue)
        if (!next)
            return
        root._startPreviewDecode(next.id, next.isImage)
    }

    function _startPreviewDecode(key, isImage) {
        root._previewDecodeIsImage = isImage
        if (isImage) {
            var safeName = encodeURIComponent(key).replace(/%/g, "_")
            var path = "/tmp/afloat-clip-preview-" + safeName + ".img"
            previewDecodeProc.command = [
                "sh", "-c",
                "cliphist decode \"$1\" > \"$2\"",
                "afloat-clip-preview",
                key,
                path
            ]
            root._runningDecodePath = path
        } else {
            previewDecodeProc.command = ["cliphist", "decode", key]
            root._runningDecodePath = ""
        }
        root._runningDecodeId = key
        previewDecodeProc.running = true
    }

    // Clean up temp preview files for the given id (called when preview changes).
    function discardPreview(id) {
        if (!id) return
        if (root._previewRequestId === id) {
            root._previewRequestId = ""
        }
        var safeName = encodeURIComponent(id).replace(/%/g, "_")
        Quickshell.execDetached(["rm", "-f", "/tmp/afloat-clip-preview-" + safeName + ".img"])
    }

    Component.onCompleted: {
        if (!_cacheDirProc.running)
            _cacheDirProc.running = true
    }
}
