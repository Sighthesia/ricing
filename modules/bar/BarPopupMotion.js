.pragma library

// Shared layered-reveal math for popup surfaces. The header leads the
// content, just like the settings sidebar's independently appearing layers.
function progress(value, start, end) {
    var current = Number(value)
    var from = Number(start)
    var to = Number(end)
    if (!isFinite(current) || !isFinite(from) || !isFinite(to) || to <= from)
        return 0
    return Math.max(0, Math.min(1, (current - from) / (to - from)))
}

function headerProgress(value) {
    return progress(value, 0, 0.72)
}

function contentProgress(value) {
    return progress(value, 0.16, 1)
}

function offset(value, distance) {
    return Number(distance) * (1 - Math.max(0, Math.min(1, Number(value))))
}
