.pragma library

// Pure wave-surface contracts: route validation, geometry, and escape precedence.
// Content routes stay out; register future routes explicitly instead of editing call sites.

var routes = ["launcher"]
var waveAngles = [13, -7, 4, -2]

function isRoute(route) {
    return routes.indexOf(route) >= 0
}

function normalizeRoute(route) {
    return isRoute(route) ? route : ""
}

function registerRoute(route) {
    if (!route || typeof route !== "string" || isRoute(route))
        return false
    routes.push(route)
    return true
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

function waveAngle(index) {
    var candidate = Number(index)
    return isFinite(candidate) && candidate >= 0 && candidate < waveAngles.length
            ? waveAngles[Math.floor(candidate)] : 0
}

function sidebarWidth(value) {
    return clamp(value, 176, 280)
}

function escapeAction(inputActive, pageCanGoBack, surfaceOpen) {
    if (inputActive)
        return "input"
    if (pageCanGoBack)
        return "back"
    return surfaceOpen ? "close" : "none"
}
