.pragma library

var narrowWidthBreakpoint = 792
var narrowHeightBreakpoint = 552

function clamp(value, minimum, maximum) {
    var candidate = Number(value)
    var lower = Number(minimum)
    var upper = Number(maximum)
    if (!isFinite(candidate))
        candidate = 0
    if (!isFinite(lower) || !isFinite(upper) || lower > upper)
        return candidate
    return Math.max(lower, Math.min(upper, candidate))
}

function panelWidth(availableWidth) {
    var width = Number(availableWidth)
    if (!isFinite(width))
        return 0
    width = Math.max(0, width)
    if (width < narrowWidthBreakpoint)
        return Math.max(0, width - 32)
    return Math.round(clamp(width * 0.8, 760, 1040))
}

function panelHeight(availableHeight) {
    var height = Number(availableHeight)
    if (!isFinite(height))
        return 0
    height = Math.max(0, height)
    if (height < narrowHeightBreakpoint)
        return Math.max(0, height - 32)
    return Math.round(clamp(height * 0.78, 520, 760))
}

function navigationWidth(width) {
    var value = Number(width)
    if (!isFinite(value))
        return 168
    return isFinite(value) && value < 760 ? 168 : 216
}

function categoryDirection(previousIndex, nextIndex) {
    var previous = Number(previousIndex)
    var next = Number(nextIndex)
    if (!isFinite(previous) || !isFinite(next) || previous === next)
        return 0
    return next > previous ? 1 : -1
}

function timeoutSecondsToMs(seconds) {
    return Math.round(clamp(Number(seconds), 2, 15) * 1000)
}

function notificationAnchors(position) {
    var normalized = position == null ? "top-right" : String(position)
    if (normalized !== "top-left" && normalized !== "top-right"
            && normalized !== "bottom-left" && normalized !== "bottom-right")
        normalized = "top-right"
    var bottom = normalized.indexOf("bottom-") === 0
    var left = normalized === "top-left" || normalized === "bottom-left"
    return {
        top: !bottom,
        bottom: bottom,
        left: left,
        right: !left,
    }
}
