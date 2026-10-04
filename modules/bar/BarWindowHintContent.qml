import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic

// Body of the mod-key window hint: a strip of the workspaces around the one you
// are on. Rendered inside the bar's popup, so it reuses the popup's surface
// colors, section fill and shared reveal instead of owning a surface of its own.
//
// A workspace switch is a WHOLE-BODY displacement: the crossing travels by exactly
// as many workspaces as the user moved, once, without turning back, and it carries
// BOTH frames with it. The panel is a three-column window onto the strip; the strip
// is `span + 3` columns wide, so while it travels there is always a full panel's
// worth of it under the window and the panel is never less than covered.
//
// Why one strip and not two copies crossing. The panel is a three-column frame of
// CONSECUTIVE workspaces, so the frame being left and the frame arriving share
// two of their three columns. Two copies sliding past each other therefore put a
// shared workspace on screen twice - the same window titles, once as the card
// column of the frame being left and once as a neighbour column of the frame
// arriving. Measured with a probe sampling which titles were inside the panel
// every 40ms across a whole crossing: 22 of 24 samples forward, 22 of 24
// backward, 85 double-painted titles in 72 samples. The user reads that as
// duplicated window-title cards.
//
// One strip cannot have the fault, and the reason is structural rather than
// arithmetic: the strip holds each position exactly once, so there is only one
// place a title could be painted from. See `WindowHintMenuLogic.stripPlan` for the
// geometry and `stripColumns` for the ordering - both live there so this component
// and its suite read one rule rather than two.
//
// Only the arriving copy's content carries the focus highlight and the indicator.
// Focus belongs to the workspace you are moving to, and a marker on a column
// still on its way out would blink a second time for a workspace you have already
// left. Both are placed against the arriving column's own geometry - read through
// the same layout function the column itself uses - so the marker and the row it
// marks cross together AND change width together, at every instant of the
// crossing rather than only at its ends.
//
// THE ACTIVE COLUMN IS TWICE AS WIDE AS EITHER NEIGHBOUR, and that is what the
// crossing is drawn with. The workspace you are ON is the one whose windows you
// opened the panel to choose from, so it gets the room; the neighbours are context
// for it. The band is the wide middle slot and never moves, and the two columns
// either side of it trade places through it - one narrowing on the way out, one
// widening on the way in - because both are one layout function evaluated at two
// points along a single workspace's travel. See `HintLogic.slotX`.
Item {
    id: root

    // The live snapshot from WindowHintService, replaced wholesale on every
    // refresh, so each binding below re-evaluates on a workspace switch.
    property var hint: null
    signal windowActivated(string windowId)

    // What is painted: the strip, one column per workspace position, in order.
    // Replaced at the START of a slide, not at the end - the frame being left is
    // the one being held, and the panel is sized from what is arriving so a width
    // change is masked by the arriving content still being off-panel.
    property var columns: []
    // The frame the strip is leaving, held for the length of one slide. Needed
    // because the arriving snapshot only describes the three workspaces around the
    // workspace being moved TO: the column for the workspace being left is in
    // neither of the arriving snapshot's own three, and inventing an empty column
    // for it would report "no windows" about a workspace that has some. A depth-1
    // hold is the whole of it: the launcher's display pool solves the same problem
    // for a list that refills on every keystroke, which is not what a hold-to-see
    // popup does.
    property var leavingHint: null
    property bool shownReady: false
    // +1 when the workspace moved later in the list, -1 earlier, 0 unknown. It
    // steers the strip's direction, not a transform: see the plan.
    property int swapDirection: 0
    // 0 while a slide is in flight, 1 at rest. The one clock the whole motion runs
    // on: the strip's offset is a pure function of it, so there is no second
    // animation to fall out of step.
    // ---- OBSERVATION SLOW-MOTION -------------------------------------------
    // Every duration on the focus marker's path is multiplied by this, so the sequence
    // can be watched rather than inferred. 6 is slow enough to see a card light up in
    // the same frame its frame lands, rather than after it.
    //
    // It is a WRITABLE property, not a constant, for one reason: the suite waits in
    // wall-clock time, so a slowed build turns every timing assertion red and makes a
    // diagnostic nobody can run. `tst_window_hint_content`'s `init()` sets this back to
    // 1, so the tests always measure the real recipes and the live shell is the only
    // thing that is slow. Set it to 1 to get normal motion back.
    property real debugTimeScale: 6

    property real slideProgress: 1
    // A crossing is under way. A FLAG, not `slideProgress < 1`.
    //
    // The clock reaches 1 on the animation's last tick, a frame or two before
    // `onFinished` narrows the strip back to the arriving frame's three columns. So
    // `slideProgress < 1` goes false while the strip is still mid-narrow - and the
    // markers, which choose between their resting and crossing placement on this flag,
    // would change regime against a strip that had not finished moving.
    property bool swapping: false

    // The geometry of the crossing in flight, from `HintLogic.stripPlan`, or null
    // at rest. The strip's own offset, the number of columns it is drawn with and
    // the slot the active workspace occupies are all read off this one record, so
    // the three cannot describe different crossings.
    property var plan: null

    readonly property bool ready: root.shownReady
    // Two column widths, because there are two sizes. A neighbour's is the panel's
    // unit; the active workspace's is twice it, which is the only asymmetry in the
    // panel - see `WindowHintMenuLogic.ACTIVE_COLUMN_SCALE` for why it is there.
    //
    // Neither varies with the content: the active workspace sits in the middle, and
    // it can only stay in the middle if the frame around it is the same size whatever
    // the neighbours are running. It also means the panel does not resize under the
    // pointer as the user moves between an interior workspace and an edge one.
    readonly property int columnWidth: HintLogic.COLUMN_WIDTH
    readonly property int activeColumnWidth: HintLogic.ACTIVE_COLUMN_WIDTH
    // Gap between the three columns, and the pitch two NEIGHBOUR-width columns
    // produce. `inlineGap` is the bar's workspace widget's own spacing between its
    // squares - see `BarWindowHintStrip.columnGutter` for why the panel needs one.
    readonly property int columnGutter: LazerTheme.inlineGap
    readonly property int narrowPitch: columnWidth + columnGutter
    // The panel's own width: a neighbour, a gutter, the wide middle column, a
    // gutter, a neighbour. Computed by the same function the strip's layout is
    // measured against, so the band below - which spans that middle column - cannot
    // land one gutter out from the right edge while its left edge is exactly
    // `bandInset` from the left.
    readonly property int panelWidth: HintLogic.panelWidth(
        columnWidth, activeColumnWidth, columnGutter)
    // Margins, each lifted from the widget rather than chosen here:
    //
    //   band   -> panel edge   `LazerTheme.barWidgetGutter`   3
    //   card   -> band, above  (barWidgetHeight 42 - the widget's 18px content
    //             and below    row) / 2                        12
    //   card   -> band, sides  `cardClearance` * 2 + the indicator's width  19
    //
    // The two card margins are different numbers because the widget's are: its square
    // is `contentRow.implicitWidth + cellPadding * 2` wide, so 8 a side, while its
    // height is a fixed `barWidgetHeight` with the content row centred in it, which
    // leaves 12 above and below. Using 8 on all four sides - which is what this had -
    // read as the cards crowding the band, and it is most visible vertically because
    // the band here is full-height and the widget's is a fixed-height bar row.
    //
    // The horizontal one is no longer 8, because the focus indicator lives in it. It
    // is a mark OUTSIDE the card - `Workspaces.qml` has its indicator outside the
    // marked square - so the padding holds the clearance, the bar and the clearance
    // again, and all three are the same number so none of them can be quietly tighter
    // than the others. See `cardClearance`.
    //
    // `surfaceInset` is how far the popup's own content column is inset from its
    // surface; `BarPopupActions` declares it. The band has to reach past it to get to
    // `bandInset` from the edge, which is why that reach is a negative offset here
    // rather than a padding on the body.
    // `Workspaces.cellPadding`, the widget's own gap between an icon and its square's
    // edge. It is the panel's card padding, the indicator's clearance from the band and
    // the indicator's clearance from the card - one number, because one number is what
    // stops any of the three from drifting tighter than the others.
    readonly property int cardClearance: 8
    readonly property int cellPaddingX: cardClearance * 2 + indicatorThickness
    readonly property int cellPaddingY: 12
    readonly property int bandInset: LazerTheme.barWidgetGutter
    property int surfaceInset: 0
    // What the band reaches out past the body's own edges to sit `bandInset` from the
    // surface. Zero when the host declares no inset.
    readonly property int bandOutset: Math.max(0, surfaceInset - bandInset)
    // The panel's middle column, as a coordinate. The active workspace's column is ALWAYS
    // the middle one - the crossing runs precisely so that the arriving active column
    // lands there - so this is where that column's left edge is, whatever the crossing
    // is doing. Kept as a named number because the panel's own geometry is arithmetic
    // that several places reason about and none of them should be repeating it.
    //
    // It used to also be the x of a full-height `activeFill` rectangle behind the column
    // - the workspace widget's `activeHighlight` cell, magnified. That is gone: see the
    // note where the band used to be.
    readonly property real bandX: narrowPitch
    readonly property int shownColumnCount: HintLogic.COLUMN_COUNT
    // The two ends of the crossing as WORKSPACE POSITIONS, and the position in
    // between - which is the whole animation.
    //
    // Every column on the strip places itself from `panelPosition`: `slotX` and
    // `slotWidth` ask how far it is from the workspace the panel is centred on. So
    // one number running from the workspace being left to the one being moved to
    // slides the arriving column in AND widens it, narrows the one being left as it
    // goes, and carries the focus markers - they are placed from the same function.
    // There is no second clock and no transform: the width change is not an effect
    // layered on the slide, it IS the slide.
    //
    // Positions rather than pixels is the load-bearing part. The strip used to travel
    // by `span * columnPitch` with every column at a uniform pitch, and a switch
    // landing mid-crossing had to correct that pixel offset by hand (`stripReshift`),
    // because the new plan renumbered the strip's slots and the offset had to give
    // back exactly what the renumbering took. Here there are no slots to renumber and
    // no offset to convert: continuing from wherever the crossing had reached is a
    // matter of handing `positionFrom` that value. See `_reaimSlide`.
    property real positionFrom: 0
    property real positionTo: 0
    readonly property real panelPosition: positionFrom
        + (positionTo - positionFrom) * slideProgress
    // The crossing runs on the WORKSPACE WIDGET'S ACTIVE-HIGHLIGHT CURVE: one ease,
    // `Easing.OutQuad` over `medium`. That is the recipe `Workspaces.qml`'s
    // `activeHighlight` slides on, and it is the right reference twice over - this
    // panel is a magnified view of that widget's three columns, and the highlight the
    // strip now carries for its active column is the same surface the widget slides,
    // so the list and the highlight must arrive together or they read as two things
    // happening at once.
    //
    // Before this it was two phases, a departure and a settle, borrowing the
    // workspace INDICATOR's two-speed shape. That shape does not transplant: the
    // indicator's head and tail are two positions running in PARALLEL with a drawn
    // bar stretched between them, so fast and slow cost nothing. A crossing has one
    // position, so the phases had to run in sequence, and the handover between them
    // read as two paragraphs of motion. Then it was the launcher's focus curve,
    // which was smooth but belonged to a different component and moved at a
    // different weight.
    //
    // The duration is deliberately NOT a function of the span: a three-column jump
    // covers the same 160ms and arrives three times as fast, which is what a fixed
    // settle rhythm means, and what stops a run of taps from feeling like a queue.
    readonly property int slideDuration: MotionTokens.medium
    // The crossing's own recipe, so a suite can assert the curve rather than the
    // tokens it was written from - a test that reads `MotionTokens.slow` instead
    // checks that a number exists somewhere in the file, not that the animation runs
    // on it, which is exactly the mistake a retune of this file would reintroduce.
    readonly property alias slideAnimation: slideRun
    // The marker's own clock, exposed for the same reason `slideAnimation` is: a suite
    // can assert the duration and the curve rather than re-reading the tokens they were
    // written from. The two clocks are asserted to DIFFER, because the whole effect
    // depends on the marker outliving the columns.
    readonly property alias crossingAnimation: crossingRun
    readonly property alias indicatorHeadMotion: indicatorHeadAnimation
    readonly property alias indicatorTailMotion: indicatorTailAnimation
    readonly property int rowHeight: 28
    // The one row the focus indicator belongs to, or -1. Read from the ARRIVING
    // active column, which is the content the user is being taken to.
    readonly property var activeColumn: root.plan
        ? root.columns[root.plan.activeSlot] : null
    readonly property int focusedRowIndex: HintLogic.focusedIndexIn(
        root.activeColumn ? root.activeColumn.rows : null)
    // The indicator, outside the card. `Workspaces.qml` puts its indicator outside the
    // marked square - below it, in the bar's own gap - and this panel had it the other
    // way round: 4px in from the card's left edge, between the card's edge and its
    // icon, with the icon carrying a 19px inset whose only purpose was to make room.
    //
    // Its clearance is `cardClearance` on BOTH sides, which is the whole point: the
    // widget's marker sits one card-padding from its band, and a marker centring
    // itself in whatever padding happened to be left over is a marker that reads as
    // too close the moment any of the three numbers moves. One number, three gaps.
    //
    // It cannot drift off-centre either: `cellPaddingX` is this clearance twice plus
    // `indicatorThickness`, so the two gaps are equal by construction rather than by a
    // centring expression that has to be kept in step.
    readonly property int indicatorThickness: LazerTheme.barIndicatorHeight
    readonly property int indicatorInset: cardClearance
    // A row's glyph inset, shared by the icon and the title so both start on the
    // same x - and shared by the ACTIVE column and its two neighbours, which read
    // the same property, so the three columns' icons stay on one line.
    //
    // No longer derived from the indicator. It was `indicatorInset +
    // indicatorThickness + indicatorGutter` - 19px - purely to leave the marker a
    // gutter inside the card, and with the marker outside that whole chain is dead
    // weight that would read as an arbitrary indent. It is `cardClearance` now, the
    // same padding the card's own edge gets and the marker gets.
    readonly property int glyphInset: cardClearance
    readonly property int glyphWidth: 16
    // Vertical pitch of the list: a row plus the Column's gap. The indicator is
    // positioned from this, so it has to agree with the Column's own spacing
    // exactly - asserted against a real row's bottom edge in the suite.
    readonly property int rowPitch: rowHeight + listSpacing
    readonly property int listSpacing: 6
    // How many rows the active column shows at once. A VIEWPORT, not a cap: the column
    // scrolls, so every window is reachable and nothing is summarised away. The strip
    // owns the number and the body reads it, so the panel's height and the column's
    // clip cannot be two different viewports.
    readonly property int viewportRows: HintLogic.MAX_WINDOW_ROWS
    readonly property int viewportHeight: Math.max(0,
        viewportRows * rowPitch - listSpacing)
    // Top edge of the focused row, 0 when there is none. One source of truth for
    // both markers below, so the frame and the indicator can never disagree about
    // which row is current.
    // Top edge of the focused row, in the strip's space. The cards start at the
    // strip's own top - the band is what sits a padding above them, not the cards -
    // so this carries no padding term. It did, briefly, and put the row highlight a
    // whole padding below the card it is drawn over.
    // The focused row's top edge in the STRIP's own coordinates - which is a SCROLLED
    // space, because the active column's `y` is its negative scroll offset. So the
    // offset is part of where the row is, not an adjustment applied to the marker: a
    // marker placed at `index * rowPitch` would sit at the row's unscrolled position and
    // point at the wrong window the moment the column had been scrolled.
    // Where there is no focused row the marker is placed wholly ABOVE the panel, and
    // that is the whole of how "no row" is expressed.
    //
    // It used to be 0, which is the FIRST card's top edge - a perfectly real coordinate
    // naming a row that is not there, and the root of two separate faults. A bar
    // appearing in an empty workspace, because the marker was at the first card's
    // position with only its opacity standing between it and the screen; and a flicker on
    // every switch, because a visibility flag cannot survive a snapshot that arrives
    // mid-crossing with no windows in it yet - which is what niri sends while a workspace
    // is still coming up. Each of those snapshots was a real flip of that flag, and a flip
    // of a flag the eye can see IS a flicker.
    //
    // A position cannot flicker. A snapshot with no windows puts the marker off the top
    // edge, where the next snapshot with windows brings it down onto the card: an arrival
    // rather than a blink.
    readonly property real noRowTop: _offTop
    readonly property real focusedRowTop: focusedRowIndex < 0 ? noRowTop
        : focusedRowIndex * rowPitch - strip.scrollOffset
    // The leaving frame's own height, from the row counts of the frame being held
    // rather than from a second strip. A crossing's strip is as tall as the tallest
    // of the two frames already, so this only matters for the instant between a
    // snapshot arriving and the strip's delegates having laid out - where reading
    // `strip.contentHeight` would report the new frame's height and size the panel
    // to it for a frame, clipping the leaving frame's bottom rows.
    //
    // The row pitch rather than a delegate, so it is available before any layout
    // has polished.
    readonly property int _outgoingHeight: {
        if (!root.leavingHint || !root.swapping)
            return 0
        const rows = HintLogic.cappedRows(root.leavingHint.windows).rows
        // Clamped to the viewport, like `strip.contentHeight`. The leaving frame is held
        // for the length of a crossing, and a twelve-window workspace would otherwise
        // size the panel to twelve rows for exactly as long - a visible jump out of the
        // viewport and back.
        return Math.min(rows.length * root.rowPitch - root.listSpacing,
            root.viewportHeight)
    }

    // --- indicator: the workspace widget's dual-speed edge tracker, rotated ---
    // The workspace indicator is `barWidgetHeight - 16` long and `barIndicatorHeight`
    // thick - 26x3 on a 48px bar - and its head/tail stretch lengthens it along its
    // own long axis so it stays a bar. This list runs down a column, so the indicator
    // is that same bar turned 90 degrees: 3 wide, and the same length.
    //
    // It was 16 here, on a comment that also claimed the widget's bar was 16 -
    // `Workspaces.indicatorBarWidth` is `barWidgetHeight - 16`, which is 26. So the
    // bar was not the widget's bar at 90 degrees but a different, shorter one, and
    // the eye already knows the real length from the bar at the top of the screen.
    // The row is `rowHeight` tall and the length fits inside it, which the widget's
    // also does inside its square.
    //
    // Stretching the WRONG axis would have turned a 3px bar into a tall rectangle
    // mid-flight, which is a shape change rather than a bar growing.
    readonly property int indicatorLength: LazerTheme.barWidgetHeight - 16

    property real _headY: 0
    property real _tailY: 0
    property bool _snapping: false
    // Committed target, never animated. Dedupe and same-anchor drift read this,
    // because _headY is the Behavior's in-flight frame and is numerically equal to
    // _tailY until the first tick, which would make a same-frame switch look
    // settled and teleport the bar.
    property real _anchorY: 0
    property bool _placed: false
    // Same-anchor drift arriving while a trail is in flight; applied as one snap
    // once the tail catches up, so a trail is never cut short.
    property real _pendingTop: -1
    property string _targetKey: ""

    // Left edge of the drawn bar, and the head/tail target, both derived the same
    // way the workspace widget derives them: the target is the row's centre minus
    // half the bar's resting length, so at rest the bar sits centred. A function,
    // not just a binding, because the change handlers below must be able to ask
    // for a target from the index that just changed - see _syncIndicator.
    function _targetYFor(index) {
        return index * rowPitch + rowHeight / 2 - indicatorLength / 2
    }

    // --- the crossing displacement ---------------------------------------
    // On a workspace switch ONE instance of the row marker travels the whole height of
    // the panel, in the direction the list is going. To the workspace below: it leaves
    // the focused card of the workspace being left by sliding DOWN, is gone once the clip
    // has taken it below the bottom edge, comes back in through the TOP and slides down
    // onto the focused card of the one being moved to. To the workspace above, all four
    // of those are mirrored - up out of the top, back in through the bottom, up onto the
    // card.
    //
    // The rule underneath is the reference being followed: the old superisland window
    // hint's title-card focus rectangle displaced onto the focused card along the axis the
    // move was going, never across it. One exit edge and the opposite entry edge mean the
    // journey reads as one continuous sweep, so the direction of the switch is carried by
    // the marker AND by the content - rather than the marker contradicting the content by
    // always travelling the same way.
    //
    // (That reference is a horizontal capsule row and this is a vertical card column, so
    // there was no code to port - only the rule, which is the part that mattered.)
    //
    // ONE instance for the whole journey, corner included. It was two elements - a
    // resting one and a crossing-only twin, each hidden while the other showed - because
    // `focusFrame.y` carries a `Behavior` for the focus glide, and a property that is both
    // behaviour-animated and a pure function of a clock is a race whose winner came down
    // to the order QML evaluated them in. One instance with two placements per leg
    // removes the race outright, and it is also what the effect is FOR: a single
    // rectangle travelling is the gesture, and two rectangles taking turns is a cut.
    //
    // The crossing and resting placements are chosen by a flag rather than by
    // `crossingClock < 1`, because they agree on the landing frame - the clock is 1, so
    // `crossingTop` IS `focusedRowTop` - so flipping the flag changes nothing and there is
    // no frame on which the two expressions could disagree.
    //
    // Everything below is in STRIP coordinates, so the strip's own `y` - the padding
    // between the panel's top edge and the card block - is already applied.
    readonly property real _stripY: bandInset - surfaceInset + cellPaddingY
    // The panel's top edge in those coordinates, and a whole card above it: where the
    // marker starts. Wholly outside, so it slides IN rather than already being on screen
    // at the edge.
    // The DEPARTURE leg: the card the marker leaves from, and the point it leaves at.
    //
    // The departure leaves by the EDGE THE SWITCH IS HEADED FOR. Moving to the workspace
    // below, the focus drains out of the BOTTOM; moving to the workspace above, it rises
    // out of the TOP. The arrival comes back in through the OPPOSITE edge and travels the
    // same way as the departure, so each switch is one continuous sweep in the direction
    // the list is going rather than a marker that changes its mind about which way is up.
    //
    // So the exit side and the entry side are not two independent choices: one number
    // fixes both, and the gesture is always "out of one edge and back in through the
    // other". That is what the workspace widget's own indicator does when it travels
    // between workspaces, at a fifth the size.
    //
    // Which card it leaves is the DEPARTING frame's own focused row, not the arriving
    // one's: `focusedRowIndex` is read off the arriving column and is already the new
    // workspace's by the time anything here runs. Taken from the held frame's windows
    // rather than from `focusedRowIndex` sampled at that instant, because a binding's
    // value while its own inputs are being reassigned is not a thing to depend on.
    property int _departingRowIndex: -1
    // How far the departing column was scrolled when the switch was published, captured
    // because the value is gone by the time anything else could read it.
    //
    // The panel scrolls the ACTIVE column to keep the focused card on screen, so a
    // workspace whose focus is below the fifth row has its focused card drawn up inside
    // the viewport. During the crossing that column is a NEIGHBOUR slot, which does not
    // scroll, so the same card is drawn at its unscrolled position - tens of pixels below
    // the panel. The departure therefore has to start from where the card WAS, which is
    // the only place the user ever saw it, and that is this offset subtracted.
    property real _departingScroll: 0
    // The two positions that are wholly outside the clip: a whole card past each edge.
    // Wholly, so the marker really does disappear rather than parking on the first or
    // last row.
    readonly property real _offTop: -_stripY - rowHeight
    readonly property real _offBottom: root.height - _stripY + rowHeight
    // Which way this journey runs. A switch to the workspace BELOW leaves downward and
    // arrives from the top; a switch to the workspace ABOVE rises out of the top and
    // arrives from the bottom.
    //
    // Captured rather than read from `plan`, and deliberately NOT recaptured by a re-aim.
    // The marker has already left by the time a second switch can arrive, so reversing
    // the sign then would bend its path mid-flight - out of the bottom and back in from
    // the top is still one sweep, whereas a bend is neither. The re-aim's own direction
    // governs the columns, which is what it is for.
    property int _journeyDirection: 1
    readonly property bool _journeyUp: root._journeyDirection < 0
    // The point the departure leaves at, and the point the arrival enters from: the two
    // off-panel positions, in the order this journey runs through them.
    readonly property real exitTo: _journeyUp ? _offTop : _offBottom
    // A frame with nothing focused has no card to leave from, so the departure leg is
    // given zero length - the marker starts already off the bottom and the panel shows
    // the arrival alone. Degenerate rather than special-cased.
    readonly property real exitFrom: _departingRowIndex < 0 ? exitTo
        : _departingRowIndex * rowPitch - _departingScroll
    // The arrival's own start - the edge OPPOSITE the one the departure left by, for
    // the reason given above.
    readonly property real crossingFrom: _journeyUp ? _offBottom : _offTop
    // Where the arrival lands: the focused card's own top edge, in the SCROLLED space
    // that `focusedRowTop` is measured in.
    //
    // With nothing focused on the arriving side there is no card to land on, and
    // `focusedRowTop` answers "no row" with 0 - which is the FIRST card's top edge, a
    // perfectly real coordinate naming a row that is not there. Folding the arrival's
    // end back onto its start makes the leg degenerate instead: the marker stays above
    // the panel for the whole of it rather than descending onto the first card of an
    // empty column.
    // Degenerate rather than landing on the first card of a column with nothing in it.
    // Both ends of that leg are off the panel on this journey's own side, so the marker
    // is out of sight for the whole of it.
    readonly property real crossingTo: hasTarget ? focusedRowTop : crossingFrom

    // The marker traverses the panel in ONE clock, in two legs: down and out through
    // the bottom, then in through the top and down onto the card. The corner between
    // them is the midpoint, and at the midpoint the marker is wholly outside the clip
    // on both counts - so the discontinuity in its position is never on screen. That is
    // what lets one element do both halves, and one element is the whole effect: a
    // single rectangle travelling is the gesture, and two rectangles taking turns is a
    // cut.
    property real crossingClock: 0
    // A crossing marker is under way - which is to say, either leg of the journey is.
    // A FLAG rather than `crossingClock < 1`, and deliberately its own flag rather than
    // the strip's `swapping`: the two clocks end 160ms apart, so the strip's is already
    // false while the marker is still descending. It is also the only thing that clears
    // it - `_commitHint` on a commit that never showed the marker travelling, and this
    // animation's `onFinished` otherwise - which is why a cancelled crossing has to
    // reach one of those rather than simply being abandoned.
    property bool _markerCrossing: false
    // Does the snapshot now in hand belong to the journey that is under way? Both terms
    // are load-bearing, and the second is the one that was missing.
    //
    // `_markerCrossing` says a journey is placing the frame, and it outlives the strip's
    // own clock by `MotionTokens.page - MotionTokens.medium`, so a snapshot arriving in
    // that window is part of the journey and must not commit over it.
    //
    // `plan.activePosition` says which workspace that journey is arriving at, and it is
    // what makes the question answerable: a snapshot reporting no movement names the
    // workspace the previous one named, so during a journey it is naming the destination
    // - and a snapshot naming anything else is a different frame, which has to be
    // committed whatever the marker's clock is still doing. See the note at the branch.
    //
    // A FUNCTION, and the reason is the whole of it. Written as a `readonly property`
    // with `&&` it was a lazily evaluated binding, and QML tracks dependencies only for
    // the operands a `&&` actually reached: every evaluation made while
    // `_markerCrossing` was false returned without ever reading `plan` or `hint`, so the
    // binding held no dependency on either, and the next thing to dirty it was
    // `_markerCrossing` going true - at which point it compared the new plan against
    // whatever `hint` had been when it was last genuinely read. Measured: a snapshot for
    // workspace 1 arriving while a journey was arriving at 3 was answered "yes, it
    // joins", out of a cached `3 === 3`. That is the same hazard the indicator's own
    // tracker was rebuilt to avoid - a derived value read back before its inputs have
    // been recomputed - and this is a function precisely because a function has no
    // remembered value to read back.
    function _joinsMarkerJourney() {
        if (!root._markerCrossing || !root.plan)
            return false
        return root.plan.activePosition === root.hint.activeWorkspacePosition
    }
    // The leg currently in progress, and how far through it. `InOutQuad` is at its
    // fastest exactly here, so the marker leaves through one edge at speed and re-enters
    // through the other at the same speed: one continuous sweep rather than two stops.
    readonly property bool _onExitLeg: crossingClock < 0.5
    readonly property real legProgress: _onExitLeg
        ? crossingClock * 2 : (crossingClock - 0.5) * 2
    // Where the departure starts on a re-aim, captured. A second switch landing mid-
    // crossing restarts `crossingClock` at 0, which would put the marker back on the
    // card it had already left - so the new leg carries on from where the old one had
    // reached. Only ever needed on the DEPARTURE leg: a re-aim needs the strip's own
    // 160ms clock still running, and that is the first half of this one.
    property real _exitFrom: 0
    readonly property real crossingTop: _onExitLeg
        ? _exitFrom + (exitTo - _exitFrom) * legProgress
        : crossingFrom + (crossingTo - crossingFrom) * legProgress

    // The card the marker is on, read LIVE from the strip rather than interpolated. The
    // departing column slides sideways while the marker leaves it, and the strip's own
    // placement runs on a different curve from the marker's - so a lerp here would drift
    // off the card within a few frames, which is worse than the extra machinery of not
    // interpolating at all.
    readonly property real _leavingPosition: root.leavingHint
        ? root.leavingHint.activeWorkspacePosition : strip.activePosition
    readonly property real markerLeft: _onExitLeg
        ? strip.columnXFor(_leavingPosition) + cellPaddingX
        : strip.activeColumnX + cellPaddingX
    readonly property real markerWidth: Math.max(0, (_onExitLeg
        ? strip.columnWidthFor(_leavingPosition)
        : strip.activeColumnWidthNow) - cellPaddingX * 2)
    // Whether there is a row to mark anywhere in the journey. The departure marks the
    // card being left, which the arriving frame knows nothing about, so an empty arriving
    // workspace must not make the departure invisible - and with "no row" now expressed as
    // an off-panel position rather than as this flag, the arrival leg of such a crossing
    // is already out of sight. That is what lets this be the simple OR it used to be:
    // nothing has to consult the leg, and nothing can flicker on the way through.
    readonly property bool markerHasTarget: hasTarget || _departingRowIndex >= 0
    // The bar is the same gesture one `markerOffset` lower at every point of it: at rest
    // it is a bar centred on its card, so the offset that puts it there is the offset it
    // travels with, on both legs. One formula, one offset, two elements that cannot
    // drift apart.
    readonly property real markerOffset: rowHeight / 2 - indicatorLength / 2
    // --- the row's focus tint, fed from the frame's own rectangle ---------
    // The frame's rect in the strip's space, and whether it has stopped moving. The
    // strip runs the focused card's tint off the first and gates the row's
    // `Behavior on color` on the second, and the body owns both because `focusFrame` is
    // DECLARED here while being a child of the strip - an id is file-scoped, so the strip
    // cannot name it and has to be handed the numbers.
    //
    // Plain properties rather than a reference to the element, and numbers rather than a
    // decision, because the point is that nothing in between decides anything. The tint
    // was `focusedRowIndex` - read off the ARRIVING snapshot, so correct from the
    // crossing's first frame, which lit the arriving card while the frame was still
    // above the panel and gave the answer away before the gesture delivered it. It was
    // then a flag: `markerOnFocusedRow`, a renamed `!_markerCrossing`, which held the
    // tint off for a whole journey and switched it on at the landing. A flag can only be
    // right on the frames something writes it on, so it is either too early or too late
    // everywhere else, and the case it cannot see at all is the common one - a focus
    // change inside a single workspace, where nothing writes a flag and the frame glides.
    //
    // The frame's live rectangle is the mask, so the tint is that rectangle made visible:
    // a card is lit on every frame the frame's band overlaps it, including the frame it
    // is first touched and including the cards the band sweeps over on the way. Which is
    // what the user asked for - the region the frame encloses changes colour, as the
    // frame is over it - and it is the one rule that needs no cases.
    // The frame's rectangle, handed down whole. Top and height alone were enough for as
    // long as the frame was only ever over the active column - see `focusFrameLeft`.
    property real focusFrameTop: 0
    property real focusFrameLeft: 0
    property real focusFrameHeight: 0
    // Has the frame ARRIVED: no journey placing it, and its own animated `y` sitting on
    // the row it is going to. The journey term is not redundant - a switch between two
    // workspaces whose focus is on the SAME row puts the frame back on that row's own
    // coordinates on the crossing's first frame, so the position alone would read a
    // travelling frame as a rested one.
    //
    // --- the slide -------------------------------------------------------
    // A workspace switch replaces every row, so without this the panel's contents
    // are simply gone and remade between two frames. Here the leaving frame is
    // held, the strip is rebuilt to carry both, and one clock drives it across.
    //
    // Reduced motion, a first snapshot, a change with no knowable direction (a
    // window title edit on the same workspace) and a move wider than the two
    // frames together all commit straight away: an un-aimed animation would be
    // motion for its own sake, and there is nothing to animate for a move whose
    // middle column no snapshot knows anything about.
    function _onHintChanged() {
        if (MotionTokens.reducedMotion || !root.shownReady) {
            root._lastFrame = root.hint
            return root._commitHint()
        }
        const direction = HintLogic.switchDirection(root.hint)
        // A snapshot reporting no movement must NEVER cancel a crossing that is
        // already under way.
        //
        // niri sends a second refresh about 40ms after the activation, because the
        // window list changes as the new workspace comes up. By then the service has
        // already advanced its record of the active workspace, so that snapshot
        // reports the SAME position on both sides and reads as "nothing moved".
        // Committing on it stopped every crossing a few frames in - which is why the
        // traverse's timing could be retuned three times over and never once looked
        // different, because none of it was ever on screen.
        //
        // The two cases are genuinely different. "No movement" alongside a crossing
        // means the new workspace's content, refreshed - not a denial of the move
        // the crossing is already showing. So the content is replaced under the
        // crossing and the crossing finishes on its own clock. With no crossing in
        // flight there is nothing to protect, and a title edit on the current
        // workspace commits straight away exactly as before.
        //
        // The test for "a crossing is in flight" is `_markerCrossing`, and it was
        // `swapping` - which is the STRIP's clock, and that clock ends
        // `MotionTokens.page - MotionTokens.medium` = 160ms (times `debugTimeScale`)
        // BEFORE the marker's. So for the last 160ms of every switch the guard read
        // false while the frame was still two thirds of the way down the panel, and a
        // refresh landing in that window took `_commitHint()`.
        //
        // Measured, at scale 1 with a refresh 220ms into a switch: `_markerCrossing`
        // dropped with `crossingClock` at 0.76, 0.78 and 0.82 across three runs - the
        // journey stopped with the frame in mid-air and it teleported the rest of the
        // way. At scale 6 with a refresh 1200ms in, the clock was at 0.71.
        //
        // The streak is the worse half, and it is why this was reported as the
        // indicator rather than as the frame. `_commitHint` clears `_markerCrossing`,
        // and that flag is the load-bearing term in BOTH of the tracker's Behaviors -
        // so a commit in the dead window handed the head and the tail their animations
        // back in the middle of a switch, and the refresh's own correction to the
        // focused row then ran as a full genuine streak. Measured peak: 37.6px at
        // scale 1 and 37.7px at scale 6, growing the drawn bar from `indicatorLength`
        // (26) to 64 - on a switch, whose whole design is that the frame IS the
        // motion and a stretch underneath it would be a second motion on one marker.
        //
        // And the length of that streak is not the switch's to decide: it is how far
        // the refresh's focused row is from the row the switch had already put the bar
        // on. So it is long when the refresh disagrees with the switch and it is
        // nothing at all when the refresh merely confirms it - which is exactly the
        // reported shape. Two switches at scale 6, each refreshed inside its own dead
        // window: 37.7px of streak after the first, 0px after the second, the bar
        // stretching to 83px and then to nothing.
        //
        // `_replaceArriving()` is the right destination in that window rather than a
        // special case, because by then the strip has already landed: `slideRun`'s
        // handler has released the held frame and put a REST plan in place, so
        // `stripColumns(hint, null, rest)` - which is what `_replaceArriving` computes
        // there - is the same three columns `_commitHint` would have built. The only
        // thing the commit added was stopping the marker's clock, which is the fault.
        //
        // Joined to the journey by the workspace it is arriving at rather than by
        // `_markerCrossing` alone, because that flag alone is not the same question. A
        // marker's clock can still be winding down while the panel has been handed a
        // DIFFERENT frame altogether - the panel re-shown with a fresh snapshot, or the
        // next workspace in a run - and that frame has to be committed, because
        // `_replaceArriving` re-seats only the columns and leaves `panelPosition` on the
        // journey it was already showing. Measured: re-seating the panel on workspace 1
        // while a crossing was still arriving at 2 left `positionFrom` and `positionTo`
        // both at 2, so the panel went on drawing three columns centred two workspaces
        // away from the frame it had just been given.
        //
        // The service cannot produce that case - a snapshot reporting no movement names
        // the workspace the previous one named, because `previousActiveWorkspacePosition`
        // is what makes it report movement at all - so this is about the flag meaning
        // what it says rather than about a case the shell can reach.
        if (direction === 0) {
            root._lastFrame = root.hint
            return root._joinsMarkerJourney() ? root._replaceArriving()
                : root._commitHint()
        }
        const plan = HintLogic.stripPlan(
            root.hint.previousActiveWorkspacePosition,
            root.hint.activeWorkspacePosition)
        // Too far to describe: the two frames' workspaces no longer form a
        // contiguous run, so a column would have to be invented. Commit.
        if (!plan) {
            root._lastFrame = root.hint
            return root._commitHint()
        }
        // The frame the strip is leaving is whichever one was on screen when this
        // publish arrived - the resting frame for a fresh switch, and the frame
        // mid-crossing is arriving at for a second switch. Latched before the
        // arrival overwrites it, or the strip loses the column for the workspace
        // being left.
        const leaving = root._lastFrame
        root._lastFrame = root.hint
        root.leavingHint = leaving
        root.swapDirection = plan.direction
        // Already sliding: re-aim the same crossing rather than starting a new one,
        // so the strip continues from where it is instead of jumping home.
        if (root.swapping)
            return root._reaimSlide(plan)
        root._startSlide(plan)
    }

    // The frame the panel was showing when the current publish arrived. The service
    // overwrites `previousActiveWorkspacePosition` as it builds, so the "position
    // being left" is only readable off the hint the panel was ALREADY showing.
    property var _lastFrame: null

    // Replace the panel's content outright, with no crossing. What is on screen
    // becomes what the snapshot says, in one step, and the strip is rebuilt at rest
    // so it is the arriving frame's own three columns with the active one in the
    // middle.
    function _commitHint() {
        slideRun.stop()
        root.slideProgress = 1
        root.leavingHint = null
        root.swapDirection = 0
        root.plan = null
        root.positionFrom = 0
        root.positionTo = 0
        root.swapping = false
        // The marker's clock is stopped here rather than left to finish: this is a commit
        // that never showed the marker travelling, so letting it land 320ms later would
        // drop it onto a card it had already been told about.
        crossingRun.stop()
        root._markerCrossing = false
        root._departingRowIndex = -1
        root._departingScroll = 0
        root._exitFrom = 0
        root._journeyDirection = 1
        // A rest plan rather than no plan: the strip still needs to be drawn, and
        // this is the one that says "three columns, active slot 1, centred here" -
        // the same shape the crossing's plan has, so every binding downstream can be
        // written once. See `HintLogic.restPlan`.
        const rest = HintLogic.restPlan(root.hint)
        root.plan = rest
        // At rest the panel is centred on this workspace and both ends of the
        // crossing are that value, so a crossing started from here begins exactly
        // where the resting layout was - which is what lets a crossing simply use
        // its own `fromPosition`, with nothing to compensate.
        if (rest) {
            root.positionFrom = rest.fromPosition
            root.positionTo = rest.toPosition
        }
        root.columns = HintLogic.stripColumns(root.hint, null, rest)
        root.shownReady = HintLogic.ready(root.hint)
    }

    // Swap the arriving frame's columns under the crossing, without touching the
    // clock. The strip's offset is what carries the motion, so the rows change
    // under it mid-crossing and the user sees the new workspace's list already in
    // place behind the seam.
    function _replaceArriving() {
        root.columns = HintLogic.stripColumns(root.hint, root.leavingHint, root.plan)
        root.shownReady = HintLogic.ready(root.hint)

    }

    // Hold what is on screen, extend the strip to carry the new frame alongside
    // it, and start the clock. The held frame is a reference to the same hint
    // object, so nothing is copied and the leaving rows keep their own delegates.
    function _startSlide(plan) {
        // The departing column's scroll offset, captured BEFORE the plan or the columns
        // are replaced. Both of those change which column is the active one, and a strip
        // whose active column has just been rebuilt reports no scroll range for a frame -
        // which clamps the offset to zero before anything downstream could read it. Read
        // a line lower it was reliably 0, and the departure leg then started from the
        // focused card's UNSCROLLED position: 170px below the panel, so the marker set off
        // upward instead of down and the whole leg played out of sight.
        root._departingScroll = strip.scrollOffset
        root.plan = plan
        root.columns = HintLogic.stripColumns(root.hint, root.leavingHint, plan)
        root.shownReady = HintLogic.ready(root.hint)
        // The row the marker walks away from, and the place that walk starts. Taken
        // before either clock starts, so the departure is on screen from the crossing's
        // first frame - the marker is already sliding off the old card rather than
        // appearing on the new one and only then leaving.
        // The UNCAPPED window list, deliberately. `cappedRows` truncates to the
        // viewport's five rows, so a workspace whose focused window was further down
        // reported no focused row at all - and the departure leg was then given zero
        // length, which is why the marker never appeared to move down on exactly those
        // switches. The arriving side has always read the uncapped list, so the two ends
        // of the journey were answering the question differently.
        root._journeyDirection = plan.direction
        root._departingRowIndex = HintLogic.focusedIndexIn(
            HintLogic.rowsFromList(root.leavingHint ? root.leavingHint.windows : null))
        root._exitFrom = root.exitFrom
        root._markerCrossing = true
        root.swapping = true
        // Hand the tracker to the frame's journey rather than cancelling it. The publish that
        // starts this crossing is what moved the focus, so the tracker may already be
        // mid-trail toward the arriving row; committing to the journey from wherever its
        // two ends are keeps that one motion continuous instead of resetting it to zero
        // length on this frame - which is what the snap here used to do, and what made a
        // trail in flight collapse the instant a switch began.
        root._followJourney()
        root.positionFrom = plan.fromPosition
        root.positionTo = plan.toPosition
        root.slideProgress = 0
        slideRun.restart()
        crossingRun.restart()
    }

    // A second switch arrived mid-crossing. The strip must CONTINUE from where it
    // is: re-aiming it to the new plan's own start would throw the content back to
    // the edge of the panel, which is a visible jump rather than a correction.
    //
    // The one thing a re-aim has to preserve is where the crossing had actually
    // reached, so that is what the new leg starts from. Read from the clock rather
    // than from the incoming plan's own start, for exactly that reason.
    //
    // There is nothing else to correct, and that is the payoff of keying the layout
    // on workspace positions instead of on a translated strip. Every column used to
    // sit at `slot + offset`: a new plan renumbered the slots, so `stripReshift` had
    // to take the difference of the two bases and give it back out of the offset, or
    // the content jumped sideways by exactly that many columns on the frame the
    // second switch landed. Now a column's place is a function of its own workspace
    // and the panel's centre, neither of which the re-aim disturbs - the new leg
    // simply starts at the position the old one had reached.
    function _reaimSlide(plan) {
        // Read before the plan is replaced: `crossingTop` is a function of the clock and
        // the landing row, so reading it afterwards would measure the new leg against
        // the old leg's progress.
        const here = root.panelPosition
        const markerHere = root.crossingTop
        // Read before the hint changes over, and deliberately NOT recaptured from the new
        // frame's focused row: the marker is mid-DEPARTURE, so the row it is on is the one
        // it has not reached yet. What it continues from is where it has got to. Only the
        // departure leg can be re-aimed - a re-aim needs the strip's clock still running,
        // and that is the first half of the marker's.
        root._exitFrom = markerHere
        root.plan = plan
        root.columns = HintLogic.stripColumns(root.hint, root.leavingHint, plan)
        root.shownReady = HintLogic.ready(root.hint)
        root.swapping = true
        // Already true on a re-aim, and deliberately not reset: the marker carries on
        // down through the second switch rather than restarting its journey.
        root._markerCrossing = true
        // As in `_startSlide`: the tracker joins this leg from wherever it is, rather
        // than being reset. A second switch lands mid-trail more often than not, and a
        // snap here is exactly the sudden shortening it is meant to avoid.
        root._followJourney()
        root.positionFrom = here
        root.positionTo = plan.toPosition
        // Restart both clocks from the current position, not from either crossing's own
        // start: the re-aim is a new traverse over the remaining distance, and beginning
        // either at 0 while the content is already halfway across would jump.
        root.slideProgress = 0
        slideRun.restart()
        crossingRun.restart()
    }

    // The marker's clock: 320ms, twice the strip's, and it carries BOTH legs. The
    // departure takes the first half - the same length as the column traverse and on the
    // same footing, so the marker leaving the old card reads as part of that gesture
    // rather than as a second event - and the corner falls exactly on the frame
    // `slideRun.onFinished` narrows the strip. The arrival then has the second half to
    // itself, landing on a panel that has stopped moving rather than chasing content that
    // is still sliding. Adding the departure cost the journey no extra time at all.
    NumberAnimation {
        id: crossingRun
        target: root
        property: "crossingClock"
        from: 0
        to: 1
        duration: MotionTokens.page * debugTimeScale
        easing.type: Easing.InOutQuad
        onFinished: {
            // No settle here. The tracker has been following the frame all the way, so the
            // bar arrives already stretched; the tail's own flight - three times the
            // head's - contracts it, and that contraction is the last beat of the switch
            // rather than a second event bolted onto the frame's landing. Snapping it
            // away here used to be deliberate, to hand over a bar at rest at exactly the
            // moment the motion finished, but it is the same snap that made a switch cut
            // a trail short, just at the other end.
            // The frame lands. There is
            // nothing to hold the tint back for here any more: the tint has been
            // following the frame's own rectangle the whole way in, so the card lit on
            // the frame the band first touched it rather than on this one - and
            // `Behavior on color` was off for every frame of that, which is what kept a
            // crossfade out of the middle of the journey.
            root._markerCrossing = false
            root._departingRowIndex = -1
            root._departingScroll = 0
            root._exitFrom = 0
            root._journeyDirection = 1
        }
    }

    NumberAnimation {
        id: slideRun
        target: root
        property: "slideProgress"
        from: 0
        to: 1
        // The workspace widget's active-highlight curve, verbatim: `Workspaces.qml`
        // slides `activeHighlight` on `MotionTokens.medium` with `Easing.OutQuad`.
        // One ease, one duration, no phases.
        //
        // The strip's own active-column highlight slides on the SAME recipe (see
        // `BarWindowHintStrip`), so the list and the highlight behind it are on one
        // clock. Sharing the widget's curve rather than a near miss is the point: the
        // panel is that widget's columns at three times the size, and a crossing that
        // does not move like the highlight it sits inside is the mismatch you can see
        // without noticing you can see it.
        duration: MotionTokens.medium * debugTimeScale
        easing.type: Easing.OutQuad
        onFinished: {
            // The strip has landed with the arriving frame's active column in the
            // middle, so the held frame goes with it and exactly one set of rows
            // stays alive. The strip also narrows to the arriving frame's own three
            // columns, and the panel's centre becomes that workspace outright rather
            // than a number that happens to have arrived there - the resting plan
            // says the active column is slot 1, which is the panel's middle column.
            //
            // Narrowing the strip matters as much as dropping the held frame: a
            // crossing's strip is `span + 3` columns, and keeping those extra
            // workspaces painted at rest would show columns the arriving frame's own
            // three do not describe.
            root.leavingHint = null
            const rest = HintLogic.restPlan(root.hint)
            root.plan = rest
            root.columns = HintLogic.stripColumns(root.hint, null, rest)
            if (rest) {
                root.positionFrom = rest.fromPosition
                root.positionTo = rest.toPosition
            }
            root.slideProgress = 1
            // The strip's flag only. The marker's clock runs 160ms BEYOND this handler,
            // and its state - `_markerCrossing`, `_departingRowIndex` and the captured
            // `_exitFrom` - belongs
            // to `crossingRun.onFinished`. Clearing it here would have reset the captured
            // start to zero while the marker was still two thirds of the way down, which
            // throws it most of the way back up the panel on the frame the columns settle.
            //
            // The arrangement that makes the two-beat effect safe is exactly this: the
            // marker lands onto a panel that has already stopped moving, and neither
            // handler reaches across to the other's clock.
            root.swapping = false
        }
    }

    onHintChanged: _onHintChanged()

    // The bar's top edge, in the SAME space as `focusedRowTop` - which is a SCROLLED
    // space, because the active column's own `y` is its negative scroll offset.
    //
    // The subtraction is the whole of it, and it was missing. `_targetYFor` and the
    // tracker that consumes it are in the column's own UNSCROLLED coordinates, which is
    // right for them - the stretch is a property of the list, not of where the viewport
    // happens to be - but the bar is drawn as a sibling of the cards, so where it is
    // drawn has to be where the cards are. With the column scrolled, the two disagreed by
    // exactly the scroll offset: the outline sat on the focused card and the bar sat the
    // same number of pixels below the list's own bottom. Measured on a twelve-window
    // workspace with the focus on row 9, the outline landed on the card at y 136 and the
    // bar at y 307 - 171px apart, which is the scroll.
    readonly property real _barTop: Math.min(_headY, _tailY) - strip.scrollOffset
    readonly property real _barLength: indicatorLength + Math.abs(_headY - _tailY)

    // Where the bar belongs while the frame is travelling: on the frame, in the bar's own
    // length, measured in the tracker's scrolled coordinates like every other target
    // (`_targetYFor` is pre-scroll too, and `_barTop` subtracts the offset back out).
    // Where the bar belongs while the frame is travelling: on the frame, in the bar's own
    // length, measured in the tracker's scrolled coordinates like every other target
    // (`_targetYFor` is pre-scroll too, and `_barTop` subtracts the offset back out).
    //
    // A FUNCTION and not a `readonly` property, which is the trap this file has already
    // paid for twice. A property's binding is re-evaluated when its dependencies change,
    // and nothing orders that before the `onCrossingTopChanged` handler that reads it - so
    // the handler was handed the PREVIOUS frame's target and the head trailed the frame by
    // exactly one frame, forever. Measured across a crossing at quarters: `journeyY` ran
    // 69, 118.5, -42, -20.5, 1 and the head ran 74, 69, 118.5, -42, -20.5 - the same
    // series, one step behind, for the whole journey. A function is evaluated on the call,
    // so it can only ever be current.
    function _journeyTarget() {
        return root.crossingTop + root.markerOffset + strip.scrollOffset
    }
    readonly property bool hasTarget: focusedRowIndex >= 0
            && activeColumn
            && focusedRowIndex < activeColumn.rows.length

    // `_snapping` is the load-bearing gate on both of these, and it is a
    // property rather than anything about the crossing, so a `Behavior` sees it at the
    // moment the property CHANGES - which is what a write inside `_snapIndicator` needs
    // and a flag read inside `_syncIndicator` would arrive a step too late for.
    //
    // `!root._markerCrossing` used to sit here as well, and it froze the tracker for the
    // whole journey: head and tail could not differ, so a workspace switch had no trail
    // and the crossing's own first write collapsed any trail in flight from before it.
    // The trail belongs on a switch - it is the widget's own behaviour - so the gate is
    // gone and the tracker's target during a crossing is the frame itself, which
    // `_followJourney` supplies on every frame the frame moves.
    Behavior on _headY {
        enabled: root._placed && !MotionTokens.reducedMotion && !root._snapping
        NumberAnimation {
            id: indicatorHeadAnimation
            duration: MotionTokens.medium * debugTimeScale
            easing.type: Easing.OutQuad
        }
    }
    Behavior on _tailY {
        enabled: root._placed && !MotionTokens.reducedMotion && !root._snapping
        // 3x the head's flight: the tail lingers long after the head lands, which
        // is what keeps the stretch readable.
        NumberAnimation {
            id: indicatorTailAnimation
            duration: MotionTokens.slow * 2 * debugTimeScale
            easing.type: Easing.OutSine
        }
    }

    // Commit head and tail together with the Behaviors suppressed. Both writes use
    // a precomputed target: reading _headY back would return the animation frame,
    // not the committed value.
    //
    // `_snapping` only stops a NEW behaviour animation from starting. It cannot end one
    // that is already running: these animations are declared inside `Behavior` blocks, so
    // they are not root nodes and `stop()` on them warns and does nothing. The gate that
    // does work is on the `enabled` of the two Behaviors - see the note there.
    function _snapIndicator(top) {
        _snapping = true
        _anchorY = top
        _headY = top
        _tailY = top
        _snapping = false
    }

    // Hand the tracker to the journey rather than freezing it.
    //
    // The distinction from `_snapIndicator` is the whole point: this writes the two ends
    // as TARGETS and lets the Behaviors animate towards them, so while the frame is
    // moving the head runs after it and the tail - three times the head's flight - lags,
    // and the bar is drawn stretched between them. That is the workspace widget's own
    // vocabulary: `Workspaces.activeHighlight` slides by being stretched, the head
    // arriving at the new square's centre while a shadow trails over the gap.
    //
    // It used to be frozen instead. `_syncIndicator` snapped head and tail together for
    // the whole crossing and both Behaviors were gated on `!_markerCrossing`, so a
    // workspace switch produced no trail at all - and because the gate made every tracker
    // write inside a crossing a snap, the write at the crossing's FIRST frame collapsed
    // whatever trail was still in flight from an earlier focus change to zero in one step.
    // That was the tail visibly shortening on consecutive switches, and it was worst
    // exactly when switches came quickly, because a trail was in flight more of the time.
    //
    // Snapping here at all is still wrong, though, and is why the hand-off writes the
    // CURRENT position rather than the arriving row's: the publish that starts a crossing
    // is the same publish that moves `focusedRowIndex`, so by this point the tracker may
    // already be trailing toward the arriving row. Committing to the journey from wherever
    // the two ends actually are keeps one continuous motion; committing to either end's
    // value would be a second one.
    function _followJourney() {
        const target = root._journeyTarget()
        if (!isFinite(target))
            return
        _anchorY = target
        // Not `_targetKey`: the landing row's own key. At the landing `_restingY()` is
        // that row, and a key that still said "journey" would read as a genuine switch
        // and flash the bar back to full length instead of letting the tail finish
        // contracting - the arrival's own motion, cut off by a bookkeeping value.
        _targetKey = String(root.focusedRowIndex)
        // The head SNAPS and the tail is merely re-targeted, and the asymmetry is the
        // design rather than an inconsistency. The head is the frame's own position: the
        // bar has to stay one `markerOffset` below the outline for the whole journey, or
        // the two stop being one gesture - and a Behavior chasing a target that moves
        // every frame is always behind it, which is a lag, not a lead. So the leading end
        // of the bar is pinned to the frame and only the trailing end flies, three times
        // the head's flight. `_barTop` is the MINIMUM of the two, so the bar is drawn
        // upward from the tail to just past the head: the stretch is a wake behind the
        // frame, and the frame never leaves the bar's leading edge.
        //
        // `_snapping` is read at the moment the property changes, which is why it brackets
        // the head's write rather than being set for the whole function: the tail below it
        // has to animate.
        _snapping = true
        _headY = target
        _snapping = false
        _tailY = target
    }

    // Route every re-anchor through here. A genuine target switch desyncs head and
    // tail into the trail and blinks once; same-target layout drift snaps both so
    // content churn never stretches the bar; the first placement snaps so it never
    // slides in from zero.
    function _retargetIndicator(top, key) {
        if (!isFinite(top))
            return
        if (key !== _targetKey && _placed) {
            _pendingTop = -1
            _targetKey = key
            _anchorY = top
            _headY = top
            _tailY = top
            _flashIndicator.restart()
            return
        }
        if (Math.abs(top - _anchorY) < 0.5)
            return
        if (Math.abs(_headY - _tailY) > 0.5) {
            _pendingTop = top
            return
        }
        _snapIndicator(top)
    }

    // Apply a drift that landed mid-trail, once the tail has caught up.
    Timer {
        interval: 16
        repeat: true
        running: root._pendingTop >= 0
        onTriggered: {
            if (Math.abs(root._headY - root._tailY) >= 0.5)
                return
            var pending = root._pendingTop
            root._pendingTop = -1
            root._snapIndicator(pending)
        }
    }

    // Three columns, always, one of them twice as wide. The popup measures its
    // geometry from this, so the host's `window-hint` width reads the body rather
    // than keeping its own number - and the body reports the same number whether
    // the neighbour workspaces are busy or empty, so the panel never changes size
    // mid-hold.
    //
    // The clip is what keeps the rest of the strip off the surface. A crossing
    // carries `span + 3` columns through a three-column window, so up to three
    // extra columns are travelling through the panel, and without a clip here they
    // would paint outside the popup's own rect - and outside the layer-shell input
    // region the host sized from this body's width.
    clip: true
    // Neighbour, gutter, the wide active column, gutter, neighbour. Not
    // `3 * narrowPitch - columnGutter`: the active column is twice a neighbour's, and
    // a panel sized for three equal columns would either crop its own middle slot or
    // leave the band's right edge a whole column short of the surface.
    implicitWidth: panelWidth
    // The taller of the two frames while a crossing is in flight, and the strip's
    // own height once it has landed. The empty-workspace placeholder lives inside
    // the columns, so the columns' own height already accounts for it.
    // The card block, plus the band's own padding, less whatever the band covers
    // beyond this body's edges by reaching for the surface. With no host inset that is
    // the block plus its padding; with one it shrinks, because the band is already
    // covering ground the body does not own.
    // Bounded by the VIEWPORT, which is what the cap used to do by truncating the list.
    // A twelve-window workspace now scrolls within five rows instead of collapsing the
    // rest into a summary line, and the panel is the same size either way - so the
    // layer-shell input region still does not grow once per added window.
    implicitHeight: ready
        ? Math.min(root.viewportHeight,
            Math.max(root._outgoingHeight, strip.contentHeight))
            + cellPaddingY * 2 - bandOutset * 2
        : emptyText.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // The strip. One object, carrying both frames, and NOT translated: every column
    // on it places itself from `panelPosition`, so there is no strip-level offset
    // that could disagree with them or fall a frame behind them. The panel is the
    // three-column window onto it, and `clip` on the body is what keeps the rest of
    // the run off the surface.
    // NO COLUMN-WIDE HIGHLIGHT, and its absence is the design.
    //
    // There was one here: the bar's `Workspaces.qml` draws the active workspace's cell as
    // a single `activeHighlight` rectangle behind its squares, and this was the same
    // surface at three times the size - a full-height, full-column `activeFill` (mTertiary
    // at 14% alpha) sitting behind the cards, swelling 2% at the middle of every crossing.
    //
    // It was the wrong grain. The panel already says which workspace is active three
    // other ways - the middle column is twice a neighbour's width, the columns trade
    // places through the middle slot, and the focus marker travels the whole height of
    // the panel onto one card. A fourth, coarser signal drawn UNDER all of them is the
    // one that reads as "the block changed", and it changed on every switch while the
    // thing the user is actually asking about - which window - arrived underneath it.
    // So the panel showed two nested highlights, and the outer one was the one that
    // moved.
    //
    // The focus marker's own three parts are the whole of the highlight now, and they are
    // all one card's worth: the row's own background (`settingsSelected`, painted under
    // its icon and title as its children), the border drawn around it, and the green bar
    // beside it. The active column is still unmistakable - it is the wide one.
    //
    // What is left of the band's geometry is `bandX`, above.

    BarWindowHintStrip {
        id: strip
        objectName: "windowHintStrip"
        parent: root
        // Spelled as 0 rather than left implicit, because the absence IS the design.
        // This used to be the one moving object in the panel, and a reader looking
        // for the crossing's motion should find it here and be told it is not here.
        x: 0
        // A padding down from the panel's top edge, and correspondingly shorter than
        // the panel: the strip is the card block, and the padding belongs to the panel
        // around it. Sized from the panel it overran the bottom by a whole padding,
        // which put the band's bottom margin out of step with its top.
        y: root.bandInset - root.surfaceInset + root.cellPaddingY
        height: Math.max(0, root.height - cellPaddingY * 2 + bandOutset * 2)
        // The active column's own clip is its business; the strip's height is the
        // viewport the body sized the panel from, which the columns are then measured
        // against.
        // NO DIP, and its absence is the point.
        //
        // The strip used to fade to 88% at the dead middle of a crossing -
        // `sin(PI * slideProgress) * 0.12` - because a translation has no weight of its
        // own and something had to give the traverse some. What it gave was a change to
        // the WHOLE BACKGROUND, peaking exactly halfway through the switch, across all
        // three columns and every card in them: the largest visual event in the crossing,
        // and it belonged to nothing. The one thing that should be changing is the card
        // the focus marker is on, and a surface-wide fade arriving alongside it is a
        // second event competing with it - which is what made the arrival read as "the
        // block changed" rather than as "the focus arrived".
        //
        // The weight it was there to supply is supplied properly now: the marker travels
        // the whole height of the panel, from outside one edge onto a card. Nothing else
        // needs to move for the switch to have a body.
        columns: root.columns
        // Read off the plan the strip was built from, so the column that carries
        // the card fill and the one the focus markers are placed against are the
        // same column by construction.
        activeSlot: root.plan ? root.plan.activeSlot : 1
        // The workspace the markers belong to, and the one the panel is centred on.
        // Two numbers rather than one because they are two different questions at the
        // START of a crossing: the arriving column is off-panel, and the panel is
        // still centred on the workspace being left.
        activePosition: root.plan ? root.plan.activePosition : 0
        panelPosition: root.panelPosition
        columnWidth: root.columnWidth
        activeColumnWidth: root.activeColumnWidth
        columnGutter: root.columnGutter
        // One viewport, declared once: the body sizes the panel from it and the strip
        // clips the column to it, so the two cannot be different numbers.
        viewportRows: root.viewportRows
        // The frame's own rectangle and whether it has stopped moving: what the row's
        // tint is computed from and what its `Behavior on color` asks. The strip cannot
        // read `focusFrame` itself - the element is declared here and only parented
        // there - so these are the two numbers the whole of the focus tint rests on.
        focusFrameTop: focusFrame.y
        focusFrameHeight: focusFrame.height
        focusFrameLeft: focusFrame.x
        focusFrameWidth: focusFrame.width
        debugTimeScale: root.debugTimeScale
        cellPaddingX: root.cellPaddingX
        listSpacing: root.listSpacing
        rowHeight: root.rowHeight
        glyphInset: root.glyphInset
        glyphWidth: root.glyphWidth
        interactive: !root.swapping
        onWindowActivated: windowId => root.windowActivated(windowId)
        onScrollOffsetChanged: root._onScrollChanged()
        // A crossing replaces the list, and the new column's content can be shorter
        // than the offset the old one was scrolled to.
        onContentHeightChanged: strip.clampScroll()
    }

    // One shared focus highlight for the whole list, the way the launcher's does: a
    // single element that moves rather than every row showing and hiding its own. ONE
    // instance, and it is the whole of the displacement effect: on a workspace switch
    // this rectangle is the thing that travels, coming down from the panel's top onto
    // the arriving card. It was two elements - this one plus a crossing-only twin, each
    // hidden while the other showed - because a `Behavior` on `y` and a pure function of
    // the crossing's clock are two animations on one property, and which of them won at
    // the boundaries came down to the order QML happened to evaluate them in. One
    // instance with two placements removes the race outright, and it is also what the
    // effect is FOR: a single rectangle travelling is the gesture, and two rectangles
    // taking turns is a cut.
    //
    // BORDER-ONLY, which is the launcher's arrangement and the reason the tint lives in
    // the row. This was a filled wash above the rows at z 5, the only way a separate
    // element could mark an opaque card - and `settingsSelected` is the primary at a
    // quarter alpha, so that wash veiled the icon and the title it was meant to be
    // pointing at. The fill moved into the row's own background, where it sits UNDER the
    // icon and the title as the row's children, and what glides here is the outline
    // around it. Exactly one element still carries the tint at a time: the focused row's.
    //
    // A child of the strip, and placed from the arriving column's own geometry, so it
    // travels with the content it marks and resizes with it. Pinned to the panel, it
    // would say the focus stayed put while the window list moved - two different claims
    // about where the current window is.
    //
    // And this rect is not only decoration drawn over the focused row: it is the MASK the
    // row's tint is computed from, handed down as `focusFrameTop` / `focusFrameHeight`.
    // A border-only rectangle still has a position and a height, and those are exactly
    // what says which card is lit - so the tint cannot be a second opinion about where
    // the focus is, because it is read off the same rectangle the user can see moving.
    Rectangle {
        id: focusFrame
        objectName: "windowHintFocusFrame"
        parent: strip
        z: 5
        radius: 6
        // Nothing filled, so this element cannot cover the row's content. The tint
        // is `windowRow`'s own background instead, in the same token - see above.
        color: "transparent"
        border.width: root.hasTarget ? 1.5 : 0
        border.color: LazerTheme.settingsAccent
        // Inert to input, so it can never intercept a tap meant for the row.
        enabled: false

        // Bounded by the row, not inset: the highlight has to cover exactly the row it
        // marks, and the row spans its column's full width. Both edges are read from the
        // arriving column's OWN geometry - through the same `slotX` and `slotWidth` its
        // delegate is placed by - so the outline cannot be drawn over a column that is
        // not the active one, and it widens with the card rather than staying the width
        // the card had at the start of the crossing.
        // The card it marks, which is the DEPARTING card for the first half of a
        // crossing and the arriving one for the second - so the outline is on the window
        // it left from while it leaves, and on the one it arrives at when it lands.
        x: root._markerCrossing ? root.markerLeft
            : strip.activeColumnX + root.cellPaddingX
        y: root._markerCrossing ? root.crossingTop : root.focusedRowTop
        width: root._markerCrossing ? root.markerWidth : strip.activeCardWidth
        height: root.rowHeight
        opacity: root.markerHasTarget ? 1 : 0

        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast * debugTimeScale
                easing.type: Easing.OutQuint }
        }
        // The focus glide, and ONLY the focus glide. The displacement is a pure function
        // of the crossing's clock, so a `Behavior` on the same property would be a second
        // animation fighting it. Gated on `_markerCrossing`, which is a flag rather than
        // `crossingClock < 1` precisely so that gate is already false by the time this
        // property is re-evaluated at the landing.
        Behavior on y {
            enabled: !root._markerCrossing && !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarCollapse * debugTimeScale
                easing.type: Easing.OutQuint }
        }
    }

    // The focus indicator, in the workspace widget's vocabulary and motion, turned
    // 90 degrees for a list that runs down a column: a short green bar in the band's
    // left padding, `barIndicatorHeight` thick with the same radius, in `osuGreen`.
    // One instance for the whole list, driven by the dual-speed tracker above so a
    // switch elongates along the bar's long axis and contracts on arrival rather than
    // sliding at one rate.
    //
    // Beside the card, not inside it. The widget's indicator is outside the marked
    // square - under it, in the bar's gap - and this one was 4px in from the card's
    // left edge, between the card's edge and its icon. Now it sits in the band's left
    // padding, so the row it marks is the thing it is next to and the card's own
    // inset is padding again rather than room made for the marker.
    //
    // Stacking: rows paint at the default 0, the shared focus outline above them at
    // 5, and this indicator above that at 6. Stated because at equal z the
    // declaration order alone would decide, and the outline's left edge is exactly
    // where this bar now sits.
    //
    // On a workspace SWITCH this same instance is what moves: it displaces down from the
    // panel's top onto the arriving card, one `markerOffset` below the outline above it,
    // so the two are one gesture throughout rather than two things that happen to agree.
    // See `crossingTop`.
    Rectangle {
        id: focusUnderline
        objectName: "windowHintFocusIndicator"
        parent: strip
        z: 6

        width: root.indicatorThickness
        radius: LazerTheme.barIndicatorRadius
        color: LazerTheme.osuGreen
        // Measured from the column's own left edge - the band's edge, not the card's - so
        // the bar and the outline it marks always move together, and on the DEPARTING
        // column for the departure leg exactly as the outline is.
        x: (root._markerCrossing ? root.markerLeft - root.cellPaddingX
            : strip.activeColumnX) + root.indicatorInset
        // The tracker's two ends, ALWAYS - the stretch is the bar's
        // own dual-speed motion and it belongs on a workspace switch as much as on a
        // focus change inside one workspace. During a crossing the tracker's target is
        // the frame itself (`_followJourney`), so the head runs after the frame and the
        // tail trails over the gap, and the bar draws stretched between them.
        //
        // It used to be `crossingTop + markerOffset` at a fixed `indicatorLength` for the
        // duration, on the reasoning that the bar was being carried and a changing length
        // would be a second motion on one marker. The stretch is not a second motion: it
        // is the bar's own, and it is what made the bar read as attached to the frame
        // instead of being repositioned by it.
        y: root._barTop
        height: root._barLength
        visible: root.markerHasTarget
        opacity: root.markerHasTarget ? 1 : 0

        // Switch blink: the same tinted-glow blink the workspace indicator plays
        // per genuine target switch.
        Rectangle {
            id: indicatorFlashOverlay
            objectName: "windowHintIndicatorFlash"
            anchors.fill: parent
            radius: parent.radius
            color: LazerTheme.flashWash
            opacity: 0
            enabled: false
        }

        NumberAnimation {
            id: _flashIndicator
            target: indicatorFlashOverlay
            property: "opacity"
            from: MotionTokens.clickFlashOpacity
            to: 0
            duration: MotionTokens.clickFlashDuration * debugTimeScale
            easing.type: MotionTokens.clickFlashEasing
        }

        Behavior on opacity {
            NumberAnimation { duration: MotionTokens.fast * debugTimeScale }
        }
    }

    // Drive the indicator from the one focused row. Hooked to the target itself
    // rather than to `focusedRowTop`: the derived top edge and `hasTarget` are
    // separate bindings, and QML does not order their change handlers, so a hook on
    // the top edge could observe the "target lost" case after the target came back
    // and snap the bar to the meaningless position a target-less row computes. Both
    // hooks call the same routine; the second is a no-op.
    //
    // The target is computed from `focusedRowIndex` - the property that just
    // changed - rather than read back from `focusedRowTop` or the binding on
    // `_indicatorTargetY`. A change handler runs as soon as its own property is
    // notified, which is before the bindings that depend on it have necessarily been
    // recomputed; reading one of those there yields the PREVIOUS row's target and
    // leaves the bar one switch behind. This is the same discipline the workspace
    // widget uses, where `updateIndicator` computes `centerX` itself and passes it
    // into the tracker.
    // The active column scrolled. The markers are positioned from `focusedRowTop`,
    // which already carries the offset, so this is about the marker's own TRACKER: the
    // dual-speed tracker holds committed targets, and a scroll that moved the row under
    // it without re-anchoring would leave the bar easing toward a position the row has
    // already left.
    function _onScrollChanged() {
        if (root.swapping)
            return
        root._retargetIndicator(root._targetYFor(root.focusedRowIndex),
            String(root.focusedRowIndex))
    }

    // Reveal the focused window when focus moves to a row the viewport does not show.
    // niri moves focus on its own (a window raises, a shortcut focuses another), and a
    // marker pointing at a scrolled-out row is a marker pointing at nothing - the same
    // reason `focusedIndexIn` refuses to return an index past the cap.
    function _revealFocusedRow() {
        if (root.focusedRowIndex < 0)
            return
        // Not animated for the WHOLE journey, not just the strip's half of it. The
        // marker's landing target is `focusedRowTop`, which carries the scroll offset - so
        // a reveal still easing when the arrival leg began would move that target under a
        // marker that is halfway down travelling to it, and the marker would chase it for
        // 300ms. niri's second publish about 40ms into a switch is what makes that likely
        // rather than merely possible, since that is when the new workspace's windows
        // arrive and the reveal they call for has to happen.
        strip.revealRow(root.focusedRowIndex, !root.swapping && !root._markerCrossing)
    }

    // Where the bar rests when there is no row to mark: the same off-panel position the
    // outline uses, converted into the tracker's own UNSCROLLED space (which is the
    // scrolled one plus `scrollOffset`, since `_barTop` subtracts it again on the way
    // out). `_targetYFor(-1)` is not it - that expression is `index * rowPitch + ...`, so
    // an index of -1 is a real coordinate about a row above the panel, and the next real
    // target's `Behavior` then animates FROM it.
    //
    // Named rather than written out because it has more than one caller, and one of them
    // had put the marker's own landing back on a negative row.
    function _restingY() {
        return root.hasTarget ? root._targetYFor(root.focusedRowIndex)
            : root.noRowTop + strip.scrollOffset + root.markerOffset
    }

    function _syncIndicator() {
        var target = root._restingY()
        // While the marker is travelling, the tracker's target is the FRAME, and it is fed
        // from `crossingTop` rather than from a row index. `focusedRowIndex` changes the
        // instant a switch is published - before the crossing starts and while it runs -
        // so retargeting to the row would put a second, independent motion on the bar
        // underneath the frame's own, and a bar whose length is no longer the one
        // `markerOffset` was measured against.
        //
        // The end of the crossing needs no special case either: `_followJourney` leaves
        // `_targetKey` naming the landing row, so the resting sync that follows finds the
        // key unchanged, sees the position it is already at, and returns - leaving the
        // tail to finish contracting on its own. That contraction is the arrival's own
        // motion and belongs on the bar; snapping it away was a second event at the exact
        // moment the first finished.
        if (root._markerCrossing) {
            root._pendingTop = -1
            root._followJourney()
            return
        }
        if (!root.hasTarget) {
            // No target: the bar is hidden, so it must not be left mid-trail either
            // - a trail still in flight when the next target arrives would stretch
            // out of the wrong place.
            //
            // Snap to the resting position for NO row rather than to
            // `_targetYFor(-1)`. That expression is `index * rowPitch + ...`, so an
            // index of -1 hands back a negative offset roughly one row above the
            // panel's top: a real coordinate, which the next target's `Behavior`
            // then animates FROM. The bar is invisible, so the flight was not
            // visible when it happened - but it was a flight, and it arrived at the
            // right row only after `MotionTokens.slow * 2` of tail travel. That is
            // the flash on arriving at a workspace whose focused row is not where
            // the previous one was.
            //
            // Zero is the honest "resting, nowhere" value: it is where
            // `_snapIndicator` puts the marker before its first placement, and a
            // bar that has no row to sit on has no business anywhere else. Retarget
            // from here and the first real target still travels, which is the
            // dual-speed stretch doing its job, rather than arriving pre-stretched
            // from a coordinate that never named a row.
            root._pendingTop = -1
            root._snapIndicator(root._restingY())
            // ...and it is no longer a PLACEMENT. Zero is a coordinate that names no row,
            // and the next real target has to arrive by snapping rather than by flying
            // from it: `_retargetIndicator`'s genuine-switch branch animates the head and
            // the tail from wherever they are, which from here means the bar entering on
            // the FIRST card and sliding down to the focused one - a journey invented by
            // the tracker's resting value, out of a state where there was nothing to
            // travel from. Clearing `_placed` hands the next target to the first-placement
            // branch below, which snaps.
            //
            // So this branch is not only "no row, park it" - it is also the statement
            // that the marker is not currently on a row, which is what the stretch needs
            // to know and had no way to ask.
            root._placed = false
            return
        }
        // First placement snaps: there is nothing on screen to travel from.
        if (!root._placed) {
            root._placed = true
            root._targetKey = String(root.focusedRowIndex)
            root._snapIndicator(target)
            return
        }
        root._retargetIndicator(target, String(root.focusedRowIndex))
    }

    onFocusedRowIndexChanged: {
        _syncIndicator()
        _revealFocusedRow()
    }
    onHasTargetChanged: _syncIndicator()

    // The tracker's target during a crossing moves every frame the frame moves, so this
    // is where the trail comes from. One handler rather than a binding, because the head
    // and the tail are written by their Behaviors - a binding on either would be torn off
    // by the first animation that started - and because both must be written on the same
    // frame to keep the target they are chasing a single value.
    onCrossingTopChanged: {
        if (root._markerCrossing)
            _followJourney()
    }

    Component.onCompleted: {
        if (root.hasTarget)
            root._syncIndicator()
    }

    // Cold snapshot: the service has not resolved an active workspace yet, so the
    // menu says so instead of drawing an empty list.
    Text {
        id: emptyText
        objectName: "windowHintEmpty"
        parent: root
        width: parent.width
        text: "Waiting for the active workspace"
        color: LazerTheme.textMuted
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        visible: !root.ready
    }

}
