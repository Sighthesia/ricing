.pragma library
.import "widgets/TraySlotLogic.js" as SlotLogic

// The row list of ONE hint column, carried across publishes so a window that left
// has somewhere to leave FROM.
//
// A publish replaces the whole snapshot, and the rows are a projection of it - so
// without this a window closing is a row that simply stops existing, and there is
// nothing to animate: the list under the pointer loses a row between two frames.
// The tray strip solved the same problem with a stable `ListModel` whose
// departing slot stays resident until its exit has played (see
// `widgets/Tray.qml`), and this is that arrangement expressed as data instead of
// as a model: the reconcile below returns the UNION of what was on screen and what
// the snapshot now says, each entry carrying the phase it is in and the values its
// own animation has reached.
//
// It has to be data and not per-item state, and that is a Quickshell fact rather
// than a preference: a `Repeater` over a JS array destroys and rebuilds EVERY
// delegate when the array is reassigned - measured, three delegates for a list of
// three replaced by three new ones for the same three entries - so an item that
// held its own `presence` would lose it on the very publish that is supposed to
// continue the animation. The record is the thing that survives; the delegate reads
// it back when it is created and writes it as it moves.
//
// Nothing here touches QML, so the ordering, the phases and the cascade delays are
// all readable without instantiating the panel.

// One row's identity, and the key the two lists are joined on. A window's id is
// the only field in the snapshot that is stable across a publish - the title can
// change, the app id can change, the position in the list can change - so a
// reconcile keyed on anything else would read a retitled window as one closing and
// another opening.
//
// The index fallback exists for the empty-window-id case the service can produce
// while a window is still being described, and it is deliberately index-based:
// such a row has no identity to preserve, so the best available answer is "the row
// in that place".
function keyFor(row, index) {
    var id = row && row.windowId !== undefined && row.windowId !== null
        ? String(row.windowId) : ""
    return id !== "" ? "w:" + id : "s:" + index
}

function _list(value) {
    return value && typeof value.length === "number" ? value : []
}

function _fields(row) {
    return {
        windowId: row && row.windowId !== undefined ? row.windowId : "",
        title: row && row.title !== undefined ? row.title : "",
        appId: row && row.appId !== undefined ? row.appId : "",
        icon: row && row.icon !== undefined ? row.icon : "",
        isFocused: !!(row && row.isFocused)
    }
}

function _copy(record) {
    var out = _fields(record)
    out.key = record.key
    out.phase = record.phase
    out.delayMs = record.delayMs || 0
    out.presence = record.presence === undefined ? 1 : record.presence
    out.ink = record.ink === undefined ? 1 : record.ink
    out.started = record.started === true
    return out
}

function _resting(fields, key) {
    return {
        windowId: fields.windowId,
        title: fields.title,
        appId: fields.appId,
        icon: fields.icon,
        isFocused: fields.isFocused,
        key: key,
        phase: "live",
        delayMs: 0,
        presence: 1,
        ink: 1,
        started: true
    }
}

function _leaving(previous, key, index, count, stepMs) {
    var out = _copy(previous)
    out.key = key
    if (previous.phase !== "exit") {
        // The phase CHANGED on this pass, so this is the frame the exit begins: the
        // delay is its own and the animation starts from wherever the row was.
        out.phase = "exit"
        out.delayMs = SlotLogic.cascadeDelayMs(index, count, stepMs, true)
        out.started = false
        out.presence = previous.presence === undefined ? 1 : previous.presence
        out.ink = previous.ink === undefined ? 1 : previous.ink
    }
    return out
}

function _arriving(fields, key, index, count, stepMs) {
    return {
        windowId: fields.windowId,
        title: fields.title,
        appId: fields.appId,
        icon: fields.icon,
        isFocused: fields.isFocused,
        key: key,
        phase: "enter",
        delayMs: SlotLogic.cascadeDelayMs(index, count, stepMs, false),
        presence: 0,
        ink: 0,
        started: false
    }
}

