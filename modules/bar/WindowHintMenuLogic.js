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
// read as peers and the panel height is predictable.
//
// ALL THREE ALWAYS EXIST, whatever they contain. An earlier version dropped a
// column with no windows and narrowed the panel to suit, which was wrong for two
// reasons at once: the active workspace moved out of the middle depending on what
// its neighbours happened to be running, and the panel changed width under the
// pointer on every switch between an interior and an edge workspace. Both made
// the same three workspaces read as a different panel each time.
//
// A column with nothing in it therefore renders its own "no windows" line rather
// than reserving blank space. The slot is not empty - it is a column that has
// something to say about that workspace.
function cappedColumns(hint) {
    return {
        previous: cappedRows(hint ? hint.previousWindows : null),
        current: cappedRows(hint ? hint.windows : null),
        next: cappedRows(hint ? hint.nextWindows : null)
    }
}

// One column's width. A constant rather than a share of the panel: the panel's
// width is this times the column count, and the count never varies, so this is
// simply the panel's unit.
var COLUMN_WIDTH = 180

// How many columns the panel has, always: the previous workspace, the active one
// and the next. A constant rather than a count, because the active workspace sits
// in the middle and can only be the middle if the three slots are a fixed frame.
var COLUMN_COUNT = 3

// What a neighbour column says when that workspace has no windows. Named here so
// the label is one string rather than two literals, and so the wording is stated
// once: it names no workspace, because a column with no number on it cannot say
// which one it is - the position in the panel already does that.
var NEIGHBOUR_EMPTY_LABEL = "No windows"

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