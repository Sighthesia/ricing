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
        isFocused: !!(row && row.isFocused),
        // The window's own place in niri's tiling. Carried because a REORDER is the same
        // set of identities in a different order, and telling that apart from "one left and
        // another arrived in its place" needs the position each window HOLDS rather than
        // where it happens to sit in the projection.
        colIdx: row && row.colIdx !== undefined ? row.colIdx : 0,
        rowIdx: row && row.rowIdx !== undefined ? row.rowIdx : 0
    }
}

// Where this record sits, as one comparable number. Columns first, then rows - the same
// order the service sorts by, so "moved up" and "moved left" are both a decrease.
function _tilingOrder(record) {
    return Number(record.colIdx || 0) * 1000 + Number(record.rowIdx || 0)
}

function _copy(record) {
    var out = _fields(record)
    out.key = record.key
    out.moveFrom = record.moveFrom === undefined ? -1 : record.moveFrom
    // Carried for the same reason `moveFrom` is: a second move landing mid-travel needs to
    // know how far the first one got, and that is a field of this record.
    out.moveProgress = record.moveProgress === undefined ? 1 : record.moveProgress
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
        colIdx: fields.colIdx,
        rowIdx: fields.rowIdx,
        key: key,
        phase: "live",
        delayMs: 0,
        presence: 1,
        ink: 1,
        started: true,
        moveFrom: -1
    }
}

function _leaving(previous, key, index, count, stepMs) {
    var out = _copy(previous)
    out.key = key
    // A row on its way out is not the current window, whatever it was while it was open.
    // The focus markers are placed from the list's own `isFocused`, so a closing row that
    // kept the flag would hold the frame and the bar on a card that is dissolving - and
    // the window niri focused in its place would never be marked at all.
    out.isFocused = false
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
        colIdx: fields.colIdx,
        rowIdx: fields.rowIdx,
        key: key,
        phase: "enter",
        delayMs: SlotLogic.cascadeDelayMs(index, count, stepMs, false),
        presence: 0,
        ink: 0,
        started: false,
        moveFrom: -1
    }
}

// The index a key occupied in a list, or -1. Used to tell a row that MOVED from a row
// that was merely re-described: both arrive with the same key, and only the position it
// used to hold says which one happened.
function _indexOfKey(list, key) {
    for (var i = 0; i < list.length; ++i) {
        var item = list[i]
        if (!item)
            continue
        // `keyFor` rather than `item.key`, because the two lists this is asked about are
        // not the same shape: the previous one holds reconcile RECORDS (which carry a
        // `key`), and the incoming one holds raw snapshot rows (which do not, and whose
        // identity is derived from the window id exactly as the reconcile derives it).
        if (keyFor(item, i) === String(key))
            return i
    }
    return -1
}