// The union of `previous` and `incoming`, in display order.
//
// Departures keep their OLD place in the list rather than being moved: a row on its
// way out has to stay where the user last saw it, and re-sorting it to wherever the
// new snapshot would have put it is a row that jumps sideways as it dies. Arrivals
// are spliced in at their incoming index, which is where they belong and is the
// only index that exists for them.
//
// A record whose phase did not change is copied through with its live values
// untouched, so an unrelated publish - a title edit, a focus move, niri's second
// refresh 40ms after an activation - cannot restart an animation that is halfway
// through. Only a CHANGE of phase resets anything, and that is the definition of
// the event being animated.
function reconcileRows(previous, incoming, stepMs) {
    var prev = _list(previous)
    var next = _list(incoming)
    var step = Number(stepMs) > 0 ? Number(stepMs) : 0

    var previousByKey = {}
    for (var p = 0; p < prev.length; ++p) {
        var prevKey = prev[p] && prev[p].key !== undefined
            ? String(prev[p].key) : keyFor(prev[p], p)
        previousByKey[prevKey] = prev[p]
    }
    var incomingByKey = {}
    for (var n = 0; n < next.length; ++n)
        incomingByKey[keyFor(next[n], n)] = next[n]

    // The counts a cascade is paced over, counted before anything is built so both
    // directions can be expressed as "position in the batch".
    var leaving = []
    for (var a = 0; a < prev.length; ++a) {
        var goneKey = prev[a] && prev[a].key !== undefined
            ? String(prev[a].key) : keyFor(prev[a], a)
        if (!incomingByKey[goneKey])
            leaving.push(goneKey)
    }
    var arriving = []
    for (var b = 0; b < next.length; ++b) {
        var newKey = keyFor(next[b], b)
        if (!previousByKey[newKey])
            arriving.push(newKey)
    }

    var out = []
    for (var i = 0; i < prev.length; ++i) {
        var record = prev[i]
        if (!record)
            continue
        var key = record.key !== undefined ? String(record.key) : keyFor(record, i)
        var live = incomingByKey[key]
        if (live) {
            var merged = _copy(record)
            var fields = _fields(live)
            merged.windowId = fields.windowId
            merged.title = fields.title
            merged.appId = fields.appId
            merged.icon = fields.icon
            merged.isFocused = fields.isFocused
            // A row that was on its way out and is still here has been revived: it
            // goes back to resting at once, because the alternative - finishing the
            // exit and then growing back - is two animations for one window that
            // never left.
            if (merged.phase === "exit") {
                merged.phase = "live"
                merged.started = true
            }
            // A resting row has no cascade position to hold: the delay it may have
            // been given on the pass it arrived is spent, and carrying it forward
            // would be a number on a record whose phase says nothing is moving.
            if (merged.phase === "live")
                merged.delayMs = 0
            out.push(merged)
            continue
        }
        out.push(_leaving(record, key, leaving.indexOf(key), leaving.length, step))
    }

    // Ascending, so each splice lands at the index the arrival has in the snapshot
    // and the merged order is a merge rather than a reshuffle.
    for (var c = 0; c < next.length; ++c) {
        var arrivalKey = keyFor(next[c], c)
        if (previousByKey[arrivalKey])
            continue
        out.splice(c, 0, _arriving(_fields(next[c]), arrivalKey,
            arriving.indexOf(arrivalKey), arriving.length, step))
    }
    return out
}

// Is a row arriving or leaving anywhere in this list? The one question the panel
// asks about a transition, and the reason it is asked of the RECORDS rather than of
// the items: the item that knows is the one being rebuilt.
function anyMoving(rows) {
    var list = _list(rows)
    for (var i = 0; i < list.length; ++i) {
        if (list[i] && (list[i].phase === "enter" || list[i].phase === "exit"))
            return true
    }
    return false
}

// How much shorter than its resting height the slot at `index` is, in pixels, right
// now: a collapsing or opening slot changes the offset of every row below it, and
// the focus markers are placed against the rows, not against the pitch.
function liftAt(rows, index, rowHeight, listSpacing) {
    var list = _list(rows)
    var pitch = Number(rowHeight) + Number(listSpacing)
    var lift = 0
    for (var i = 0; i < list.length && i < index; ++i) {
        var presence = list[i] && list[i].presence !== undefined
            ? Number(list[i].presence) : 1
        if (!isFinite(presence))
            presence = 1
        lift += pitch * (1 - Math.max(0, Math.min(1, presence)))
    }
    return lift
}
