import QtQuick

// Viewport-priority, single-flight queue for clipboard thumbnail decodes.
//
// Decoding one entry costs a `cliphist decode` process spawn plus the real
// decode, so a list that materializes ~96 rows would otherwise ask for ~96
// decodes on a cold open and stall the launcher on a screenshot-heavy
// clipboard. The page owns ONE scheduling point - a repeating Timer that calls
// pump() - and this type enforces three rules on top of it:
//
//  - at most one decode in flight, and at most one issued per tick, so a burst
//    of newly visible rows decodes over a few frames instead of in one frame;
//  - the candidate list is recomputed from the page's live viewport geometry
//    on every tick, so only rows near the visible band are ever served and a
//    row that scrolls back out of the band before its turn drops out of the
//    served order instead of waiting in line off screen;
//  - the row the preview pane renders is served first, because it is drawn
//    large enough that a missing thumbnail is the most visible thing on
//    screen.
//
// The page owns the decoded-path cache, the single pacer Timer and the
// service, and this type owns only the decision: it is called once per tick
// and answers "issue this one, or nothing". Nothing here is visual, so it is
// a plain QtObject and adds no scene-graph node.
QtObject {
    id: root

    // --- page seams -------------------------------------------------------

    // function() -> ordered [{ id, mime }] for every materialized image row
    // that still needs a decode and is currently worth spending one on,
    // nearest-to-the-visible-band first. The page owns the viewport and the
    // row geometry, so it answers this question; rows it omits are dropped.
    property var candidates: null

    // function(id, mime, done) -> void. Requests ONE decode. `done(path)` must
    // eventually be called; an empty path means the entry had nothing to
    // decode. Only the scheduler decides to call this, so the one-in-flight
    // rule holds for every request the page makes.
    property var decode: null

    // function(id, path) -> void. A decode settled. The page stores the path in
    // its cache and bumps its revision; an empty path records nothing.
    property var decoded: null

    // Gate from the page: false while the launcher is closed. A prewarmed page
    // remains mounted but disabled, so it must not spawn decode processes.
    property bool active: true

    // --- pacing -----------------------------------------------------------

    // One request per tick: a burst of newly visible rows then decodes over a
    // handful of frames instead of monopolizing the frame that revealed them.
    // Reads the shared motion token rather than inventing a duration.
    readonly property int interval: MotionTokens.fast

    // Liveness of the page's pacer. Declarative so every writer below is
    // enough to keep it alive without an imperative start/stop that could race
    // a tick: `outstandingCount` keeps it ticking while candidates remain
    // (each tick serves at most one), `busy` keeps it alive across an
    // in-flight decode, and `armed` is the one-shot wake the page uses when
    // the viewport, the pool, the materialized window or the selection moved
    // and nothing is outstanding yet - without it a settled list would never
    // look again.
    readonly property bool running: active && (busy || outstandingCount > 0 || armed)

    // --- observable state -------------------------------------------------
    // Exposed for probes and tests: a burst that never happened has to be
    // measurable, not merely invisible.

    // True while a request this scheduler issued is still outstanding.
    property bool busy: false
    // Entry id of that request.
    property string inFlightId: ""
    // Candidates waiting for their turn, as of the last tick.
    property int outstandingCount: 0
    // Lifetime tally and issue order, so a test can prove both the throttle
    // (nothing else was ever in flight) and the priority (who went first).
    property int issuedCount: 0
    property var issuedIds: []
    // One-shot wake flag, cleared at the start of every tick.
    property bool armed: false

    // A materialized row asked for a thumbnail, or the viewport, the pool, the
    // materialized window or the selection moved. One arming call for both:
    // every case ends up as "re-derive the served order on the next tick", and
    // a row's interest is never worth its own timer - whether a row is close
    // enough to the viewport to be worth a decode is decided from live
    // geometry, so an off-screen row costs nothing and scrolling back to it
    // re-queues it with no extra plumbing.
    function enqueue() {
        root.armed = true
    }
    function wake() {
        root.armed = true
    }

    // One tick: re-derive the served order from live geometry, publish how
    // many candidates are waiting, and issue the head if nothing is in flight.
    function pump() {
        root.armed = false
        var list = root._candidates()
        var waiting = 0
        var next = null
        for (var i = 0; i < list.length; i++) {
            var id = String(list[i].id)
            if (root.busy && id === root.inFlightId)
                continue
            waiting++
            if (waiting === 1)
                next = list[i]
        }
        root.outstandingCount = waiting
        if (!root.busy && next !== null && typeof root.decode === "function")
            root._issue(next)
    }

    // Ids currently waiting for their turn, in served order. Diagnostics only:
    // it re-derives the same list the next tick would serve.
    function pendingIds() {
        var out = []
        var list = root._candidates()
        for (var i = 0; i < list.length; i++) {
            var id = String(list[i].id)
            if (root.busy && id === root.inFlightId)
                continue
            out.push(id)
        }
        return out
    }

    function _candidates() {
        if (typeof root.candidates !== "function")
            return []
        var produced = root.candidates()
        return produced || []
    }

    function _issue(job) {
        var id = String(job.id)
        root.busy = true
        root.inFlightId = id
        root.issuedCount++
        root.issuedIds = root.issuedIds.concat([id])
        root.decode(id, String(job.mime == null ? "" : job.mime), function (path) {
            root._settle(id, path)
        })
    }

    // A decode came back. An already-issued request is never cancelled, so
    // this can only ever arrive for a request that is still ours; the guard
    // keeps a late callback from releasing a slot that has since been handed
    // to another row. The cache write happens either way.
    function _settle(id, path) {
        if (root.busy && root.inFlightId === id) {
            root.busy = false
            root.inFlightId = ""
        }
        if (typeof root.decoded === "function")
            root.decoded(id, path)
        // Serve the next row on the following tick, never inside this callback:
        // that is the spacing, not an accident of the callback landing late.
        root.armed = true
    }
}
