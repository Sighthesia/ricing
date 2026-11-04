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

// How many window rows the ACTIVE column shows at once. This is a VIEWPORT
// height, not a cap on the list: the active column scrolls, so every window in the
// workspace is reachable and nothing is summarised away.
//
// It was a cap - the rest collapsed into a "+N more windows" line - because the panel
// had no scroll surface and an unbounded list would grow the layer-shell input region
// once per added window. A viewport answers the same concern from the other side: the
// panel is this tall no matter how many windows the workspace holds, so the input
// region is bounded by the viewport rather than by the content.
//
// The two neighbour columns still truncate at this many rows, because they do not
// scroll. They always did, and they never carried the overflow line either - a
// neighbour states what it has and stops.
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
            isFocused: window.isFocused === true,
            // The window's own place in the tiling, carried so a REORDER can be told
            // apart from a row that was replaced. This list is already in that order, so
            // the two agree at rest - they stop agreeing on the publish that moved
            // something, which is the one this is for.
            colIdx: _count(window.colIdx),
            rowIdx: _count(window.rowIdx)
        })
    }
    return rows
}

function windowRows(hint) {
    return rowsFromList(hint ? hint.windows : null)
}

// Rows plus the count that did not fit. The count is reported so a caller can say
// whether the list is longer than the viewport without comparing against the cap
// itself; nothing renders it as text any more.
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
// one, and the active one itself. The NEIGHBOURS are capped at the viewport height
// and the ACTIVE column is not, because the active column is the one that scrolls -
// capping it would put a wall between the user and the windows they came to pick.
// Each is capped by the same limit so the three
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
        // Every window, uncapped: the active column scrolls to reach them all. `hidden`
        // still reports how many are past the viewport, which is what tells the renderer
        // there is anything to scroll - not a summary line, but the scroll contract.
        current: {
            rows: rowsFromList(hint ? hint.windows : null),
            hidden: Math.max(0, rowsFromList(hint ? hint.windows : null).length
                - MAX_WINDOW_ROWS)
        },
        next: cappedRows(hint ? hint.nextWindows : null)
    }
}

// A NEIGHBOUR column's width. A constant rather than a share of the panel: the
// panel's width is this times the column count plus one active column, and
// neither varies, so this is simply the panel's unit.
var COLUMN_WIDTH = 180

// How many times wider the ACTIVE workspace's column is than a neighbour's.
//
// The one asymmetry in the panel, and it is there because the workspace you are
// ON is the one whose windows you opened the panel to choose from: its titles get
// the room, its cards get the band's full width, and the two neighbours are
// context for it rather than peers of it. Everything else about the three columns
// - the count, the gutter, every padding - is shared, so the wide one reads as
// emphasis and not as a different component.
var ACTIVE_COLUMN_SCALE = 2
var ACTIVE_COLUMN_WIDTH = COLUMN_WIDTH * ACTIVE_COLUMN_SCALE

// How many columns the panel has, always: the previous workspace, the active one
// and the next. A constant rather than a count, because the active workspace sits
// in the middle and can only be the middle if the three slots are a fixed frame.
var COLUMN_COUNT = 3

// The panel's own width: a neighbour, a gutter, the active column, a gutter, a
// neighbour. A function rather than a constant so the layout below and the panel
// that shows it cannot disagree about where the right edge is - the band is placed
// against this number, and a band one gutter out from the edge is the fault the
// `barWidgetGutter` reach exists to prevent.
function panelWidth(columnWidth, activeColumnWidth, gutter) {
    return 2 * columnWidth + 2 * gutter + activeColumnWidth
}

// Where a column sits and how wide it is, as ONE function of its distance - in
// workspaces, and fractional - from the workspace the panel is centred on.
//
// `rel` is the whole interface. Zero is the active column, in the wide middle
// slot; -1 and +1 are the two neighbour slots at their own width; anything
// further out is off-panel content marching past an edge, still at neighbour
// width. Between the three slots the answer interpolates, which is the whole
// width-change effect: a crossing is nothing more than `rel` running from one
// workspace's value to another's, so the arriving column grows on the way in and
// the one being left shrinks on the way out - from the same number, on the same
// clock, with no second animation that could fall out of step with the first.
//
// Three properties this shape is chosen for, all of which the alternative - a
// uniform pitch with one card growing over its neighbours - does not have:
//
//   CONTINUITY. Adjacent answers agree at every boundary, so a column never jumps
//   as `rel` crosses an integer. A piecewise function with matching endpoints is
//   what makes `rel` safe to animate rather than safe to evaluate.
//
//   NO OVERLAP, EVER. Both layouts are contiguous - column i's right edge is
//   column i+1's left edge less the gutter - and a lerp between two contiguous
//   layouts of the same run is contiguous too, because a lerp of differences is
//   the difference of lerps. So the gap between any two adjacent cards is the
//   gutter at every instant of a crossing, not merely at its ends. That is also
//   what keeps the panel covered throughout: the panel can never show a gap wider
//   than one inter-card gap, which is the guarantee the suite states.
//
//   RE-AIM FOR FREE. A crossing's two ends are two values of one scalar, so
//   continuing from wherever the scalar had reached is a matter of remembering
//   that value - no per-column compensation, no slot renumbering, and nothing to
//   correct when a second switch lands mid-flight.
//
// `narrowPitch` and `rightX` are passed rather than recomputed because they are
// two of the panel's own measurements; deriving them here as well would be a
// second copy of the layout's arithmetic, free to drift from the first.
function slotX(rel, narrowPitch, rightX) {
    if (rel >= 1)
        return rightX + (rel - 1) * narrowPitch
    if (rel <= -1)
        return (rel + 1) * narrowPitch
    if (rel >= 0)
        // Middle to right neighbour: the incoming column, closing on the wide slot.
        return narrowPitch + rel * (rightX - narrowPitch)
    // Left neighbour to middle: the outgoing column, leaving it.
    return narrowPitch * (rel + 1)
}