// The index a key holds among the rows that are present in BOTH lists, which is the only
// frame of reference a reorder can be measured in: a row that is leaving occupies a place
// on one side and no place on the other, so counting through it makes every row below it
// look displaced - and dropping it later displaces them again by the same amount.
function _indexAmongSurviving(list, key, otherByKey) {
    var seen = 0
    for (var i = 0; i < list.length; ++i) {
        var item = list[i]
        if (!item)
            continue
        var itemKey = keyFor(item, i)
        if (!otherByKey[itemKey])
            continue
        if (itemKey === String(key))
            return seen
        ++seen
    }
    return -1
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
            // MOVED, or just re-described? A window that changed its place in niri is the
            // one thing this projection cannot show by itself: the array is sorted by that
            // place, so a move is the same identities in a different order - which reads
            // exactly like a row being replaced unless the position is compared.
            //
            // The travel is remembered as the ORDER INDEX it came from, not as a pixel
            // offset and not as the tiling number: the row is drawn by its index in this
            // list (`slotTopAt`), so the index is the unit its position is already
            // expressed in. A tiling delta would have to be converted through a pitch that
            // a collapsing slot is changing at the same time.
            if (merged.phase === "live") {
                // The two positions, and neither is `i`: this loop walks the PREVIOUS
                // list, so `i` is where the row was - the new place is where the incoming
                // list puts it. Comparing `i` against itself is why the first cut of this
                // found no movement at all: every row was at its own index in both lists.
                //
                // Both indices are counted over the rows that are STILL HERE, on both
                // sides. A departing row holds a place in `prev` that the arriving list does
                // not have, so counting through it made every row below it look like it had
                // moved by one - and the moment that row was dropped, the same rows were
                // "moved" again by the same one. Measured: a reorder and a close in one
                // publish slid the moved row into place, then slid it a second time when the
                // closing slot was retired.
                var previousIndex = _indexAmongSurviving(prev, key, incomingByKey)
                var incomingIndex = _indexAmongSurviving(next, key, previousByKey)
                if (previousIndex >= 0 && incomingIndex >= 0
                        && previousIndex !== incomingIndex) {
                    // WHERE THE ROW ACTUALLY IS, not where the last publish put it.
                    //
                    // A second move can land while the first is still travelling - a fast
                    // run of move-column, which is the reported case. `previousIndex` is the
                    // place the row was HEADING FOR, so starting the new travel from it
                    // makes the row jump forward to that place and slide back out of it:
                    // the eye sees a hop, not a longer journey.
                    //
                    // `moveFrom` and `moveProgress` together say where it really is, in the
                    // previous list's coordinates, and that is the honest start of the new
                    // one. A row that had settled carries `moveFrom === -1` and no progress,
                    // which lands on `previousIndex` as before.
                    var liveFrom = record.moveFrom
                    var liveProgress = record.moveProgress
                    if (liveFrom !== undefined && liveFrom >= 0
                            && liveProgress !== undefined && liveProgress < 1) {
                        var left = (liveFrom - previousIndex) * (1 - liveProgress)
                        merged.moveFrom = previousIndex + left
                    } else {
                        merged.moveFrom = previousIndex
                    }
                    merged.moveProgress = 0
                    merged.moveEpoch = (merged.moveEpoch || 0) + 1
                }
            }
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
    // ORDERED BY THE INCOMING LIST, with every departure left in the place it held.
    //
    // The rows that STAY belong in the order the snapshot now says, or a reorder would be
    // invisible: they would keep their slots and only the titles under them would change.
    //
    // A row on its way OUT is the opposite case and must not be re-ordered at all. Appending
    // departures to the end - which is what this did - is a real change of place, so the row
    // TRAVELLED to the bottom of the list and dissolved there. Measured, closing the second
    // of four rows made it slide past two neighbours and fade at the bottom edge, which is
    // the reported "a closing card always moves to the bottom instead of leaving where it
    // was". A row that is leaving has no place in the new order, so the place it already
    // occupies is the only honest one.
    var ordered = []
    var departures = []
    for (var d = 0; d < next.length; ++d) {
        var wantKey = keyFor(next[d], d)
        for (var e = 0; e < out.length; ++e) {
            if (out[e] && String(out[e].key) === String(wantKey)) {
                ordered.push(out[e])
                out.splice(e, 1)
                break
            }
        }
    }
    for (var f = 0; f < out.length; ++f) {
        if (out[f] && out[f].phase === "exit")
            departures.push(out[f])
    }
    // The live rows in the snapshot's order, with each departure spliced back at the index
    // it held in the PREVIOUS list - which is where the user last saw it.
    for (var g = 0; g < departures.length; ++g) {
        var was = _indexOfKey(prev, departures[g].key)
        if (was < 0) {
            ordered.push(departures[g])
            continue
        }
        var at = Math.min(was, ordered.length)
        ordered.splice(at, 0, departures[g])
    }
    return ordered
}

// Is a row arriving or leaving anywhere in this list? The one question the panel
// asks about a transition, and the reason it is asked of the RECORDS rather than of
// the items: the item that knows is the one being rebuilt.
function anyMoving(rows) {
    var list = _list(rows)
    for (var i = 0; i < list.length; ++i) {
        if (!list[i])
            continue
        // A REORDER counts, and it has to: `liftAt` is read while this is true, and a row
        // that is half way between two places is not where its index says it is any more
        // than a collapsing slot is.
        if (list[i].phase === "enter" || list[i].phase === "exit"
                || list[i].moveFrom >= 0)
            return true
    }
    return false
}

// Is a row CROSSING to a new place - which is a different question from "is anything
// happening", and the difference is a whole mechanism.
//
// `anyMoving` answers the first: an arrival or a departure changes the LAYOUT, so anything
// placed by summing slots has to be recomputed while it runs. This answers the second: a row
// is travelling from one place to another, so the thing that marks it has no fixed target to
// ease toward and has to be PINNED instead.
//
// They were the same predicate, and that is what put a trail on a window closing. A
// departing row does not move - it dissolves where it is - so its marker's target does not
// move either; but `anyMoving` was true for it, the marker was switched to the pinned
// mechanism, and the pinned mechanism's head was written to a target that never changed
// while its tail walked in from wherever the previous travel had left it. Measured: head
// pinned at 35 for the whole exit while the tail crawled -30 -> 35 behind it, a wake drawn
// under a mark that was not going anywhere.
function anyReordering(rows) {
    var list = _list(rows)
    for (var i = 0; i < list.length; ++i) {
        if (list[i] && list[i].moveFrom !== undefined && list[i].moveFrom >= 0)
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
        var record = list[i]
        // Only a LEAVING slot lifts the rows below it. An arriving one is opening into a
        // space the list does not have yet, so the rows under it are still where they were
        // - and counting its shortfall as a lift is what put the focused row's target 200
        // pixels above where it is: measured on the first frame of a twelve-row workspace,
        // eleven slots at presence 0 summed to a lift of 199.96 and the reveal scrolled to
        // 4 instead of 238, which is the report - the focused card below the panel's edge.
        if (!record)
            continue
        if (record.phase !== "exit")
            continue
        var presence = record.presence !== undefined ? Number(record.presence) : 1
        if (!isFinite(presence))
            presence = 1
        lift += pitch * (1 - Math.max(0, Math.min(1, presence)))
    }
    return lift
}
