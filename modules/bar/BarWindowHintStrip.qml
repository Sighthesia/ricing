import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic
import "./WindowHintRowMotion.js" as RowMotion

// One strip of workspace columns and nothing else: a run of consecutive
// workspaces, left to right, the active one among them.
//
// Instantiated once by the body. A workspace switch is not two copies of this
// sliding past each other - it is ONE strip, `span + 3` columns wide, holding
// every workspace position exactly once, which is why no window title can be
// painted twice during the crossing: there is only one place it could be painted
// from. See `WindowHintMenuLogic.stripPlan`.
//
// NOTHING HERE IS TRANSLATED. Every column places ITSELF, from
// `WindowHintMenuLogic.slotX` and `slotWidth`, off one number: how far it is from
// the workspace the panel is centred on. That number is the body's, it is
// fractional mid-crossing, and the crossing is nothing more than it running from
// the workspace being left to the one being moved to - so the arriving column
// slides in AND widens, the one being left slides out AND narrows, and the band
// they pass through never moves at all.
//
// It was a strip that translated as one object with every column at a uniform
// `index * columnPitch`, and a uniform pitch is a layout that cannot express a
// wide middle slot: it has nowhere to put the extra 180px, so the alternative was
// one card growing over its neighbours' cards. See `slotX` for why this shape
// cannot overlap at any instant, and why a second switch landing mid-crossing
// needs no correction at all.
//
// The focus highlight and the indicator are NOT here. Focus belongs to the
// content that is arriving, and the body owns those markers so they can be placed
// against `activeColumnX` - which is the arriving column's own placement read
// through the same function its delegate uses, rather than a second guess at where
// the active slot is.
//
// Geometry and vocabulary are passed in rather than measured, so the strip cannot
// drift from the panel by a pixel, and `columns` is the ordered list the body built
// rather than a view model assembled here: the ordering IS the rule that stops the
// duplication, and there is one place it is decided.
Item {
    id: root

    // The strip, one entry per workspace position, in order. Each is
    // `{ position, rows, hidden }` as `WindowHintMenuLogic.stripColumns` builds
    // them. `position` is what the layout below is keyed on - a strip that did not
    // say which workspace a column was for would have nothing to place it by.
    property var columns: []
    property int columnWidth: HintLogic.COLUMN_WIDTH
    // The active workspace's column is this much wider than a neighbour's, so every
    // width on this strip is one of two numbers and `slotWidth` is the only thing
    // that decides between them.
    property int activeColumnWidth: HintLogic.ACTIVE_COLUMN_WIDTH
    // Gap between columns, and the pitch two NEIGHBOUR-width columns produce. The
    // middle slot's pitch is not this: it is the neighbour pitch plus the active
    // column's extra width, and `rightX` below is where that lands.
    //
    // The columns were flush: one column's right edge was the next one's left edge, so
    // the cards in adjacent columns touched and the three columns read as one block
    // rather than as three workspaces. The bar's workspace widget separates its squares
    // by `inlineGap`, and this is the same token at three times the size.
    property int columnGutter: 0
    readonly property int narrowPitch: columnWidth + columnGutter
    // The right neighbour's left edge: one neighbour, one gutter, the wide middle
    // column, one gutter. The layout function is handed this rather than deriving
    // it, so the panel's own arithmetic exists in exactly one place.
    readonly property real rightX: narrowPitch + activeColumnWidth + columnGutter
    // Padding between the band's edge and the cards inside it, on every side.
    //
    // Horizontal padding inside the cell. `Workspaces.qml` makes its square
    // `contentRow.implicitWidth + cellPadding * 2` wide, so the widget's own padding
    // is 8 a side; the highlight then covers that square exactly, which is why the
    // margin belongs inside the marked cell rather than between the highlight and the
    // thing it marks. Vertical padding is the body's, since it comes from a different
    // number - see `cellPaddingX` / `cellPaddingY` there.
    property int cellPaddingX: 0
    property int listSpacing: 6
    property int rowHeight: 28
    property int glyphInset: 20
    property int glyphWidth: 16
    // False while a crossing is in flight: what is under the pointer is either
    // leaving or has not arrived.
    property bool interactive: true
    // How many rows the active column shows at once. `MAX_WINDOW_ROWS`, and the
    // panel is sized from the strip rather than from the content, so this is also
    // what bounds the panel's height - and therefore the layer-shell input region -
    // however many windows the workspace holds.
    property int viewportRows: HintLogic.MAX_WINDOW_ROWS

    // The focus frame's own rectangle in THIS space, and whether it has stopped moving.
    // The first two are what the row's tint is a geometric function of; the third is what
    // the row's `Behavior on color` asks.
    //
    // Handed down rather than reached for because an id is file-scoped: `focusFrame` is a
    // child of this strip but it is DECLARED in the body, so nothing in here can name it.
    // It arrives as numbers, the way `rowHeight` and `rowPitch` do - and as a POSITION
    // rather than as a decision, which is the point: the body owns where the frame is,
    // and the row owns what that means for its own surface. Nothing in between says when
    // to apply it.
    //
    // `focusFrame` is declared after the strip, so these bindings are read for the first
    // time only once a window row exists - a row needs a snapshot, a snapshot needs a
    // created component, and by then both objects are there. Nothing reads them during
    // construction, which is the whole of what that ordering is safe on.
    property real focusFrameTop: 0
    property real focusFrameHeight: 0
    // ...and its horizontal extent, which is what makes the mask a MASK rather than a
    // full-width band. The frame is exactly one card wide, and WHICH card changes across
    // a crossing - so its left edge is a question with three answers over a journey, not
    // one, and left unasked the mask cannot tell which column it is in.
    property real focusFrameLeft: 0
    property real focusFrameWidth: 0
    // Observation slow-motion, fed from the body. The row flash and the focus tint live
    // here rather than on the body, so they are on the marker's path and have to be
    // slowed with it - a 100ms tint left unscaled next to a 2s journey is the one thing
    // still moving at speed.
    property real debugTimeScale: 1

    // How far the ACTIVE column is scrolled, in pixels. Owned here rather than by the
    // body because the scrolling content is here: the column's own `y` is this offset,
    // and the body needs it only to place the focus markers against the same scrolled
    // geometry the rows are drawn in.
    property real scrollOffset: 0
    // How far the active column CAN be scrolled: its full content less the viewport.
    // Zero when it fits, which is what makes a list that fits refuse the wheel.
    readonly property real maxScrollOffset: Math.max(0,
        activeColumnContentHeight - viewportHeight)

    readonly property int rowPitch: rowHeight + listSpacing
    readonly property int viewportHeight: Math.max(0,
        viewportRows * rowPitch - listSpacing)

    signal windowActivated(string windowId)

    // Which slot is drawn as CARDS and which as plain labels. The body reads it off
    // the plan it built the strip from, so the two cannot disagree about which
    // column carries the card fill.
    property int activeSlot: 1
    // The workspace the focus markers belong to: the arriving frame's active one. A
    // DIFFERENT column from the one `activeSlot` picks at the start of a crossing -
    // it is off-panel then, and arrives in the middle.
    property int activePosition: 0
    // The workspace the panel is CENTRED on, fractionally. Whole at rest, a real
    // fraction in the middle of a crossing, and the only thing that moves: every
    // column here is a pure function of it.
    property real panelPosition: 0

    // The arriving column's own placement, read through the SAME function its own
    // delegate uses. It used to be `activeSlot * columnPitch`, a number in the
    // strip's uniform pitch rather than in the layout - and with a wide middle slot
    // those are not the same number, so a second guess here would have been a second
    // chance to be wrong.
    readonly property real activeColumnX: columnXFor(root.activePosition)
    readonly property real activeColumnWidthNow: columnWidthFor(root.activePosition)
    // The focused row's card width: the active column less its own padding. A
    // function of the clock like the column's x, because the outline drawn around
    // that row has to be exactly as wide as the row at every instant of a crossing,
    // not merely at its ends.
    readonly property real activeCardWidth: Math.max(
        0, activeColumnWidthNow - cellPaddingX * 2)

    function columnXFor(position) {
        return HintLogic.slotX(position - root.panelPosition,
            root.narrowPitch, root.rightX)
    }

    function columnWidthFor(position) {
        return HintLogic.slotWidth(position - root.panelPosition,
            root.columnWidth, root.activeColumnWidth)
    }

    // Is the focus frame's band over this row, right now? The whole of the focus tint.
    //
    // The frame is a rectangle one row tall travelling down a list, and a card is tinted
    // for exactly as long as that rectangle overlaps it. The frame's live position IS the
    // mask; nothing else decides, so the tint cannot lead the frame or lag it.
    //
    // Strictly a POSITIVE overlap. The frame's lower edge reaching a row's upper edge is
    // the instant that row lights, because the frame really is on it - and a card the
    // frame has just touched has to be lit, or "the region the frame encloses changes
    // colour" would mean something weaker than it reads. Half-open bounds would have
    // bought a tidier handoff at the cost of leaving a card dark while a rectangle is
    // visibly sitting on it.
    //
    // The row's own rect is computed, not measured off the delegate: `y` is
    // `index * rowPitch - scrollOffset`, because the active column is drawn at its own
    // negative scroll offset and the strip's space is therefore the scrolled one. That is
    // the same expression the body's `focusedRowTop` uses for the frame's resting place,
    // so the two agree about where a row is by construction.
    //
    // Only the vertical band is compared, and that is the whole of it rather than a
    // shortcut: every card on this strip is in the one ACTIVE column, so they all share
    // an x and a width, and a horizontal test could only ever reject all of them or none
    // of them. The frame is what travels along the list, and the list runs down.
    //
    // What it costs is worth stating, because it is visible and it is intended. A row is
    // `rowHeight` tall and the gap between rows is `listSpacing` - 28 and 6 - so a band
    // 28 tall cannot fit in a 6px gap: where it straddles the space between two cards it
    // lights BOTH, and the highlight is handed from one card to the next by a short
    // overlap rather than by a gap. That is what the frame's rectangle says about two
    // cards, and the frame is drawn around whichever of them it is nearer. It lasts for
    // `rowHeight - listSpacing` of travel - 22px, two thirds of a row pitch - and it is
    // the reason a focus glide reads as one sweep rather than as a switch.
    // The frame's rectangle CLIPPED TO this row, in the row's own coordinates. The mask,
    // not a yes/no.
    //
    // The row's rect in the strip's space starts at `index * rowPitch - scrollOffset` -
    // the scroll is in here because the active column is drawn at `-scrollOffset`, so a
    // row's on-screen position and its position in the list are two different numbers and
    // this one is the on-screen one. The frame's rect is `focusFrameTop` through
    // `focusFrameTop + focusFrameHeight`. What this returns is their intersection, expressed
    // relative to the row so the overlay can be a plain child of it.
    //
    // The card itself, and the card's OWN `y` as where it sits - not an index and not a
    // re-derived pitch. Two reasons, both found by measurement.
    //
    // The neighbour label's `required property int index` is never filled: read off the
    // objects, all three columns' labels reported `index` 0, while a bare `index` at the
    // instantiation site and `neighbourLabel.index` there both read 0 too. Every
    // neighbour's mask therefore landed on row 0's geometry and none of them lit. The
    // Column has already placed every delegate, so `card.y` is the answer that does not
    // depend on a broken property - and it is a better answer regardless, since the
    // Column's own spacing is then not restated here.
    //
    // The column comes from `parent`, which is the same answer for an active row and a
    // neighbour label, so neither has to be told which it is. Its `y` is added because
    // the card's own is relative to it, and it is `- scrollOffset` for the active column
    // and 0 for a neighbour: only the active one scrolls. A `- scrollOffset` term in the
    // function, which is what an earlier version did, put a neighbour's mask a viewport
    // out of place on any scrolled panel.
    //
    // `top` may exceed the card's height and `height` may come back zero or
    // negative; the caller clamps nothing, because a zero-height overlay IS the
    // answer for "the frame is not on this card" and `visible` reads it.
    // The card's strip-space Y: its own `y` plus every ancestor's `y` up to (but
    // not including) the strip itself. The active list lives in an inner content
    // Column offset by `-scrollOffset` inside an outer viewport Item pinned at y=0,
    // so summing the chain is what keeps the mask on the scrolled row rather than
    // on its unscrolled position. A single `parent.y` term was correct only while
    // the scrolled Column was also the clipped viewport - which moved its own clip
    // rect with the offset and left a blank band at the bottom (see the delegate).
    function _cardTopInStrip(card) {
        var top = card.y
        var p = card.parent
        while (p && p !== root) {
            top += p.y || 0
            p = p.parent
        }
        return top
    }

    // The card's strip-space X, same walk as above. The inner content Column sits
    // at x=0 inside the outer viewport, so reading the direct parent alone would
    // report the padding without the column's own placement.
    function _cardLeftInStrip(card) {
        var column = card.parent
        while (column && column.parent && column.parent !== root
            && column.isActiveSlot === undefined)
            column = column.parent
        if (!column)
            return root.cellPaddingX
        return (column.x || 0) + root.cellPaddingX
    }

    function _cardWidthInStrip(card) {
        var column = card.parent
        while (column && column.parent && column.parent !== root
            && column.isActiveSlot === undefined)
            column = column.parent
        var w = column ? column.width || 0 : 0
        return Math.max(0, w - root.cellPaddingX * 2)
    }

    function frameMaskOverCard(card) {
        const top = root._cardTopInStrip(card)
        const maskedFrom = Math.max(top, root.focusFrameTop)
        const maskedTo = Math.min(top + root.rowHeight,
            root.focusFrameTop + root.focusFrameHeight)
        return {
            top: maskedFrom - top,
            height: Math.max(0, maskedTo - maskedFrom)
        }
    }

    // Is the frame over this card's COLUMN at all? The vertical half cannot answer
    // that, and answering only the vertical one is the whole of the fault these two
    // functions exist to fix.
    //
    // The mask used to intersect on the vertical axis alone, which is correct exactly
    // as long as the frame is over the active column - and it is only ever over the
    // ACTIVE column for the second half of a journey. For the first half it is on the
    // card being left, in a departing column that is itself sliding out, and the
    // active column frequently has a row at the very same height: measured across the
    // departure leg of a 2-to-3 switch the frame's x ran 205 -> 131 while the active
    // column's row 1 sat at 571 -> 425, and the mask lit the active column's rows 1,
    // 2, 3, 4 and 5 in turn as the frame merely DESCENDED past their heights. The
    // highlight looked confined to the workspace being moved to, and it appeared
    // before the frame got there.
    //
    // An overlap test rather than an equality, because mid-crossing the frame is as
    // wide as the card it is over and that card changes width as its column narrows.
    function frameOverCard(card) {
        const left = root._cardLeftInStrip(card)
        const width = root._cardWidthInStrip(card)
        return Math.min(left + width, root.focusFrameLeft + root.focusFrameWidth)
            - Math.max(left, root.focusFrameLeft) > 0
    }

    // The tallest column on the strip, MEASURED rather than bound.
    //
    // This was a `readonly` property whose body looped over `columnRepeater.itemAt(i)`
    // and read `column.height` off each delegate. QML tracks no dependency through
    // `itemAt`: the only property the loop touched was `root.columns`, so the whole
    // expression was evaluated when the list was replaced and then never again, and the
    // panel was sized from whichever heights the delegates happened to hold at that
    // instant. A stale read.
    //
    // It did no harm until the scroll. The cap made a column's height a function of its
    // row count, which is available the moment the model is assigned, so a measurement
    // taken a frame early was the right answer by luck. The viewport makes a column's
    // height depend on its own laid-out content instead, and the stale answer was a
    // viewport's worth for a twelve-row column - the panel sized itself for five rows of
    // a list it was about to draw twelve of.
    //
    // So it is written by `remeasureHeight`, called from each column's own
    // `onHeightChanged` and once after a list replacement. Imperative because a binding
    // cannot see through `itemAt` at all, and the alternative - predicting the height
    // from the row count - is the second copy of the layout's rules that the comment
    // above this one used to warn against.
    property int contentHeight: 0

    function remeasureHeight() {
        var tallest = 0
        for (var i = 0; i < columnRepeater.count; ++i) {
            var column = columnRepeater.itemAt(i)
            if (column && column.height > tallest)
                tallest = column.height
        }
        // Only on a change: a column's `onHeightChanged` fires during layout, and
        // writing an unchanged value from there would dirty the binding for nothing.
        if (tallest !== root.contentHeight)
            root.contentHeight = tallest
    }

    // Synchronously, not deferred: the body's `focusedRowIndex` is read off `activeRows`,
    // and a turn's worth of staleness there would place the markers against the list the
    // previous publish left behind - which is the same one-frame lag that made the
    // tracker read the previous row's target.
    onColumnsChanged: {
        root.reconcileAllRows()
        Qt.callLater(remeasureHeight)
    }

    // --- rows entering and leaving ------------------------------------------
    // `columns` is what the SNAPSHOT says a column holds, replaced wholesale on every
    // publish - so a window closing is a row that simply stops being there, and there
    // is nothing left to animate. The rows this strip actually paints are therefore
    // kept here, one list per workspace position, and reconciled against the snapshot
    // instead of being replaced by it: `WindowHintRowMotion` returns the union of what
    // was on screen and what has arrived, each entry carrying the phase it is in and the
    // values its own animation has reached. That file's header is where the reasoning
    // for data-rather-than-item state lives, and it is a Quickshell fact rather than a
    // preference: a `Repeater` over a JS array rebuilds every delegate when the array is
    // reassigned.
    //
    // Keyed by workspace POSITION and not by column index, because a column's index on a
    // strip mid-crossing is the slot it happens to occupy - and a crossing renumbers
    // those. The position is what a column is FOR, so it is what its rows belong to.
    property var rowsByPosition: ({})
    // The workspace whose rows the markers are placed against: the arriving frame's, so
    // `activeRows` is the list the focus frame and the bar are reading.
    readonly property var activeRows: root.rowsByPosition[root.activePosition] || []
    // Is a row arriving or leaving anywhere in the active column? The body asks this to
    // decide whether its markers may be placed by the plain pitch or have to follow the
    // layout, and it is asked of the records because the items are the half that is
    // rebuilt.
    readonly property bool rowsTransitioning: {
        root.rowRevision
        return RowMotion.anyMoving(root.activeRows)
    }
    // A row CROSSING to a new place, which is NOT the same question - see `anyReordering`.
    // Only this one means the markers have no fixed target to ease toward; a row arriving or
    // leaving changes the layout under them but leaves their target where it is.
    readonly property bool rowsReordering: {
        root.rowRevision
        return RowMotion.anyReordering(root.activeRows)
    }

    // The strip's own columns, as objects: what is actually on the strip right now, rather
    // than what the model says should be. Readable from outside this file because a
    // column's rows live inside a `Repeater`, where an id is file-scoped and nothing can
    // reach them - and "what is this column painting" is the one question a diagnostic
    // cannot answer from the snapshot.
    readonly property var columnItems: {
        var items = []
        for (var i = 0; i < columnRepeater.count; ++i) {
            var item = columnRepeater.itemAt(i)
            if (item)
                items.push(item)
        }
        return items
    }

    function reconcileAllRows() {
        var previous = root.rowsByPosition || ({})
        var next = ({})
        for (var i = 0; i < root.columns.length; ++i) {
            var column = root.columns[i]
            if (!column || column.position === undefined)
                continue
            var key = String(column.position)
            next[key] = RowMotion.reconcileRows(previous[key], column.rows || [],
                MotionTokens.windowRowStagger)
        }
        // Positions the strip no longer carries keep nothing: a workspace that left the
        // run is not on screen, and holding its rows would be state waiting to be wrong
        // when that position comes back into view with different windows.
        root.rowsByPosition = next
    }

    // Drop a row whose exit has played. Called by the row itself, because the thing that
    // knows when its own animation finished is the thing that says so.
    function retireRow(position, rowKey) {
        var key = String(position)
        var list = root.rowsByPosition[key]
        if (!list)
            return
        var kept = []
        for (var i = 0; i < list.length; ++i) {
            if (String(list[i].key) !== String(rowKey))
                kept.push(list[i])
        }
        if (kept.length === list.length)
            return
        var next = ({})
        for (var p in root.rowsByPosition)
            next[p] = root.rowsByPosition[p]
        next[key] = kept
        root.rowsByPosition = next
        // A row leaving changes the scroll range, and an offset past the new end would
        // paint the list a row higher than it is.
        if (key === String(root.activePosition))
            root.clampScroll()
    }

    // How far the rows ABOVE `index` are short of their resting pitch, in pixels: a
    // collapsing or opening slot changes the offset of everything below it, and the
    // focus markers are placed against the rows, not against the pitch. Read from the
    // records' live `presence`, so it is exact at every frame of a transition rather than
    // only at its ends.
    function rowLiftFor(index) {
        // The revision for the same DEPENDENCY reason `slotTopAt` reads it: a move's
        // progress lives on a plain record, so nothing would invalidate this otherwise.
        root.rowRevision
        return RowMotion.liftAt(root.activeRows, index, root.rowHeight, root.listSpacing)
    }
    // The same number for the focused row, which is what the body's markers subtract.
    //
    // `rowRevision` is read for its DEPENDENCY and for nothing else: `activeRows` is a JS
    // array, and mutating a record's `presence` inside it notifies nobody - so a binding
    // that only read the array would compute the lift once and hold it while the slots
    // moved. Every row bumps this when it moves, which is what makes `rowLift` a live
    // function of the layout rather than of the last publish.
    //
    // NOTHING ELSE LISTENS TO IT, deliberately. The body's markers subtract `rowLift` where
    // they are DRAWN, exactly as they already subtract the viewport's scroll - so a slot
    // closing under them moves the mark on the same frame, and the tracker is never told
    // the layout moved. It was told, for one round: a handler on this counter re-snapped
    // both ends of the indicator, which on a workspace switch's row transition ran every
    // frame and closed the wake before it could open. That is the report - "the indicator
    // teleports instead of moving, no trail" - and it was the handler, not the animation.
    property int rowRevision: 0
    // The outstanding height of the slots ABOVE the focused row, in pixels: the correction
    // that turns `index * rowPitch` into where that row is actually DRAWN.
    //
    // The same walk `slotTopAt` does for the rows themselves, so the two cannot disagree -
    // verified against it at every frame of an exit, 68 -> 59.5 -> 51 -> 42.5 -> 34. Only a
    // LEAVING slot contributes: an arriving one opens into space the list does not have yet,
    // and counting its shortfall is what once summed eleven opening slots into a lift of 199
    // and put the mark above the panel.
    // The SAME arithmetic the rows are drawn with, asked about the focused row.
    //
    // `rowLiftFor` -> `RowMotion.liftAt` counts a slot's shortfall only while
    // `phase === "exit"`, which is right for the layout's own purposes and wrong here: the
    // moment the departing record is dropped from the list, that term stops existing and the
    // lift jumps to zero in one frame. The rows do not jump - `slotTopAt` walks `presence`
    // and the last frame before the drop still had a few tenths left in it - so the mark and
    // the row it marks parted company by the whole remaining height on that frame.
    //
    // So this walks the same way `slotTopAt` does, over the rows above the focused one, and
    // asks each for its `presence` rather than for its phase. Measured on "close the middle
    // window, focus lands on the next one": 64.6 -> 35 in one frame against a row that moved
    // 38 -> 34.
    readonly property real rowLift: {
        root.rowRevision
        var list = root.activeRows
        var pitch = root.rowHeight + root.listSpacing
        var lift = 0
        for (var i = 0; i < list.length && i < root.focusedRowIndex; ++i) {
            if (!list[i])
                continue
            // Only a LEAVING slot shortens the rows below it. An arriving one is opening
            // into space the list does not have yet, so it takes nothing off them - the same
            // distinction `liftAt` draws, and it has to survive here or the first frame of a
            // panel build sums eleven opening slots into a lift of 199 and puts the mark
            // above the panel.
            if (list[i].phase !== "exit")
                continue
            var presence = list[i].presence !== undefined ? Number(list[i].presence) : 1
            if (!isFinite(presence))
                presence = 1
            lift += pitch * (1 - Math.max(0, Math.min(1, presence)))
        }
        return lift
    }
    readonly property int focusedRowIndex: {
        var list = root.activeRows
        for (var i = 0; i < list.length; ++i) {
            if (list[i] && list[i].isFocused === true)
                return i
        }
        return -1
    }
    function liveRowTop(index) {
        // The row's own travel is part of where it is, not an adjustment to the index it
        // currently holds: a reordering row is drawn between two places, and the marker has
        // to sit on it rather than on the place it is heading for.
        root.rowRevision
        // The travel is asked of the ACTIVE column, which is the one the markers follow.
        // Guarded on the FUNCTION rather than only on the item: a column delegate is a
        // plain `Item` until its own definition has been applied, so a marker placed in the
        // same turn the strip is built can reach an item that does not answer yet - and a
        // missing answer here is "no travel", not an error.
        var column = root.activeColumnItem
        var travel = column && typeof column.moveOffsetAt === "function"
            ? column.moveOffsetAt(index) * root.rowPitch : 0
        return index * root.rowPitch - root.rowLiftFor(index) + travel
            - root.scrollOffset
    }

    // Nothing needs an exit animation while the surface is off screen, and the state this
    // leaves behind is exactly a resting panel. The hint body is a persistent object that
    // is shown and hidden with the popup, so a row that was mid-exit when the panel closed
    // would otherwise still be sitting in `rowsByPosition` the next time it opens.
    function flushRows() {
        var next = ({})
        for (var position in root.rowsByPosition) {
            var list = root.rowsByPosition[position]
            var kept = []
            for (var i = 0; i < list.length; ++i) {
                var record = list[i]
                if (record.phase === "exit")
                    continue
                record.phase = "live"
                record.delayMs = 0
                record.presence = 1
                record.ink = 1
                record.started = true
                kept.push(record)
            }
            next[position] = kept
        }
        root.rowsByPosition = next
        root.clampScroll()
    }

    onVisibleChanged: if (!visible) root.flushRows()

    // The scroll range, not the panel height, is what decides whether an offset is still
    // legal - and it is the one that changes when a crossing brings a shorter list.
    //
    // Hooked here as well as on `contentHeight` because the two do not move together: a
    // workspace going from twelve windows to two changes the RANGE from 238 to 0 while
    // the panel's height happens to be unchanged by the same publish, and a clamp that
    // only listened for the height would leave the list scrolled 238px past its own
    // end. It showed as two unrelated faults - a stale offset in one test, and a click
    // that landed on a row the previous test had scrolled out of the panel in another.
    onMaxScrollOffsetChanged: {
        // The outstanding reveal first: a range that has just grown is a new answer to the
        // question it asked, and clamping an offset it is about to set would be work done
        // in the wrong order.
        if (root._revealIndex >= 0) {
            root._applyReveal()
            return
        }
        root.clampScroll()
    }

    // The active column's own full height, unclamped. This is what the scroll range is
    // measured against, so it has to be the content and not the viewport.
    readonly property int activeColumnContentHeight: {
        var column = root.activeColumnItem
        return column ? column.contentHeight : 0
    }

    // One delegate per workspace position. Both `x` and `width` are DERIVED from the
    // workspace the column is for and the one the panel is centred on - not
    // accumulated by a `Row`, and not read back from a sibling's geometry. A
    // positioner would lay out against a stale width in any case (its pass lands
    // after the frame that created the delegate), and because nothing about the
    // columns then changes again it would never re-lay-out.
    // The active column's own Column, for the scroll range. Found by asking the
    // Repeater rather than by keeping a reference: a delegate reference is a binding to
    // a row that a `Repeater` is free to destroy and rebuild, and a stale one would
    // measure a column that is no longer on the strip.
    readonly property Item activeColumnItem: {
        for (var i = 0; i < columnRepeater.count; ++i) {
            var column = columnRepeater.itemAt(i)
            if (column && column.isActiveSlot)
                return column
        }
        return null
    }

    Repeater {
        id: columnRepeater
        model: root.columns

        // A workspace column. The active slot carries the card fill and the
        // overflow line; its neighbours are plain labels. Which is which is the
        // index, not a flag on the model, so a column cannot claim to be the
        // active one and disagree with the body about it.
        //
        // The active column is a VIEWPORT plus a scrolling list, and the two are
        // deliberately two objects: the outer Item is the viewport - pinned at y=0,
        // clipped to the viewport height - and the inner Column is the full list,
        // offset by `-scrollOffset`. One object cannot be both: a Column that clips
        // itself AND offsets itself moves its own clip rect with the offset, so a
        // list scrolled by one row painted the same five rows one row higher and
        // left a blank band at the bottom. Past five windows every scrolled card
        // read as disappearing into that band.
        Item {
            id: stripColumn
            required property int index
            required property var modelData

            // Placed by the layout function. Both numbers move during a crossing
            // and neither is a transform: the column genuinely travels to a new
            // place at a new size, which is why the width change comes free here
            // instead of needing a scale or a second clock.
            x: root.columnXFor(stripColumn.modelData.position)
            width: root.columnWidthFor(stripColumn.modelData.position)
            y: 0
            readonly property bool isActiveSlot: stripColumn.index === root.activeSlot
            // The viewport: the full list for a neighbour, the window's height for
            // the active column. The neighbours are capped by the logic and drawn
            // whole, which is why they need no clip.
            clip: stripColumn.isActiveSlot
            // The column's height is what its slots MEASURE, which is now a continuous
            // number rather than a row count: a slot opening or closing changes it a frame
            // at a time, so the panel and the rows below a transition travel on the same
            // value and there is nothing left for a second animation to catch up on. It
            // also means the drop of a spent row does not change the height at all - a slot
            // is already zero by the time it is removed.
            height: stripColumn.isActiveSlot
                ? Math.min(contentColumn.implicitHeight, root.viewportHeight)
                : contentColumn.implicitHeight
            // The column's own unclamped height, for the scroll range. The outer
            // `height` is the viewport once the clamp above binds, so the range
            // needs this rather than the height.
            readonly property int contentHeight: contentColumn.implicitHeight
            // Announce a resize, because the strip measures its columns through
            // `itemAt` and has no binding that could see this one. See
            // `strip.remeasureHeight`.
            onHeightChanged: root.remeasureHeight()
            // What a column's own content is given: the column less its padding,
            // which is what every row, placeholder and overflow line is laid out in.
            // A property rather than a binding repeated at each use, so the row, the
            // label, the placeholder and the overflow line cannot be given three
            // different widths on a frame where the column is mid-resize.
            readonly property real cardWidth: Math.max(
                0, stripColumn.width - root.cellPaddingX * 2)
            // The rows this column PAINTS, which is not the same list as the one the
            // snapshot hands it: a window that closed is still here until its exit has
            // played. Read off the strip's reconcile map, keyed by workspace position, so
            // a crossing renumbering the slots cannot hand this column another
            // workspace's rows.
            readonly property var rowList: root.rowsByPosition[stripColumn.modelData.position]
                || []
            // The workspace this column is for, as the string the reconcile map is keyed
            // on - and the object that holds its slots. Published for the same reason
            // `columnItems` is: a diagnostic has to be able to ask a column what it is
            // drawing.
            readonly property string positionKey: String(stripColumn.modelData.position)
            property alias columnBody: contentColumn

            // The slot at `index`'s own travel, in pitches, read off the ITEM that is
            // drawing it. Not from the record: the record says where a window went, and the
            // item is what knows how much of that journey is left - and only one of those
            // two is what the user sees.
            function moveOffsetAt(index) {
                var slot = stripColumn.slotAt(index)
                return slot ? slot.moveOffset : 0
            }

            // The slot at a column position, found by the ITEM'S OWN place rather than by
            // its `slotIndex` property: the children are in `Repeater` order, which is the
            // order the column draws in, so the child at `index` is the slot at `index`.
            //
            // This walks `columnBody`'s children rather than the `Repeater` because the
            // repeater's id is scoped to the column's content, and this has to be callable
            // from the strip root as well - the markers ask it where a row is.
            function slotAt(index) {
                if (!stripColumn.columnBody)
                    return null
                var children = stripColumn.columnBody.children
                var slot = children[index]
                return slot && slot.moveOffset !== undefined ? slot : null
            }

            // Where the slot at `index` starts, in the column's own space. THE running sum,
            // and the only one: a row's place is what every slot above it measures. Rows are
            // then placed by their own `y` rather than by a positioner, so a height that
            // changes on a frame moves everything below it on that same frame.
            //
            // `presence` is the slot's own 0-to-1, and `presence * pitch` is its height, so
            // the sum is over exactly the numbers the animations drive.
            function slotTopAt(index) {
                // The revision is read for its DEPENDENCY: a slot's travel lives on the item,
                // so nothing in the model would invalidate this otherwise.
                root.rowRevision
                var top = 0
                var list = stripColumn.rowList
                var pitch = root.rowHeight + root.listSpacing
                for (var i = 0; i < index && i < list.length; ++i) {
                    var presence = list[i] && list[i].presence !== undefined
                        ? Number(list[i].presence) : 1
                    if (!isFinite(presence))
                        presence = 1
                    // The slot's own height, and NOT its travel.
                    //
                    // This used to add `moveOffsetAt(i)` as well, on the argument that a
                    // row crossing its neighbours occupies the space it passes through. That
                    // double-counts the same displacement: `rowTopAt` adds the row's own
                    // travel on top of this sum, so every row below a moving one was pushed
                    // by it a second time - measured, a swap put the three rows that were
                    // only being displaced at 89.3 / 95.6 / 102 instead of 0 / 34 / 68, and
                    // they slid back out of nowhere. A row's travel is its own; the rows
                    // below it are moved by its SLOT, which is the `presence` term and does
                    // not change on a reorder.
                    top += pitch * presence
                }
                return top
            }

            // A row's own drawn top: its place in the layout, plus the travel it has left.
            // The one expression, so the row and the marker that follows it are placed from
            // the same numbers.
            function rowTopAt(index) {
                root.rowRevision
                var pitch = root.rowHeight + root.listSpacing
                return stripColumn.slotTopAt(index)
                    + pitch * stripColumn.moveOffsetAt(index)
            }

            // The full list. Only this moves on scroll; the viewport above stays
            // put, which is what keeps the clip rect over the panel while the rows
            // travel under it.
            //
            // NO POSITIONER, and that is the whole of how a transition lays out. A row's
            // height is a CONTINUOUS number here - that is what makes a slot open and close
            // - and a `Column` is not the right tool for a continuous layout: it places its
            // children from their measured heights, and a height that changes every frame
            // asks it to re-place every sibling on every frame, which is the arrangement
            // that left this list with every `y` at zero and `implicitHeight` at zero while
            // its children were each 34px tall. A plain `Item` whose children place
            // THEMSELVES from the same running sum is both correct and cheaper: the sum is
            // one subtraction (see `HintRow.slotTopFor`), and it cannot fall a frame behind
            // the heights it is summing because it is not a second pass over them.
            Item {
                id: contentColumn
                width: stripColumn.width
                y: stripColumn.isActiveSlot ? -root.scrollOffset : 0
                // The block's own height: the running sum of its slots, which is what the
                // viewport clips to and what the panel is sized from. Computed rather than
                // measured, because the items are placed by the same expression.
                readonly property real contentTop: {
                    root.rowRevision
                    return stripColumn.rowList.length === 0
                        ? 0 : stripColumn.slotTopAt(stripColumn.rowList.length)
                }
                implicitHeight: stripColumn.rowList.length === 0
                    ? root.rowHeight
                    : contentTop - root.listSpacing
                height: implicitHeight
                onImplicitHeightChanged: root.remeasureHeight()

            // The rows this column is painting, in order: the union of what the
            // snapshot says and what is still leaving. One `Repeater` over that list,
            // and each entry is a slot that carries its own arrival or departure - so a
            // window closing is a row that collapses out of the list rather than a row
            // that stops existing between two frames.
            //
            // The COLUMN's `spacing` is zero and the gap between rows rides inside each
            // slot (see `HintRow.slotPitch`): a `Column` would leave its spacing behind
            // when a slot collapsed to nothing, which is a dead gap exactly where a row
            // is leaving.
            Repeater {
                id: columnRowRepeater
                model: stripColumn.rowList.length

                HintRow {
                    id: rowSlot
                    required property int index
                    // The slot's own place, as opposed to the place of the row it is
                    // drawing. The `Repeater`'s injected `index` is this one.
                    slotIndex: rowSlot.index
                    // The record is taken BY INDEX rather than handed over as
                    // `modelData`, and that is load-bearing rather than stylistic: a
                    // `Repeater` given a JS array hands each delegate a COPY of its
                    // element, so the slot's writes back into its own progress would land
                    // on a throwaway object and the record the strip reconciles against
                    // would stay frozen at whatever the publish put there - every
                    // rebuilt delegate would then restart its animation from the start.
                    // Indexing the live array gives the same object the map holds, which
                    // is what makes the record the durable half of the pair.
                    record: stripColumn.rowList[rowSlot.index]
                    // Placed from the slots above it rather than by a positioner: see the
                    // note on `contentColumn`. The sum is a function of the same presence
                    // values the slot animates, so the row below a closing card is where
                    // the closing card says it is, on every frame.
                    // The row's own drawn top, which is its place in the layout plus the
                    // travel a reorder has left - see `rowTopAt`.
                    y: stripColumn.rowTopAt(rowSlot.index)
                    x: root.cellPaddingX
                    width: stripColumn.cardWidth
                    cardWidth: stripColumn.cardWidth
                    rowHeight: root.rowHeight
                    listSpacing: root.listSpacing
                    glyphInset: root.glyphInset
                    glyphWidth: root.glyphWidth
                    active: stripColumn.isActiveSlot
                    interactive: root.interactive
                    // Resolved here so an active card and a neighbour label are lit by one
                    // copy of the intersection rather than each carrying a second answer
                    // to the same question.
                    maskFor: function(cardItem) { return root.frameMaskOverCard(cardItem) }
                    maskVisible: root.frameOverCard(rowSlot)
                    onActivated: windowId => root.windowActivated(windowId)
                    onRowMoved: root.rowRevision++
                    onRetireRequested: rowKey => root.retireRow(
                        stripColumn.modelData.position, rowKey)
                }
            }

            // The slot this column shows when its workspace has no windows. The same for
            // the active column as for a neighbour: an empty workspace is the same fact
            // wherever it is, and a different shape for the middle one would make the
            // panel look as if it had a special case in it.
            //
            // It is a row slot like any other, so it too arrives and leaves rather than
            // blinking: the list going from nothing to its first window is a window
            // arriving in a column, and a placeholder that vanished on the frame the
            // first card began to grow would be the one hard cut in the panel. Its
            // `presence` is the same 0-to-1 the rows use, so the panel's height and the
            // rows below it move on the same number.
            BarWindowHintEmpty {
                objectName: "windowHintColumnEmpty"
                x: root.cellPaddingX
                y: 0
                width: stripColumn.cardWidth
                height: root.rowHeight * emptyPresence
                opacity: emptyPresence
                rowHeight: root.rowHeight
                // Not `visible` either, for the reason at `HintRow`: a positioner skips an
                // invisible child, so the placeholder would leave the layout the moment it
                // started to shrink instead of shrinking inside it.
                property real emptyPresence: stripColumn.rowList.length === 0 ? 1 : 0
                Behavior on emptyPresence {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation {
                        duration: MotionTokens.windowRowExit
                        easing.type: Easing.InQuad
                    }
                }
            }

            } // contentColumn
        } // stripColumn viewport
    }

    // --- scrolling the active column ---------------------------------------
    // The launcher's scroll contract, verbatim where it applies: wheel-driven, with an
    // edge-takeover band that takes over before the bound and damps into it, a
    // rubber-band resistance past the bound, and a bounce that settles back.
    //
    // `LauncherPage.qml`'s `resultsView` and `LazerSettingsSections.qml` are the two
    // implementations and they agree on every number below - 80px of takeover, 88px of
    // overscroll, the same durations and the same eases. Copied rather than re-derived:
    // this is a list in the same shell with the same pointer, and a scroll that felt
    // different here would be the most obvious inconsistency in the panel.
    //
    // Only the ACTIVE column scrolls. The neighbours are capped by the logic and drawn
    // whole, so there is nothing to scroll them to - and a wheel that moved them would
    // desynchronise three columns that are read as one frame.
    //
    // `target: null` on the handler: a `WheelHandler` with a target drives that target's
    // own scroll, and this strip has no `Flickable` to drive - the offset is a plain
    // property here because the column's `y` is bound to it, so a Flickable would be a
    // second source of truth for one number.
    readonly property real edgeTakeoverDistance: 80
    readonly property real overscrollDistance: 88
    // True while the edge band is being driven by the wheel, so a wheel that leaves the
    // band hands the scroll back to the plain path instead of snapping.
    property bool edgeDriving: false
    // True while the offset is outside the scrollable range, which is what suppresses
    // the reveal-on-focus: a row scrolled to under a rubber band is not a row the user
    // asked to look at.
    readonly property bool overscrolled: scrollOffset < -0.5
        || scrollOffset > maxScrollOffset + 0.5

    // Rubber-band resistance, ported from `LauncherPage`'s `_resistedScrollTarget` and
    // `LazerSettingsSections`' `_resistedTarget`: the further past the bound, the
    // smaller each additional step becomes, like a spring approaching full tension.
    function _resistedTarget(current, delta, bound) {
        const past = Math.max(0, Math.abs(current - bound))
        const tension = Math.min(1, past / root.overscrollDistance)
        return current - delta * (1 - tension)
    }

    function _settleEdge() {
        edgeDriving = false
        edgeSettleTimer.stop()
        settleAnim.to = Math.max(0, Math.min(root.maxScrollOffset, root.scrollOffset))
        settleAnim.restart()
    }

    function _cancelEdge() {
        edgeDriving = false
        edgeSettleTimer.stop()
        settleAnim.stop()
        driveAnim.stop()
        root.scrollOffset = Math.max(0, Math.min(root.maxScrollOffset, root.scrollOffset))
    }

    // Keep the offset inside the scrollable range without animating, and without
    // dragging the reveal into it: this is a correction, not a scroll.
    //
    // A RUNNING REVEAL IS NOT CANCELLED HERE, and that is the whole of why a long list
    // could not be scrolled to its focused row. This is called from `onContentHeightChanged`
    // and `onMaxScrollOffsetChanged`, and the range it is clamping to MOVES on every frame
    // of a row transition - so the reveal it used to stop was being stopped by its own
    // target changing underneath it: measured, a reveal to the twelfth row of a twelve-row
    // workspace started at 40 toward 238 and was cancelled on the next frame by a clamp
    // raised from a slot's `presence`. The offset stayed at 40, the focused card stayed 200
    // pixels below the panel's bottom edge, and the panel looked as though it could not
    // scroll at all.
    //
    // What a correction owes the reveal is a target inside the new range, not a halt. The
    // animation is re-aimed when it is running and stopped when it is not, and the scroll
    // range it is aimed at is the one measured NOW rather than the one measured when the
    // row it is going to was published.
    function clampScroll() {
        settleAnim.stop()
        driveAnim.stop()
        edgeSettleTimer.stop()
        edgeDriving = false
        const limit = root.maxScrollOffset
        const clamped = Math.max(0, Math.min(limit, root.scrollOffset))
        if (revealAnim.running) {
            // Re-aim rather than restart: `to` is the only thing a running
            // `NumberAnimation` reads, so the remaining curve covers the remaining
            // distance and the reveal keeps the pace it set out with.
            //
            // The offset is NOT written here, and that is not tidiness either - an
            // animation is writing it on every frame, and a correction that writes it
            // between two of those frames is a second author for one number: measured, a
            // reveal running 0 toward 238 was held at 4.0 by the clamp raised from the
            // same column's resize, for the whole of its 300ms and after it.
            revealAnim.to = Math.max(0, Math.min(limit, revealAnim.to))
            return
        }
        root.scrollOffset = clamped
    }

    Timer {
        id: edgeSettleTimer
        interval: 140
        repeat: false
        onTriggered: root._settleEdge()
    }

    NumberAnimation {
        id: settleAnim
        target: root
        property: "scrollOffset"
        duration: (MotionTokens.reducedMotion ? 0 : 260) * debugTimeScale
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: driveAnim
        target: root
        property: "scrollOffset"
        duration: (MotionTokens.reducedMotion ? 0 : 80) * debugTimeScale
        easing.type: Easing.OutQuint
    }

    SequentialAnimation {
        id: bounceAnim
        NumberAnimation {
            id: bounceOut
            target: root
            property: "scrollOffset"
            duration: (MotionTokens.reducedMotion ? 0 : 160) * debugTimeScale
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: bounceBack
            target: root
            property: "scrollOffset"
            duration: (MotionTokens.reducedMotion ? 0 : 260) * debugTimeScale
            easing.type: Easing.InOutCubic
        }
    }

    WheelHandler {
        id: scrollWheel
        objectName: "windowHintScrollWheel"
        orientation: Qt.Vertical
        target: null
        blocking: false
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: wheel => {
            let delta = wheel.pixelDelta.y
            if (delta === 0)
                delta = wheel.angleDelta.y / 120 * 40
            if (delta === 0)
                return
            root.applyWheel(wheel.angleDelta.y < 0 || wheel.pixelDelta.y < 0,
                Math.abs(delta))
        }
    }

    // One wheel step, `magnitude` in pixels and `scrollingDown` naming the direction.
    // Split out of `onWheel` so the scroll contract is a FUNCTION the suite can call: a
    // `WheelHandler` can only be exercised by synthesising real pointer events, which a
    // QtTest harness cannot do, and a scroll nobody had ever run would be a scroll nobody
    // had ever seen either. The split is where the EVENT ends and the SCROLL begins.
    //
    // The magnitude is unsigned and the direction is the flag, rather than passing the
    // wheel's own signed delta through: a wheel's `pixelDelta.y` is negative when
    // scrolling down, so a caller that read "down" from the flag and passed a positive
    // number would scroll the other way and the mismatch would read as the component
    // being wrong. One unit here - the flag says which way, the number says how far.
    function applyWheel(scrollingDown, magnitude) {
        {
            const delta = scrollingDown ? -magnitude : magnitude
            // A crossing replaces the list under the pointer, and a wheel arriving
            // mid-traverse would scroll a column that is on its way out.
            if (!root.interactive)
                return
            // Nothing to scroll: a workspace whose windows all fit must not swallow the
            // wheel, because the wheel belongs to whatever is behind the popup.
            if (root.maxScrollOffset <= 0)
                return
            const maximumY = root.maxScrollOffset
            const nearBottom = scrollingDown
                && maximumY - root.scrollOffset <= root.edgeTakeoverDistance
            const nearTop = !scrollingDown && root.scrollOffset <= root.edgeTakeoverDistance
            if (root.edgeDriving && !nearBottom && !nearTop)
                root._settleEdge()
            if (!MotionTokens.reducedMotion && (nearBottom || nearTop)) {
                // Take over before the bound: chase the delta with a short ease, damped
                // deeper into the overscroll band so the pull tightens toward the end.
                edgeDriving = true
                edgeSettleTimer.restart()
                settleAnim.stop()
                let proposed = root.scrollOffset - delta
                if (proposed < 0)
                    proposed = root._resistedTarget(root.scrollOffset, delta, 0)
                else if (proposed > maximumY)
                    proposed = root._resistedTarget(root.scrollOffset, delta, maximumY)
                proposed = Math.max(-root.overscrollDistance,
                    Math.min(maximumY + root.overscrollDistance, proposed))
                driveAnim.from = root.scrollOffset
                driveAnim.to = proposed
                driveAnim.restart()
                return
            }
            if ((!scrollingDown && root.scrollOffset <= 0.5)
                    || (scrollingDown && root.scrollOffset >= maximumY - 0.5)) {
                bounceOut.from = root.scrollOffset
                bounceOut.to = Math.max(-root.overscrollDistance,
                    Math.min(maximumY + root.overscrollDistance, root.scrollOffset - delta))
                bounceBack.to = Math.max(0, Math.min(maximumY, bounceOut.to))
                bounceAnim.restart()
                return
            }
            root.scrollOffset = Math.max(-root.overscrollDistance,
                Math.min(maximumY + root.overscrollDistance, root.scrollOffset - delta))
        }
    }

    // Reveal a row: the smallest scroll that brings it inside the viewport. Called by
    // the body when the focused window changes, so the marker never points at a row
    // that is scrolled out of sight.
    //
    // Animated on the launcher's programmatic scroll (`scrollTo`): 300ms OutQuint.
    // Snapped rather than animated while a crossing is in flight or under reduced
    // motion - a moving target cannot be eased to, and the offset would arrive after
    // the column it belongs to.
    //
    // A REQUEST, not a one-shot, and that is the whole of why a long list could not be
    // scrolled to its focused row. The range the row has to fit into is still being
    // MEASURED on the frame this is asked for - a column's height is the running sum of its
    // slots, so it grows while they open - and the first answer is a number computed
    // against a list that has not finished existing. Measured on a twelve-window workspace
    // focused on the twelfth row: the reveal was requested at a range of 0 (and dropped,
    // because it had nowhere to go), then at a range of 4, and it ran to 4 while the
    // focused card sat 200 pixels below the panel's bottom edge. The panel looked as though
    // it could not scroll at all, and the wheel was the only thing that moved it.
    //
    // So the index is remembered and `_applyReveal` is what runs it, from here and from
    // `onMaxScrollOffsetChanged` - which fires on every frame the range grows. Nothing
    // polls, and the request is spent the moment the offset reaches a target computed
    // against the range as it finally stands.
    function revealRow(index, animated) {
        if (index < 0)
            return
        root._revealIndex = index
        root._revealAnimated = animated
        root._revealTarget = -1
        root._applyReveal()
    }

    // The row the list owes a scroll to, and whether that scroll may be eased. Kept as a
    // REQUEST for as long as the range it has to fit into is still being measured - see
    // `revealRow`.
    property int _revealIndex: -1
    property bool _revealAnimated: false
    // The target last written, so a range that keeps growing does not re-run the same
    // reveal on every frame of a transition: only a target that has actually moved is a
    // scroll worth making.
    property real _revealTarget: -1

    // Run the outstanding reveal against the range as it stands NOW. Idempotent, so the
    // range hook can call it on every frame of a transition.
    function _applyReveal() {
        if (root._revealIndex < 0 || root.maxScrollOffset <= 0)
            return
        const target = HintLogic.revealScrollY(root.scrollOffset,
            root._revealIndex * root.rowPitch - root.rowLiftFor(root._revealIndex),
            root.rowHeight, root.viewportHeight, root.maxScrollOffset)
        if (Math.abs(target - root._revealTarget) < 0.5
                && Math.abs(target - root.scrollOffset) < 0.5) {
            // Already where this reveal wanted to be: the request is spent.
            root._revealIndex = -1
            return
        }
        root._revealTarget = target
        if (!root._revealAnimated || MotionTokens.reducedMotion || !root.interactive) {
            revealAnim.stop()
            root.scrollOffset = target
            return
        }
        if (revealAnim.running && Math.abs(revealAnim.to - target) < 0.5)
            return
        root._cancelEdge()
        revealAnim.from = root.scrollOffset
        revealAnim.to = target
        revealAnim.duration = 300 * root.debugTimeScale
        revealAnim.restart()
    }

    NumberAnimation {
        id: revealAnim
        target: root
        property: "scrollOffset"
        easing.type: Easing.OutQuint
        onFinished: root._revealIndex = -1
    }

}
