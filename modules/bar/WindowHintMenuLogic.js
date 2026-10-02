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
// earlier, or 0 when the move is unknown. The one comparison, shared with
// `stripPlan` so the crossing and the plan that describes it cannot disagree
// about which way the workspace went.
//
// A first snapshot reports -1 for the previous position, which is
// indistinguishable from "unknown", and 0 is the right answer there - there is
// nothing to have come from. A refresh 40ms after an activation reports the SAME
// position on both sides, and 0 is right for that too: it says the content
// refreshed, not that the move was undone.
function _step(fromPosition, toPosition) {
    var from = Number(fromPosition)
    var to = Number(toPosition)
    if (!isFinite(from) || !isFinite(to))
        return 0
    if (from < 0 || to < 0 || from === to)
        return 0
    return to > from ? 1 : -1
}

function switchDirection(hint) {
    if (!hint)
        return 0
    return _step(hint.previousActiveWorkspacePosition, hint.activeWorkspacePosition)
}

// The widest crossing the strip can describe, in workspaces.
//
// The strip is the ORDERED UNION of the two frames' workspaces: three positions
// each, and they only tile a contiguous run while the move is no wider than the
// two frames together. One step apart they overlap in two positions, two steps in
// one, three steps in none - and at four steps apart the middle column belongs to
// NEITHER snapshot. A strip cannot have a column whose contents nothing knows, and
// inventing an empty column there would report "no windows" about a workspace
// nobody looked at.
//
// So four steps apart is a replacement, not a crossing. It is also a rare thing to
// ask for: it means holding mod and pressing a digit at least four away.
var MAX_SWITCH_SPAN = 3

// The whole geometry of one crossing, as one record. The component and the suite
// both read this, so neither can hold a private copy of the arithmetic.
//
// Positions are workspace indices and slots are strip columns. For a move from
// `from` to `to` the strip holds every position from `min(from, to) - 1` to
// `max(from, to) + 1` - the union of the two frames - which is `span + 3` columns,
// one per workspace:
//
//   strip slot k holds position base + k
//   the frame being left  occupies slots 0..2
//   the frame arriving   occupies slots direction > 0 ? span..span+2 : 0..2
//
// and the strip therefore translates by exactly `span` columns, in the direction
// the workspace went. One copy of each position, so nothing can be painted twice;
// and the strip is always at least three columns wide while it is moving, so the
// panel cannot be left uncovered.
//
// The start and end are derived from the invariant rather than from the sign of
// the move: a strip slot is `1 - slot` columns from home when the workspace in
// that slot is the active one, and the active workspace is in the panel's middle
// column at BOTH ends of the crossing. That is what makes the arriving frame's
// active column land in the middle without a special case for either direction.
function stripPlan(fromPosition, toPosition) {
    var step = _step(fromPosition, toPosition)
    if (step === 0)
        return null
    var from = Number(fromPosition)
    var to = Number(toPosition)
    var span = Math.abs(to - from)
    if (span > MAX_SWITCH_SPAN)
        return null
    var base = Math.min(from, to) - 1
    return {
        base: base,
        span: span,
        direction: step,
        // The slot the arriving frame's active workspace occupies. In the panel's
        // middle column at the end of the crossing, and off-panel for most of the
        // travel - which is the point: the card column arrives from the far side
        // rather than changing under the reader.
        activeSlot: to - base,
        slots: span + 3,
        startColumn: 1 - (from - base),
        endColumn: 1 - (to - base)
    }
}

// The plan for a panel at rest: the arriving frame's own three columns, the active
// one in the middle, and nowhere to travel.
//
// The same record shape as `stripPlan`, deliberately. A crossing's plan and a rest
// plan are both "which slot is active, how many columns wide, where does the strip
// sit" - so the component's bindings are written once against one shape instead of
// branching on whether anything is moving, and a strip built from this is exactly
// the arriving frame with nothing duplicated beside it.
function restPlan(hint) {
    var position = Number(hint ? hint.activeWorkspacePosition : -1)
    if (!isFinite(position) || position < 0)
        return null
    return {
        base: position - 1,
        span: 0,
        direction: 0,
        activeSlot: 1,
        slots: 3,
        startColumn: 0,
        endColumn: 0
    }
}

// One frame's three columns, tagged with the position each one is for, so a
// position can be looked up in whichever frame has it. Built from `cappedColumns`
// rather than beside it, so both views apply the same cap.
function _frame(hint) {
    if (!hint)
        return null
    var position = Number(hint.activeWorkspacePosition)
    if (!isFinite(position) || position < 0)
        return null
    return { position: position, columns: cappedColumns(hint) }
}

// What one position is showing, taken from whichever frame knows it. A position
// both frames know is read from the ARRIVING one: the two agree on which
// workspace it is, and the arriving snapshot is the fresher reading of its
// windows.
function _columnForPosition(frame, position) {
    var empty = { rows: [], hidden: 0 }
    if (!frame)
        return empty
    if (position === frame.position)
        return frame.columns.current
    if (position === frame.position - 1)
        return frame.columns.previous
    if (position === frame.position + 1)
        return frame.columns.next
    return empty
}

// The strip: the two frames' workspaces merged into one ordered list, one column
// per position, left to right. `arriving` and `leaving` may be the same frame
// (a crossing's own follow-up refresh rebuilds against the same two), and either
// may be null (nothing has been left yet).
//
// A column is never split and never appears twice, so the renderer can hand each
// column to a `Repeater` and be certain of both halves of that: one column per
// workspace, one draw per column.
function stripColumns(arriving, leaving, plan) {
    var out = []
    if (!plan)
        return out
    var to = _frame(arriving)
    var from = _frame(leaving)
    for (var slot = 0; slot < plan.slots; ++slot) {
        var position = plan.base + slot
        var column = _columnForPosition(to, position)
        if (column.rows.length === 0)
            column = _columnForPosition(from, position)
        out.push({
            position: position,
            rows: column.rows,
            hidden: column.hidden
        })
    }
    return out
}

// How far a strip has to shift when a crossing in flight is re-aimed at a new
// destination, in columns. The strip's slots are numbered from its own base, so a
// new plan with a different base renumbers every column the strip already holds -
// and without giving the offset back by the same amount, the content on screen
// would jump sideways by exactly this many columns on the frame the second switch
// lands.
//
// It follows from the two bases, not from the direction of the move, and that is
// deliberate: a move that continues forwards drops the workspace behind the one now
// being left and gains one ahead, so its base moves and the correction is not zero.
// The one case that needs no correction is a re-aim that happens to land on the
// same base - arriving back at the origin of a crossing, for instance, which
// re-uses the same run of workspaces.
//
// Positive means "shift the strip left by this much", i.e. give back the ground the
// renumbering took. A column's position on the panel is its slot plus the offset,
// and the correction is what keeps that sum unchanged across the re-aim.
function stripReshift(previousPlan, nextPlan) {
    if (!previousPlan || !nextPlan)
        return 0
    return previousPlan.base - nextPlan.base
}

// Overflow line under a capped window list. Empty when everything fit, so the
// renderer can bind visibility straight to the string.
function overflowLabel(hidden) {
    var count = _count(hidden)
    return count === 0 ? "" : "+" + count + " more " + plural(count, "window", "windows")
}