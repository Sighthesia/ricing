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

// One row per window, in the order the service sorted them (column, then row,
// then id — the on-screen tiling order). `list` is the raw window array; the
// neighbours arrive as exactly the same shape as the active workspace's.
function rowsFromList(list) {
    var rows = []
    var items = _list(list)
    for (var i = 0; i < items.length; ++i) {
        var window = items[i]
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

function windowRows(hint) {
    return rowsFromList(hint ? hint.windows : null)
}

// Rows plus the count that did not fit, so the "+N more" line is derived from
// the same cap the renderer uses instead of being recomputed there.
function cappedRows(list) {
    var rows = rowsFromList(list)
    if (rows.length <= MAX_WINDOW_ROWS)
        return { rows: rows, hidden: 0 }
    return { rows: rows.slice(0, MAX_WINDOW_ROWS), hidden: rows.length - MAX_WINDOW_ROWS }
}

function cappedWindowRows(hint) {
    return cappedRows(hint ? hint.windows : null)
}

// The three columns the menu lays out: the workspaces either side of the active
// one, and the active one itself. Each is capped by the same limit so the three
// read as peers and the panel height is predictable; at either end of the
// workspace list the missing neighbour is an empty column, which is the honest
// answer - there is no workspace there to show.
function cappedColumns(hint) {
    return {
        previous: cappedRows(hint ? hint.previousWindows : null),
        current: cappedRows(hint ? hint.windows : null),
        next: cappedRows(hint ? hint.nextWindows : null)
    }
}

// Index of the focused row within a list of rows, or -1. niri reports at most one
// focused window, so this is the single row the focus marker belongs to. An index
// past the cap is never returned: the window is real but not on screen, and a
// marker pointing at nothing would be a lie.
function focusedIndexIn(rows) {
    var list = _list(rows)
    for (var i = 0; i < list.length; ++i) {
        if (list[i] && list[i].isFocused === true)
            return i
    }
    return -1
}

// The same answer for the active workspace's windows, which is the only column
// that can hold focus.
function focusedRowIndex(hint) {
    var rows = cappedRows(hint ? hint.windows : null)
    return focusedIndexIn(rows.rows)
}

// Which way the active workspace moved, as +1 for later in the list and -1 for
// earlier, or 0 when the move is unknown. The snapshot already carries both the
// active and the previous active position, so this only compares them.
//
// The list replacement uses it so the swap travels the way the workspace did: a
// switch downwards reads as the next page arriving from below, which is the
// same direction the focus indicator travels in. A first snapshot reports -1
// for the previous position, which is indistinguishable from "unknown", and 0 is
// the right answer there - there is nothing to have come from.
function switchDirection(hint) {
    if (!hint)
        return 0
    var from = Number(hint.previousActiveWorkspacePosition)
    var to = Number(hint.activeWorkspacePosition)
    if (!isFinite(from) || !isFinite(to))
        return 0
    if (from < 0 || to < 0 || from === to)
        return 0
    return to > from ? 1 : -1
}

// Overflow line under a capped window list. Empty when everything fit, so the
// renderer can bind visibility straight to the string.
function overflowLabel(hidden) {
    var count = _count(hidden)
    return count === 0 ? "" : "+" + count + " more " + plural(count, "window", "windows")
}