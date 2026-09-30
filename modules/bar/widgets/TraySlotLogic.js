.pragma library

// Pure slot bookkeeping for the tray strip: the stable identity one
// StatusNotifier item is filed under, the diff that keeps a stable model in
// sync, and the numbers the text transition contributes to its enter/exit.
//
// No QML imports and no singleton references, so QtTest can exercise all of it
// without a StatusNotifierWatcher on the bus.

// Stable per-item identity. `id` is the SNI service+path — the same key the
// bar already hands the popup host as `delegateKey`, so two tray icons are
// told apart the same way everywhere. Items that never registered an id fall
// back to their tooltip/title, and finally to their position.
function slotKey(item, index) {
    var raw = ""
    try { raw = String((item && item.id) || "") } catch (e) { raw = "" }
    if (raw === "") {
        try { raw = String((item && item.tooltipTitle) || (item && item.title) || "") } catch (e2) { raw = "" }
    }
    return raw === "" ? "tray:" + index : raw
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
    var step = Math.max(1, Math.floor(Number(stepMs) || 0))
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
