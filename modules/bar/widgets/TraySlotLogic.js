.pragma library

// Pure slot bookkeeping for the tray strip: the stable identity one
// StatusNotifier item is filed under, the diff that keeps a stable model in
// sync, and the numbers the text transition contributes to its enter/exit.
//
// No QML imports and no singleton references, so QtTest can exercise all of it
// without a StatusNotifierWatcher on the bus.

// Identity is the *registered object*, never a string derived from it.
//
// A StatusNotifierItem's `id` is not unique and not stable: two items can
// report the same one (an app registering twice, fcitx's two entries), and the
// order Quickshell hands them back in is not guaranteed between refreshes.
// Keying slots on such a string makes two icons trade places the moment the
// list reorders, and makes a departure look like an arrival for a different
// app — which is exactly "QQ's icon is replaced by the input method's". A key
// that lives exactly as long as the registration cannot do that.
//
// Object identity, not a string, also means the strip keeps the order it
// established when the service reorders: a reorder is not a display event, and
// icons should not jump around while they are in use.

function emptyRegistry() {
    return { items: [], keys: [], next: 0 }
}

// Assign every live object a key it keeps for as long as it stays registered,
// and rebuild the mapping from the current list so a departed object drops its
// key and a new object never inherits a dead one. Returns the keys in list
// order; `registry.items` is the matching item for each.
//
// Note that a QML binding cannot observe `registry.keys` being reassigned —
// only the `registry` reference itself. Read the count off a property the
// caller reassigns (Tray keeps `_liveKeys` for exactly this reason) or a
// `liveCount` will freeze at whatever the binding first saw.
function reindex(registry, liveItems) {
    var previousItems = registry.items
    var previousKeys = registry.keys
    var items = []
    var keys = []
    for (var i = 0; i < liveItems.length; i++) {
        var item = liveItems[i]
        if (!item)
            continue
        // A service that lists one object twice gets one slot, not two.
        if (items.indexOf(item) >= 0)
            continue
        var key = ""
        for (var j = 0; j < previousItems.length; j++) {
            if (previousItems[j] === item) {
                key = previousKeys[j]
                break
            }
        }
        if (key === "")
            key = "tray#" + (++registry.next)
        items.push(item)
        keys.push(key)
    }
    registry.items = items
    registry.keys = keys
    return keys
}

// Keys present in `next` but not `previous`, and the reverse, each in the
// order the caller passed them so a batch can be staggered the way it arrived.
function diff(previous, next) {
    var before = {}
    for (var i = 0; i < previous.length; i++)
        before[previous[i]] = true
    var after = {}
    for (var j = 0; j < next.length; j++)
        after[next[j]] = true

    var added = []
    for (var a = 0; a < next.length; a++) {
        if (!before[next[a]])
            added.push(next[a])
    }
    var removed = []
    for (var r = 0; r < previous.length; r++) {
        if (!after[previous[r]])
            removed.push(previous[r])
    }
    return { added: added, removed: removed }
}

// Cascade delay for slot `index` of a batch of `count`, paced as one
// wavefront: arrivals sweep left to right like the text scan line, departures
// sweep right to left like the delete ghosts. A single slot is never delayed.
function cascadeDelayMs(index, count, stepMs, fromRight) {
    var n = Math.max(0, Math.floor(Number(count) || 0))
    if (n <= 1)
        return 0
    var i = Math.max(0, Math.min(n - 1, Math.floor(Number(index) || 0)))
    var step = Math.max(1, Math.floor(Number(stepMs) || 1))
    return (fromRight ? (n - 1 - i) : i) * step
}

// How far a leaving icon drops. The glyph is centred in its slot, so the only
// room it has is the gap under it before the bar's own row clips it — a longer
// drop gets its middle sliced off at the clip edge, which reads as a cut
// rather than a fall.
function fallDistance(widgetHeight, glyphSize) {
    var h = Math.max(1, Number(widgetHeight) || 0)
    var g = Math.max(1, Number(glyphSize) || 0)
    return Math.max(2, (h - g) / 2)
}
