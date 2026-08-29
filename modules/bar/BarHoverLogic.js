.pragma library

// Pure hover-intent and geometry helpers for the bar two-layer popup.
// No QML imports or singleton references; safe to import from QtTest harnesses.

function _normalizeString(value) {
    if (typeof value === "string")
        return value
    if (value == null)
        return ""
    return String(value)
}

function popupDirection(barPosition) {
    var normalized = typeof barPosition === "string" ? barPosition.trim().toLowerCase() : ""
    return normalized === "bottom" ? "up" : "down"
}

function popupKind(intent) {
    return intent && String(intent.kind || "").toLowerCase() === "context"
        ? "context" : "hover"
}

function isSettingsIntent(intent) {
    return !!intent && (String(intent.kind || "").toLowerCase() === "settings"
        || String(intent.widgetId || "").toLowerCase() === "settings")
}

function canReplace(current, next) {
    if (!next)
        return false
    if (!current)
        return true
    return popupKind(current) !== popupKind(next)
        || String(current.instanceKey || "") !== String(next.instanceKey || "")
}

function clampAnchor(anchorX, popupWidth, screenWidth, margin) {
    var x = Number(anchorX)
    var w = Number(popupWidth)
    var s = Number(screenWidth)
    var m = Number(margin)

    if (!isFinite(x))
        x = 0
    if (!isFinite(w) || w < 0)
        w = 0
    else
        w = Math.max(0, w)
    if (!isFinite(s) || s < 0)
        s = 0
    else
        s = Math.max(0, s)
    if (!isFinite(m) || m < 0)
        m = 0
    else
        m = Math.max(0, m)

    var min = m
    var max = s - w - m
    if (max < min)
        max = min
    if (x < min)
        return min
    if (x > max)
        return max
    return x
}

function shouldClose(widgetHovered, popupHovered, closePending) {
    return !widgetHovered && !popupHovered && !!closePending
}

function hoverPayload(widgetId, instanceKey, title, iconSource, summary, actionKind) {
    return {
        widgetId: _normalizeString(widgetId),
        instanceKey: _normalizeString(instanceKey),
        title: _normalizeString(title),
        iconSource: _normalizeString(iconSource),
        summary: _normalizeString(summary),
        actionKind: _normalizeString(actionKind)
    }
}
