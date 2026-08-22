.pragma library

// Pure launcher contracts for the wave launcher: query-prefix parsing,
// stable result sorting, selection clamping, and keyboard action decisions.
// No QML or service dependencies; all inputs are defensively normalized.

var clipboardPrefix = ">clip "
var shortcutPrefix = ">key "

function normalizeText(value) {
    return value == null ? "" : String(value).replace(/\s+/g, " ").trim()
}

function toCount(value) {
    var number = Number(value)
    return isFinite(number) ? number : 0
}

function parseQuery(query) {
    var body = query == null ? "" : String(query).replace(/^\s+/, "")
    var clipRest = matchPrefix(body, clipboardPrefix)
    if (clipRest !== null)
        return { mode: "clipboard", text: normalizeText(clipRest), prefix: clipboardPrefix }
    var keyRest = matchPrefix(body, shortcutPrefix)
    if (keyRest !== null)
        return { mode: "shortcuts", text: normalizeText(keyRest), prefix: shortcutPrefix }
    return { mode: "apps", text: normalizeText(body), prefix: "" }
}

function matchPrefix(text, prefix) {
    var head = text.slice(0, prefix.length).toLowerCase()
    return head === prefix ? text.slice(prefix.length) : null
}

function displayNameOf(item) {
    return item == null || item.displayName == null ? "" : String(item.displayName)
}

function identifierOf(item) {
    return item == null || item.id == null ? "" : String(item.id)
}

function sortResults(items) {
    if (!items || !items.length)
        return []
    var sorted = items.slice()
    sorted.sort(function (left, right) {
        var byWeight = toCount(right.favoriteWeight) - toCount(left.favoriteWeight)
        if (byWeight !== 0)
            return byWeight
        var byRecent = toCount(right.lastUsedAt) - toCount(left.lastUsedAt)
        if (byRecent !== 0)
            return byRecent
        var byName = displayNameOf(left).localeCompare(displayNameOf(right))
        if (byName !== 0)
            return byName
        return identifierOf(left) < identifierOf(right) ? -1 : identifierOf(left) > identifierOf(right) ? 1 : 0
    })
    return sorted
}

function clampSelection(index, count) {
    if (!count || count < 1)
        return -1
    var value = Math.round(toCount(index))
    if (value < 0)
        return 0
    if (value > count - 1)
        return count - 1
    return value
}

function keyboardAction(key, hasInput, hasSelection, interactive) {
    var normalized = key == null ? "" : String(key).toLowerCase()
    if (normalized === "escape" || normalized === "esc")
        return hasInput ? "clear" : "close"
    if (normalized === "enter" || normalized === "return")
        return interactive && hasSelection ? "execute" : "none"
    if (normalized === "up")
        return interactive ? "up" : "none"
    if (normalized === "down")
        return interactive ? "down" : "none"
    return "none"
}
