.pragma library

var routes = ["settings", "music", "wiki", "news", "beatmap"]

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
    var width = Math.max(1, Number(screenWidth) || 1)
    var maximum = Math.min(1440, Math.max(1, width - 32))
    var minimum = Math.min(640, maximum)
    return clamp(width - 96, minimum, maximum)
}

function surfaceHeight(screenHeight) {
    var height = Math.max(1, Number(screenHeight) || 1)
    var maximum = Math.min(900, Math.max(1, height - 32))
    var minimum = Math.min(420, maximum)
    return clamp(height - 96, minimum, maximum)
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
