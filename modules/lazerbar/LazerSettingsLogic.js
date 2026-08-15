.pragma library

var narrowWidthBreakpoint = 792
var narrowHeightBreakpoint = 552
var sidebarContractedWidth = 70
var sidebarExpandedWidth = 170
var settingsContentWidth = 400
var settingsPanelWidth = sidebarExpandedWidth + settingsContentWidth

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
        return Math.min(width, Math.max(320, width - 32))
    return Math.round(clamp(width * 0.8, 760, 1040))
}

function sidePanelWidth(availableWidth) {
    var width = Number(availableWidth)
    if (!isFinite(width))
        return 0
    return Math.max(0, Math.min(settingsPanelWidth, width))
}

function sidebarWidth(expanded, availableWidth) {
    var preferred = expanded ? sidebarExpandedWidth : sidebarContractedWidth
    var width = Number(availableWidth)
    if (!isFinite(width))
        return preferred
    return Math.max(0, Math.min(preferred, width))
}

function contentWidth(availableWidth, currentSidebarWidth) {
    var width = Number(availableWidth)
    var sidebar = Number(currentSidebarWidth)
    if (!isFinite(width) || !isFinite(sidebar))
        return 0
    return Math.max(0, Math.min(settingsContentWidth, width - Math.max(0, sidebar)))
}

function panelHeight(availableHeight) {
    var height = Number(availableHeight)
    if (!isFinite(height))
        return 0
    height = Math.max(0, height)
    if (height < narrowHeightBreakpoint)
        return Math.min(height, Math.max(320, height - 32))
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

function interpolate(start, end, progress) {
    var p = Number(progress)
    if (!isFinite(p))
        p = 0
    p = Math.max(0, Math.min(1, p))
    var s = Number(start)
    var e = Number(end)
    if (!isFinite(s) || !isFinite(e))
        return 0
    return s + (e - s) * p
}

function sidebarStartX() {
    return -sidebarExpandedWidth
}

function contentStartX(panelWidth) {
    var width = Number(panelWidth)
    if (!isFinite(width))
        return -settingsPanelWidth
    return -Math.max(0, width)
}

function valuesEqual(a, b) {
    if (a === b)
        return true
    if (a == null || b == null)
        return false
    if (typeof a === "number" && typeof b === "number")
        return Math.abs(Number(a) - Number(b)) < 1e-9
    return false
}

// Map a numeric value to a 0..1 fraction, honoring reversed ranges.
function sliderFraction(from, to, value) {
    var start = Number(from)
    var end = Number(to)
    var v = Number(value)
    if (!isFinite(start) || !isFinite(end) || !isFinite(v) || start === end)
        return 0
    var low = Math.min(start, end)
    var high = Math.max(start, end)
    var fraction = (clamp(v, low, high) - low) / (high - low)
    return end < start ? 1 - fraction : fraction
}

// Turn a 0..1 fraction into a stepped value inside the slider range.
function sliderValueFromFraction(from, to, fraction, stepSize) {
    var start = Number(from)
    var end = Number(to)
    var f = Number(fraction)
    var step = Number(stepSize)
    if (!isFinite(start) || !isFinite(end) || !isFinite(f) || start === end)
        return start
    if (!isFinite(step) || step <= 0)
        step = 1
    f = Math.max(0, Math.min(1, f))
    // The exact track endpoints always map to the range bounds even when the
    // step size does not divide the range evenly (e.g. 10..0 step 3 -> 0).
    if (f <= 0)
        return start
    if (f >= 1)
        return end
    var direction = end >= start ? 1 : -1
    var low = Math.min(start, end)
    var high = Math.max(start, end)
    var raw = start + direction * f * (high - low)
    var steps = Math.round((raw - start) / (step * direction))
    return Math.max(low, Math.min(high, start + steps * step * direction))
}

// Map a pointer position inside a padded slider width to a 0..1 fraction.
function sliderFractionForPosition(position, width, padding) {
    var p = Number(position)
    var w = Number(width)
    var pad = Number(padding)
    if (!isFinite(p) || !isFinite(w) || !isFinite(pad) || w <= 0)
        return 0
    if (!isFinite(pad) || pad < 0)
        pad = 25
    var usable = Math.max(0, w - 2 * pad)
    if (usable <= 0)
        return 0
    return Math.max(0, Math.min(1, (p - pad) / usable))
}

// Decide where a dropdown menu should sit relative to its header viewport.
function dropdownPlacement(headerTop, headerBottom, menuHeight, viewportTop, viewportBottom, maxMenuHeight) {
    var top = Number(headerTop)
    var bottom = Number(headerBottom)
    var height = Number(menuHeight)
    var vt = Number(viewportTop)
    var vb = Number(viewportBottom)
    var cap = Number(maxMenuHeight)
    if (!isFinite(top) || !isFinite(bottom) || !isFinite(height) || !isFinite(vt) || !isFinite(vb))
        return { y: 0, above: false, height: 0 }
    if (!isFinite(cap) || cap <= 0)
        cap = 200
    height = Math.max(0, Math.min(height, cap))
    if (height <= 0)
        return { y: bottom, above: false, height: 0 }
    var belowSpace = vb - bottom
    var aboveSpace = top - vt
    if (belowSpace >= height)
        return { y: bottom, above: false, height: height }
    if (aboveSpace >= height)
        return { y: top - height, above: true, height: height }
    if (aboveSpace >= belowSpace)
        return { y: vt, above: true, height: Math.max(0, Math.min(height, aboveSpace)) }
    return { y: bottom, above: false, height: Math.max(0, Math.min(height, belowSpace)) }
}

function normalizeSearchQuery(query) {
    return query == null ? "" : String(query).trim().toLowerCase()
}

function matchesSearch(label, description, query) {
    var normalized = normalizeSearchQuery(query)
    if (!normalized)
        return true
    var labelText = label == null ? "" : String(label).toLowerCase()
    var descriptionText = description == null ? "" : String(description).toLowerCase()
    return labelText.indexOf(normalized) !== -1 || descriptionText.indexOf(normalized) !== -1
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
