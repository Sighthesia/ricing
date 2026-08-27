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
