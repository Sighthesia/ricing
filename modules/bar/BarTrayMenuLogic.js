.pragma library

function entryList(children) {
    if (!children)
        return []
    if (Array.isArray(children))
        return children
    if (children.values && typeof children.values.length === "number") {
        var out = []
        for (var i = 0; i < children.values.length; i++)
            out.push(children.values[i])
        return out
    }
    if (typeof children.length === "number") {
        var copy = []
        for (var j = 0; j < children.length; j++)
            copy.push(children[j])
        return copy
    }
    return []
}

function isSeparator(entry) { return !!(entry && entry.isSeparator) }
function isEnabled(entry) { return !!(entry && entry.enabled !== false) && !isSeparator(entry) }
function hasChildren(entry) { return !!(entry && entry.hasChildren) }
function isChecked(entry) { return !!(entry && entry.checkState === Qt.Checked) }
function labelOf(entry) {
    if (!entry || entry.text == null) return ""
    return String(entry.text).replace(/[\n\r]+/g, " ")
}
function shouldOpenSubmenu(entry) {
    return hasChildren(entry) && isEnabled(entry) && !isSeparator(entry)
}
function shouldCloseSubmenuOnRow(level, rowHasChildren) {
    return Number(level) === 1 && !rowHasChildren
}
function shouldDismissOnTrigger(entry) {
    if (!entry || isSeparator(entry) || hasChildren(entry))
        return false
    if (entry.checkState !== undefined && entry.checkState !== null)
        return false
    return true
}
function emptyStateVisible(handle, entries) {
    return !handle || entryList(entries).length === 0
}
function menuHandleFromPayload(payload) {
    if (!payload) return null
    if (payload.menuHandle)
        return payload.menuHandle
    if (payload.hasMenu && payload.menu)
        return payload.menu
    if (payload.trayItem && payload.trayItem.hasMenu)
        return payload.trayItem.menu || null
    return null
}
function submenuTitle(entry) { return labelOf(entry) }
function heldHeight(rawHeight, previousHeld) {
    var raw = Number(rawHeight)
    var prev = Number(previousHeld)
    if (!isFinite(raw) || raw <= 20)
        return isFinite(prev) && prev > 0 ? prev : 0
    return raw
}
function releaseSubmenuData(progress, phase) {
    return Number(progress) === 0 && String(phase || "") !== "opening"
}