function slotWidth(rel, columnWidth, activeColumnWidth) {
    if (rel >= 1 || rel <= -1)
        return columnWidth
    var share = rel >= 0 ? 1 - rel : rel + 1
    return columnWidth + (activeColumnWidth - columnWidth) * share
}

// What a neighbour column says when that workspace has no windows. An i18n KEY
// rather than a sentence (this module is Qt-free and shared), named here so
// the label is one string rather than two literals, and so the wording is stated
// once: it names no workspace, because a column with no number on it cannot say
// which one it is - the position in the panel already does that.
var NEIGHBOUR_EMPTY_LABEL = "hint.noWindows"

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
// One copy of each position, so nothing can be painted twice; and the strip is
// always at least three columns wide while it is moving, so the panel cannot be
// left uncovered.
//
// The two ends of the crossing are `fromPosition` and `toPosition` as WORKSPACE
// POSITIONS, not as pixel offsets, because that is what the layout is written
// against: `slotX` and `slotWidth` ask how far a column is from the workspace the
// panel is centred on, so a crossing is a column's answer at `toPosition` and at
// `fromPosition` and the clock is the share of the way between. The old record
// carried a start and end COLUMN as well, which was the same two numbers in a
// third unit - and needed a `stripReshift` correction to convert between the units
// when a second switch landed mid-flight, because a re-aim renumbers the strip's
// slots and the pixel offset had to give back exactly what the renumbering took.
// With the layout keyed on positions there is nothing to convert and nothing to
// correct: continuing from wherever the crossing had reached is a matter of
// handing `fromPosition` that value instead of the plan's own.
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
        // The slot the arriving frame's active workspace occupies - which slot
        // decides which column is drawn as cards and which as plain labels, so it
        // is the content half of the plan. Where that slot is PAINTED is
        // `slotX(activePosition - panelPosition)` and nothing else; it used to be
        // `activeSlot * columnPitch`, which only held because every column was the
        // same width and the whole strip moved together.
        activeSlot: to - base,
        // The workspace the markers belong to, and the two the crossing runs
        // between. Equal in a rest plan.
        activePosition: to,
        fromPosition: from,
        toPosition: to,
        slots: span + 3
    }
}

// The plan for a panel at rest: the arriving frame's own three columns, the active
// one in the middle, and nowhere to travel.
//
// The same record shape as `stripPlan`, deliberately. A crossing's plan and a rest
// plan are both "which slot is active, how many columns wide, where is the panel
// centred" - so the component's bindings are written once against one shape
// instead of branching on whether anything is moving, and a strip built from this
// is exactly the arriving frame with nothing duplicated beside it.
function restPlan(hint) {
    var position = Number(hint ? hint.activeWorkspacePosition : -1)
    if (!isFinite(position) || position < 0)
        return null
    return {
        base: position - 1,
        span: 0,
        direction: 0,
        activeSlot: 1,
        activePosition: position,
        fromPosition: position,
        toPosition: position,
        slots: 3
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

// Where the active column must be scrolled for one row to be visible: the smallest
// move that brings the row inside the viewport, clamped to the scrollable range.
//
// "Smallest move", not "centre it": the launcher centres because it is stepping a
// selection through a long list under the keyboard, where the next step has to be
// visible too. Here the scroll exists to reveal a window that niri has already
// focused, and centring it would move the panel further than it has to - which on a
// seven-window workspace means scrolling when the row was already on screen.
//
// Pure, and the arithmetic the component and the suite both read, so neither holds a
// private copy of when a row counts as visible.
function revealScrollY(scrollY, rowTop, rowHeight, viewportHeight, maximumY) {
    var current = Number(scrollY)
    if (!isFinite(current))
        current = 0
    var top = Number(rowTop)
    var height = Number(rowHeight)
    var view = Number(viewportHeight)
    var limit = Number(maximumY)
    if (!isFinite(top))
        return 0
    if (!isFinite(height) || height <= 0)
        return Math.max(0, Math.min(isFinite(limit) ? limit : 0, current))
    if (!isFinite(view) || view <= 0)
        return 0
    var target = current
    if (target > top)
        target = top
    else if (target + view < top + height)
        target = top + height - view
    var high = isFinite(limit) && limit > 0 ? limit : 0
    return Math.max(0, Math.min(high, target))
}