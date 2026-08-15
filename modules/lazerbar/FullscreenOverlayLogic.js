.pragma library

var routes = ["wiki", "news", "beatmap"]
var waveAngles = [13, -7, 4, -2]

function isRoute(route) {
    return routes.indexOf(route) >= 0
}

function normalizeRoute(route) {
    return isRoute(route) ? route : ""
}

function toggleRoute(current, requested) {
    var next = normalizeRoute(requested)
    if (!next)
        return normalizeRoute(current)
    return normalizeRoute(current) === next ? "" : next
}

function clamp(value, minimum, maximum) {
    var number = Number(value)
    if (!isFinite(number))
        number = minimum
    return Math.max(minimum, Math.min(maximum, number))
}

function surfaceWidth(screenWidth) {
    var width = Number(screenWidth)
    if (!isFinite(width))
        return 0
    return Math.max(0, width) * 0.85
}

function surfaceTop(barPosition, barHeight) {
    var height = Number(barHeight)
    if (!isFinite(height))
        height = 0
    return barPosition === "top" ? Math.max(0, height) : 0
}

function waveAngle(index) {
    var candidate = Number(index)
    return isFinite(candidate) && candidate >= 0 && candidate < waveAngles.length
            ? waveAngles[Math.floor(candidate)] : 0
}

function sidebarWidth(value) {
    return clamp(value, 176, 280)
}

function escapeAction(inputActive, pageCanGoBack, overlayOpen) {
    if (inputActive)
        return "input"
    if (pageCanGoBack)
        return "back"
    return overlayOpen ? "close" : "none"
}
