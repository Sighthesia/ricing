.pragma library

var utilityOrder = ["news", "changelog", "wiki", "ranking", "library", "chat", "community", "music"]
var removalOrder = ["community", "chat", "ranking", "wiki", "changelog", "news", "library"]

function formatDuration(seconds) {
    var value = Number(seconds)
    if (!isFinite(value) || value < 0)
        return "--:--:--"

    value = Math.floor(value)
    var hours = Math.floor(value / 3600)
    var minutes = Math.floor((value % 3600) / 60)
    var remainingSeconds = value % 60
    return _pad(hours) + ":" + _pad(minutes) + ":" + _pad(remainingSeconds)
}

function parseUptime(text) {
    if (typeof text !== "string")
        return -1

    var first = text.trim().split(/\s+/)[0]
    var value = Number(first)
    return isFinite(value) && value >= 0 ? Math.floor(value) : -1
}

function fallbackInitial(username) {
    var normalized = username == null ? "" : String(username).trim()
    return normalized.length > 0 ? normalized.charAt(0).toUpperCase() : "?"
}

function visibleUtilityIds(availableWidth, itemWidth, spacing) {
    var width = Math.max(0, Number(availableWidth) || 0)
    var slotWidth = Math.max(1, Number(itemWidth) || 0)
    var gap = Math.max(0, Number(spacing) || 0)
    var visible = utilityOrder.slice()

    function requiredWidth(count) {
        return count * slotWidth + Math.max(0, count - 1) * gap
    }

    for (var i = 0; requiredWidth(visible.length) > width && i < removalOrder.length; i++) {
        var index = visible.indexOf(removalOrder[i])
        if (index >= 0)
            visible.splice(index, 1)
    }
    return visible
}

function visualState(enabled, active, hovered, pressed) {
    if (!enabled)
        return "disabled"
    if (active && pressed)
        return "activePressed"
    if (active && hovered)
        return "activeHover"
    if (pressed)
        return "pressed"
    if (active)
        return "active"
    if (hovered)
        return "hover"
    return "rest"
}

function nextOverlay(current, requested) {
    var active = current == null ? "" : String(current)
    var target = requested == null ? "" : String(requested)
    return active === target ? "" : target
}

function popupOrigin(anchorCenterX, popupWidth, screenWidth) {
    var center = Number(anchorCenterX) || 0
    var width = Math.max(0, Number(popupWidth) || 0)
    var available = Math.max(0, Number(screenWidth) || 0)
    return center + width / 2 > available ? "topRight" : "topLeft"
}

function _pad(value) {
    var text = String(value)
    return text.length < 2 ? "0" + text : text
}
