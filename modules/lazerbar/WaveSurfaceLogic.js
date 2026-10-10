.pragma library

// Pure wave-surface contracts: route validation, geometry, and escape precedence.
// Content routes stay out; register future routes explicitly instead of editing call sites.

// The launcher page is the wave's only route. The control center used to be a
// sibling route here; it is now a VIEW inside the launcher page's content area,
// which is what removed the second entry - not a deprecation. A sibling route
// cost its own Loader component, its own header/rail contract and its own
// coordinator owner, all for content the same page already had to host.
var routes = ["launcher"]
var waveAngles = [13, -7, 4, -2]
// osu!lazer WaveContainer.FinalPosition values, absolute pixels
// (osu.Game/Graphics/Containers/WaveContainer.cs, https://github.com/ppy/osu).
// Absolute like the source: they do not scale with viewport height.
var waveFinalPositions = [-930, -560, -390, -220]

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

function waveFinalPosition(index) {
    var candidate = Number(index)
    return isFinite(candidate) && candidate >= 0 && candidate < waveFinalPositions.length
            ? waveFinalPositions[Math.floor(candidate)] : 0
}

// Push offset of one layer relative to the stack bottom (the fourth wave):
// pinning every layer to the panel edge by this offset rides the whole fan
// ahead of the panel instead of letting the panel swallow the lower layers.
function wavePushOffset(index) {
    return waveFinalPosition(index) - waveFinalPosition(waveFinalPositions.length - 1)
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
