.pragma library

// Shared layered-reveal math for popup surfaces. The header leads the
// content with the exact settings-sidebar delay/fade contract.
function progress(value, start, end) {
    var current = Number(value)
    var from = Number(start)
    var to = Number(end)
    if (!isFinite(current) || !isFinite(from) || !isFinite(to) || to <= from)
        return 0
    return Math.max(0, Math.min(1, (current - from) / (to - from)))
}

function headerProgress(value, totalDuration, fadeDuration) {
    return progress(value, 0, Number(fadeDuration) / Number(totalDuration))
}

function contentProgress(value, totalDuration, delay, fadeDuration) {
    var start = Number(delay) / Number(totalDuration)
    return progress(value, start, start + Number(fadeDuration) / Number(totalDuration))
}

function offset(value, distance) {
    return Number(distance) * (1 - Math.max(0, Math.min(1, Number(value))))
}

// Whether the popup's content slot must keep its clip pinned to the painted
// panel instead of the wider input canvas.
//
// Three independent states each pin it, and none of them may be keyed off the
// exchange flag alone:
//
//   * A stale body is still mounted. The outgoing layer is cleared only after
//     the slide, so between the mount and that clear it paints at a partial
//     offset with rows that have not arrived - empty cards.
//   * A replacement is pending. Starting a replacement resets the exchange flag
//     on the very frame the new intent lands, while deliberately leaving the
//     outgoing layer mounted. That is the only window where the flag is false
//     and a stale body exists, and catching it needs a second hop to arrive
//     inside it - a fast sweep between two adjacent tray icons. Measured there:
//     the slot jumped 260 -> 504 while the clip stayed on, so the clip rect was
//     244px wider than the panel.
//   * A slide is in flight, on either body.
//
// Lives here rather than inline so the host and its regression test share one
// definition: a copy in the test passes vacuously whenever the host changes.
function contentBodiesDisplaced(outgoingMounted, pendingIntent, exchangeCommitted, slideProgress) {
    if (outgoingMounted === true)
        return true
    if (pendingIntent !== null && pendingIntent !== undefined)
        return true
    return exchangeCommitted === true && Number(slideProgress) < 1
}
