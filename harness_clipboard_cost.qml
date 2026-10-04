import QtQuick
import Quickshell
import "./services" as Services
import "./services/launcher/LauncherAdapters.js" as LauncherAdapters

// Headless cost probe for services/ClipboardService.qml. No window, no
// compositor, no PanelWindow: it drives the real singleton against the real
// cliphist database and reports where its time actually goes.
//
// Instrumentation, and why each piece is here:
//   * Date.now() - measured on this build to be real wall time (a 2.45 s busy
//     turn reports 2450 ms, and new Date().toISOString() matches `date -u`),
//     so it is the timeline inside the process.
//   * A 1 ms repeating Timer as a stall sampler. While a turn holds the event
//     loop the timer cannot be serviced, so the gap between two samples IS the
//     turn; idle noise on this box reaches ~22 ms, which is why the report
//     prints percentiles and not just the maximum.
//   * A compiled cliphist shim first on PATH, writing every invocation's
//     CLOCK_REALTIME into one log. Process creation costs ~2.7 ms here and a
//     shell wrapper added ~7.6 ms per call, which would have swamped a ~1500
//     call timeline. The shim's phase markers share that file, so overlap
//     between background work and a foreground open is one subtraction.
//
// What it reports:
//   1. how long the list-completion turn blocks the event loop,
//   2. when the first row slice becomes readable relative to the fetch,
//   3. how many cliphist calls each background queue starts, and their span
//      (read from the shim log; this file prints the in-process residue),
//   4. foreground open latency - the real adapter reading the real backend -
//      swept across the poll/turn window, which is what the user feels.
Item {
    id: root
    width: 800
    height: 600

    readonly property string shimPath: "/tmp/opencode/clipcost/bin/cliphist"
    // Upper bound on waiting for the background queues to go idle before
    // reporting a cap breach instead of hanging.
    property int drainCapMs: 200000
    // Foreground opens are swept across the fetch window in this step.
    property int trialStepMs: 10
    property int trials: 12

    // ---- Stall sampler ----------------------------------------------------
    property var _gaps: []
    property bool _sampling: false
    property real _prevSample: 0

    property Timer _sampler: Timer {
        interval: 1
        repeat: true
        running: true
        onTriggered: {
            var t = Date.now()
            if (root._sampling) {
                var d = t - root._prevSample
                if (d > 0)
                    root._gaps.push({ at: t, ms: d })
            }
            root._sampling = true
            root._prevSample = t
        }
    }

    // Keeps the engine's event loop turning even while nothing else is
    // pending; the sampler Timer is only serviced while the loop is hot.
    property var _pumpSteps: 0
    function _pump() {
        root._pumpSteps++
        if (root._phase !== 4)
            Qt.callLater(root._pump)
    }

    function windowStalls(fromMs, toMs, top) {
        var list = []
        var biggest = []
        for (var i = 0; i < root._gaps.length; i++) {
            var g = root._gaps[i]
            if (g.at < fromMs || g.at > toMs)
                continue
            list.push(g.ms)
            biggest.push(g)
        }
        if (!list.length)
            return { n: 0 }
        biggest.sort(function(a, b) { return b.ms - a.ms })
        var sorted = list.slice().sort(function(a, b) { return a - b })
        var sum = 0
        for (var s = 0; s < sorted.length; s++)
            sum += sorted[s]
        var over = 0
        for (var o = 0; o < sorted.length; o++)
            if (sorted[o] > 30)
                over++
        var stamped = []
        for (var b2 = 0; b2 < Math.min(biggest.length, top || 5); b2++)
            stamped.push(biggest[b2].ms + "ms@" + (biggest[b2].at - fromMs))
        return {
            n: sorted.length,
            max: sorted[sorted.length - 1],
            p50: sorted[Math.floor(sorted.length * 0.5)],
            p99: sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * 0.99))],
            mean: Math.round(sum / sorted.length * 100) / 100,
            over30: over,
            // Offsets are relative to fromMs, so a caller can line a stall up
            // against the marks printed in order.
            top: stamped
        }
    }

    // ---- Timeline markers -------------------------------------------------
    function mark(label) {
        root._marks.push(label)
        // QML-side reading of the same instant the shim stamps a few ms later;
        // pairing the two by name lines the in-process and process timelines up.
        root._markTimes.push(Date.now())
        Quickshell.execDetached([root.shimPath, "--mark", label])
    }
    property var _marks: []
    property var _markTimes: []

    // ---- Queue state ------------------------------------------------------
    // Unknown properties read as undefined and are skipped, so one predicate
    // works against the pre-change and post-change service.
    function queueIdle() {
        var svc = Services.ClipboardService
        if (svc._metadataBusy)
            return false
        if (svc._metadataQueueIds && svc._metadataQueueIds.length)
            return false
        if (svc._metadataBatchTimer && svc._metadataBatchTimer.running)
            return false
        if (svc._parseRunning)
            return false
        if (svc._parseTimer && svc._parseTimer.running)
            return false
        if (svc._pendingSignatureIds.length)
            return false
        if (svc._firstSeenSignatureProc.running)
            return false
        if (svc._signatureGateTimer && svc._signatureGateTimer.running)
            return false
        return true
    }

    // ---- Foreground open simulation ---------------------------------------
    // The real adapter against the real backend: the exact read path a
    // launcher open performs, including its 64-row streaming batches.
    property var _adapter: null
    property var _opens: []
    property int _trial: -1
    property int _trialDelayMs: 0

    function makeAdapter() {
        if (!root._adapter) {
            root._adapter = LauncherAdapters.createClipboardAdapter({
                clipboardBackend: Services.ClipboardService,
                schedule: function(step) { Qt.callLater(step) }
            })
        }
        return root._adapter
    }

    function startOpen(trial, delayMs) {
        root._trial = trial
        root._trialDelayMs = delayMs
        root.mark(root._mode + "t" + trial + "_fetch")
        root._fetchAt = Date.now()
        // The instant the consumer asked for the open. A trial that lands
        // inside the list turn cannot see the turn in its own latency - it is
        // dequeued after the turn - so the latency is measured from when the
        // open was due, which is what a waiting user actually experiences.
        root._dueAt = root._fetchAt + delayMs
        Services.ClipboardService.list()
        root._openDelay.interval = delayMs
        root._openDelay.restart()
    }
    property string _mode: ""
    property real _fetchAt: 0
    property real _dueAt: 0

    property Timer _openDelay: Timer {
        interval: 0
        repeat: false
        onTriggered: root.runOpen()
    }

    function runOpen() {
        var adapter = root.makeAdapter()
        root.mark(root._mode + "t" + root._trial + "_open_t0")
        var dequeuedAt = Date.now()
        root._awaitingFirstBatch = true
        adapter.refresh("", "clipboard", function(outcome, complete) {
            if (!root._awaitingFirstBatch)
                return
            root._awaitingFirstBatch = false
            var t1 = Date.now()
            root.mark(root._mode + "t" + root._trial + "_open_batch")
            root._opens.push({
                mode: root._mode,
                trial: root._trial,
                delayMs: root._trialDelayMs,
                t0: root._dueAt,
                t1: t1,
                queueMs: dequeuedAt - root._dueAt,
                rows: Array.isArray(outcome) ? outcome.length : 0
            })
            root._nextTrial.restart()
        })
    }
    property bool _awaitingFirstBatch: false

    property Timer _nextTrial: Timer {
        interval: 150
        repeat: false
        onTriggered: root.onNextTrial()
    }

    function onNextTrial() {
        var next = root._trial + 1
        if (next < root.trials) {
            root.startOpen(next, next * root.trialStepMs)
            return
        }
        root.onTrialSetDone()
    }

    // Where the foreground open's own latency goes. Both halves belong to
    // LauncherAdapters (not this service), but the open cannot be faster than
    // they are, so the harness attributes the number instead of guessing. It
    // runs once per sweep so the curve across the queues' lifetime is visible.
    function measureAdapterCost(label) {
        var items = Services.ClipboardService.items
        var a = Date.now()
        var source = LauncherAdapters.clipboardStreamSource(items)
        var b = Date.now()
        var mapped = 0
        for (var i = 0; i < 64 && i < source.length; i++) {
            var row = LauncherAdapters.clipboardItem(source[i], null)
            if (row)
                mapped++
        }
        var c = Date.now()
        var entry = { at: label, sortMs: b - a, map64Ms: c - b, rows: source.length, mapped: mapped }
        if (!root._adapterCosts)
            root._adapterCosts = []
        root._adapterCosts.push(entry)
        console.log("ADAPTERCOST " + label + " sort=" + entry.sortMs + "ms"
                    + " mapFirst64=" + entry.map64Ms + "ms rows=" + entry.rows)
    }

    // ---- Service observation ---------------------------------------------
    property Connections _svc: Connections {
        target: Services.ClipboardService
        function onListCompleted() {
            root._listCompletedCount++
            if (root._firstCompletedMs === 0) {
                root._firstCompletedMs = Date.now()
                root.mark("first_list_done rows=" + Services.ClipboardService.items.length
                          + " rev=" + Services.ClipboardService.revision)
            }
        }
        function onMetadataUpdated() {
            root._metadataUpdates++
        }
    }

    property int _listCompletedCount: 0
    property int _metadataUpdates: 0
    property real _firstCompletedMs: 0
    property real _availableMs: 0
    property real _firstRowMs: 0
    property bool _sawRow: false
    property real _lastItemsLen: -1

    property Timer _watch: Timer {
        interval: 10
        repeat: true
        running: true
        onTriggered: root.tick()
    }

    property int _phase: 0
    property real _phaseSince: 0
    property real _idleSince: 0
    property bool _parseWasRunning: false

    function tick() {
        var svc = Services.ClipboardService
        var len = svc.items.length
        if (len !== root._lastItemsLen) {
            root._lastItemsLen = len
            if (len > 0 && !root._sawRow) {
                root._sawRow = true
                root._firstRowMs = Date.now()
                root.mark("first_row_readable")
            }
        }
        // Bracket the incremental parse so a stall inside it can be told apart
        // from one around the fetch.
        if (!!svc._parseRunning !== root._parseWasRunning) {
            root._parseWasRunning = !!svc._parseRunning
            if (root._parseWasRunning)
                root.mark("parse_begin")
            else
                root.mark("parse_end")
        }
        if (root._phase === 1 && root._firstCompletedMs > 0) {
            // Sweep 1 runs while both background queues are saturated: that is
            // the "launcher opened after the service was busy" case.
            root._phase = 2
            root._phaseSince = Date.now()
            root.mark("busy_sweep_start")
            root.startSweep("busy")
            return
        }
        if (root._phase !== 3)
            return
        if (root.queueIdle()) {
            if (!root._idleSince)
                root._idleSince = Date.now()
        } else {
            root._idleSince = 0
        }
        if (root._idleSince && Date.now() - root._idleSince > 400) {
            root._phase = 4
            root._drainedMs = Date.now()
            root.mark("queues_drained")
            root.measureAdapterCost("after-drain")
            // Sweep 2 is the same measurement with the queues idle, so the
            // difference is exactly what the background work cost the open.
            root.startSweep("idle")
        } else if (Date.now() - root._phaseSince > root.drainCapMs) {
            root.mark("drain_cap_reached")
            root.finish("DRAIN CAP REACHED - queues never went idle")
        }
    }
    property var _adapterCost: null
    property real _drainedMs: 0

    function onTrialSetDone() {
        if (root._mode === "busy") {
            root._phase = 3
            root._phaseSince = Date.now()
            // Taken here, not before the sweep: the sort costs as much as a
            // stall and would otherwise sit inside the first-list window the
            // service's own turn is measured in.
            root.measureAdapterCost("after-first-list")
            root._drainWatchStartMs = Date.now()
            root.mark("drain_watch_start")
            return
        }
        // A second idle pass separates "the queues cost the open" from "the
        // first open after 17 s of queue garbage pays a GC pause".
        if (root._mode === "idle") {
            root.mark("idle_sweep_1_end")
            root.startSweep("idle2")
            return
        }
        root.finish("done")
    }

    function startSweep(mode) {
        root._mode = mode
        root._trial = -1
        root.mark(mode + "_sweep_start")
        root.startOpen(0, 0)
    }

    // ---- Report -----------------------------------------------------------
    property bool _reported: false
    property var _adapterCosts: null
    property real _drainWatchStartMs: 0

    function finish(reason) {
        if (root._reported)
            return
        root._reported = true
        root._sampler.running = false
        var svc = Services.ClipboardService
        var byMode = {}
        for (var i = 0; i < root._opens.length; i++) {
            var o = root._opens[i]
            if (!byMode[o.mode])
                byMode[o.mode] = []
            byMode[o.mode].push({ delayMs: o.delayMs, ms: o.t1 - o.t0,
                                  queueMs: o.queueMs, rows: o.rows })
        }
        for (var m in byMode) {
            var list = byMode[m].slice().sort(function(a, b) { return a.ms - b.ms })
            var total = 0
            var qmax = 0
            for (var s = 0; s < list.length; s++) {
                total += list[s].ms
                if (list[s].queueMs > qmax)
                    qmax = list[s].queueMs
            }
            byMode[m] = {
                n: list.length,
                medianMs: list[Math.floor(list.length / 2)].ms,
                meanMs: Math.round(total / list.length),
                maxMs: list[list.length - 1].ms,
                minMs: list[0].ms,
                maxQueueMs: qmax,
                trials: list
            }
        }
        var report = {
            reason: reason,
            rows: svc.items.length,
            revision: svc.revision,
            listCompleted: root._listCompletedCount,
            metadataUpdates: root._metadataUpdates,
            pendingSignatures: svc._pendingSignatureIds.length,
            signaturesLearned: Object.keys(svc._firstSeenBySignature).length,
            firstRowMsAfterAvailable: root._firstRowMs > 0 ? root._firstRowMs - root._availableMs : -1,
            firstListCompletedMsAfterAvailable: root._firstCompletedMs > 0
                ? root._firstCompletedMs - root._availableMs : -1,
            queuesDrainedMsAfterAvailable: root._drainedMs > 0 ? root._drainedMs - root._availableMs : -1,
            firstListStalls: root.windowStalls(root._availableMs, root._firstCompletedMs + 60, 8),
            drainStalls: root._drainWatchStartMs > 0 && root._drainedMs > 0
                // Only the pure background drain: the busy sweep's own opens
                // are hundreds of milliseconds of deliberate event-loop
                // blocking and would otherwise be counted as background cost.
                ? root.windowStalls(root._drainWatchStartMs, root._drainedMs, 6) : null,
            openLatency: byMode,
            adapterCost: root._adapterCosts,
            marks: root._marks,
            markTimes: root._markTimes
        }
        console.log("COSTREPORT " + JSON.stringify(report))
        Qt.callLater(function() { Qt.quit() })
    }

    // ---- Boot -------------------------------------------------------------
    property bool _booted: false
    function boot() {
        if (root._booted)
            return
        root._booted = true
        // A bare singleton reference can be dropped without instantiating;
        // warmup() is the documented explicit construction hook.
        console.log("clipboard: available=" + Services.ClipboardService.available
                    + " probeFinished=" + Services.ClipboardService.probeFinished
                    + " warmup=" + Services.ClipboardService.warmup())
        root.mark("boot")
    }

    property Timer _bootWatch: Timer {
        interval: 5
        repeat: true
        running: true
        onTriggered: {
            if (root._phase !== 0)
                return
            if (Services.ClipboardService.available) {
                root._phase = 1
                root._phaseSince = Date.now()
                root._availableMs = Date.now()
                root.mark("available")
            }
        }
    }

    // Watchdog: the report prints even if a queue never drains.
    property Timer _reportGuard: Timer {
        interval: root.drainCapMs + 120000
        repeat: false
        running: true
        onTriggered: root.finish("WATCHDOG")
    }

    Component.onCompleted: {
        root._pump()
        root.boot()
    }
}
