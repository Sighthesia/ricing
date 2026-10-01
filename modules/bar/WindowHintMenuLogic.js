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
// read as peers and the panel height is predictable. At either end of the
// workspace list the missing neighbour resolves to an empty list, which
// `columnCount` then refuses to give a slot to.
function cappedColumns(hint) {
    return {
        previous: cappedRows(hint ? hint.previousWindows : null),
        current: cappedRows(hint ? hint.windows : null),
        next: cappedRows(hint ? hint.nextWindows : null)
    }
}

// How many of the three columns get a slot, from a `cappedColumns` result.
//
// The active workspace always takes one - with no windows it says so rather
// than disappearing, because the panel is about where you are. A neighbour takes
// one only if it has windows: a column with nothing in it is not information,
// it is a hole in the panel, and a hole reads as a layout fault rather than as
// "there is nothing there". So the two ends of the workspace list - and any
// empty neighbour workspace in between - take no space at all.
function columnCount(columnsValue) {
    var value = columnsValue || {}
    return (value.previous && value.previous.rows && value.previous.rows.length > 0 ? 1 : 0)
        + 1
        + (value.next && value.next.rows && value.next.rows.length > 0 ? 1 : 0)
}

// One column's width. A constant rather than a share of the panel: the panel's
// width is this times the column count, so deriving one from the other would be
// circular, and a dropped column must narrow the panel instead of stretching
// the survivors to fill it.
var COLUMN_WIDTH = 180

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
// The list replacement uses it to decide whether a switch is worth animating at
// all. A first snapshot reports -1 for the previous position, which is
// indistinguishable from "unknown", and 0 is the right answer there - there is
// nothing to have come from. The direction itself no longer steers a transform:
// the three columns sit side by side, so a switch is a horizontal slide and each
// column knows which slot it is moving to.
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