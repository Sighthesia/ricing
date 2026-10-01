.pragma library

// Pure view model for the mod-key window hint menu.
//
// `services/WindowHintService.qml` owns the live snapshot; this file only turns
// the windows on the active workspace into rows the bar popup can render, and
// caps how many of them it asks for. Keeping the cap, the ordering and the
// overflow copy here means they are verifiable from a QtTest harness without
// instantiating the popup, the bar, or Quickshell at all.
//
// The snapshot this reads is shaped by WindowHintService:
//   hint.workspaceId / hint.windows -> [{ windowId, title, appId, icon, isFocused }]
//
// The hint shows no workspace index, no workspace name and no counts: the bar
// already reports which workspace is active, and the list below is countable on
// screen. Nothing here builds a workspace row for that reason.

// How many window rows the menu shows before it collapses the rest into a
// "+N more" line. The popup has no scroll surface, and an unbounded list would
// grow the layer-shell input region once per added window.
var MAX_WINDOW_ROWS = 5

function _text(value) {
    if (value === null || value === undefined)
        return ""
    return String(value)
}

function _trimmed(value) {
    return _text(value).trim()
}

function _count(value) {
    var n = Number(value)
    return isFinite(n) && n > 0 ? Math.round(n) : 0
}

function _list(value) {
    return value && typeof value.length === "number" ? value : []
}

function plural(count, singular, many) {
    return _count(count) === 1 ? singular : many
}

// A snapshot is only renderable once the service has resolved an active
// workspace. Before that `windows` is empty and every row would read as
// "missing", so the menu holds its empty state instead.
function ready(hint) {
    return !!hint && _trimmed(hint.workspaceId) !== ""
}

// One row per window on the active workspace, in the order the service sorted
// them (column, then row, then id — the on-screen tiling order).
function windowRows(hint) {
    var rows = []
    var list = _list(hint ? hint.windows : null)
    for (var i = 0; i < list.length; ++i) {
        var window = list[i]
        if (!window)
            continue
        rows.push({
            windowId: _trimmed(window.windowId),
            title: _trimmed(window.title),
            appId: _trimmed(window.appId),
            icon: _trimmed(window.icon),
            isFocused: window.isFocused === true
        })
    }
    return rows
}

// Rows plus the count the menu could not fit, so the "+N more" line is derived
// from the same cap the renderer uses instead of being recomputed there.
function cappedWindowRows(hint) {
    var rows = windowRows(hint)
    if (rows.length <= MAX_WINDOW_ROWS)
        return { rows: rows, hidden: 0 }
    return { rows: rows.slice(0, MAX_WINDOW_ROWS), hidden: rows.length - MAX_WINDOW_ROWS }
}

// Index of the focused row *within the capped list*, or -1. niri reports at
// most one focused window, so this is the single row the focus underline
// belongs to. An index past the cap resolves to -1: the window is real but not
// on screen, and an underline pointing at nothing would be a lie.
function focusedRowIndex(hint) {
    var rows = windowRows(hint)
    var limit = Math.min(rows.length, MAX_WINDOW_ROWS)
    for (var i = 0; i < limit; ++i) {
        if (rows[i].isFocused)
            return i
    }
    return -1
}

// Overflow line under a capped window list. Empty when everything fit, so the
// renderer can bind visibility straight to the string.
function overflowLabel(hidden) {
    var count = _count(hidden)
    return count === 0 ? "" : "+" + count + " more " + plural(count, "window", "windows")
}