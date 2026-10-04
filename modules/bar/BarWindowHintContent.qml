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
    // The indicator's switch blink, exposed for the same reason as the two above and with
    // the same payoff: `restart()` sets `from` synchronously, so a suite can read the recipe
    // on the frame the switch happened rather than waiting out a decay and guessing where
    // in it a poll landed. This is `Workspaces.flashIndicator`'s animation.
    readonly property alias flashAnimation: _flashIndicator
    // The focus frame's own glide, for the same reason as the rest. A `Behavior` has no
    // `animation` property of its own, so a suite cannot ask "is the frame still easing?"
    // any other way - and it has to ask, because a `Behavior`-driven `y` reads the
    // pre-change value to a test function that does not run the event loop.
    readonly property alias focusFrameMotion: focusFrameGlide
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
    //
    // `Workspaces.qml`'s own name for this number is `indicatorBarWidth`, and everything
    // about how it stretches lives in that file: `_edgeX` on `medium`/OutQuad,
    // `_edgeShadowX` on `slow * 2`/OutSine, a raw `_edgeSpan` with no bound on it, and
    // `retargetEdges` handing both ends ONE committed target and blinking once when the
    // identity changes. This is that tracker, rotated. Where the two disagree is a bug in
    // one of them, and "consistent with the workspace widget" is the test for it.
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
    // once the tail catches up, so a trail is never cut short. The workspace
    // widget's own `_edgePendingCenterX`, and for the same reason: a drift that
    // lands mid-trail waits rather than cutting the trail, and the wait is the
    // tail's own convergence rather than a duration.
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

    // THE IDENTITY the tracker is aimed at, and the thing a "genuine switch" means
    // here. `Workspaces.qml` keys its own indicator on the focused WINDOW, falling
    // back to the active workspace when no window is focused - see `updateIndicator` -
    // because the bar marks a thing, and two marks of different things are a switch
    // however far apart they sit.
    //
    // It has to be the window rather than the row index, and this is the case that
    // forced it. Two workspaces can both be focused on their row 2, and a switch
    // between them does not move `focusedRowIndex` at all - so an index key reports
    // "nothing moved" for a switch, which is the blink the widget gives every one of
    // them. Keyed on the window, a switch is a switch, and the bar's target being the
    // same row on both sides is then correctly reported as a switch that does not
    // travel: commit, blink, no stretch.
    //
    // Derived, and the derivation is safe here for the reason the row index's own
    // handlers were unsafe: nothing READS another derived property out of this one.
    // It is compared for change and nothing else, so the one-frame staleness a
    // derived property has inside its own notification cannot reach it. Every
    // position still comes from `_targetYFor`, one turn later, from the index.
    readonly property string focusedWindowKey: hasTarget
            && activeColumn
            && focusedRowIndex < activeColumn.rows.length
            && String(activeColumn.rows[focusedRowIndex].windowId) !== ""
        ? "w" + String(activeColumn.rows[focusedRowIndex].windowId)
        : "s" + (root.plan ? root.plan.activePosition : 0)

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
        // `hint` as well as `plan`, because it is read on the next line and it starts
        // null. The log caught this where no test ever could: `scripts/check-shell.sh`
        // reported `TypeError: Cannot read property 'activeWorkspacePosition' of null`
        // against this file, recurring on the live session. A journey's flag and its plan
        // can both be set while the hint they describe is momentarily absent - the panel
        // is being rebuilt from a publish that has not resolved its windows yet - and the
        // guard above was checking the two of the three that are set.
        if (!root.hint)
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
        // ...and the trail goes back to the tracker, because clearing the flag is what
        // abandons the pin's last write. A commit that never showed the marker travelling
        // can arrive at any point in a journey, so this is the ordinary case of the
        // hand-back and not an edge: `_closeTrail` is a no-op when both ends are already
        // home, which is every commit that did not interrupt one. See the note there.
        Qt.callLater(root._closeTrail)
        root._departingRowIndex = -1
        root._departingScroll = 0
        root._exitFrom = 0
        root._journeyScroll = strip.scrollOffset
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
        // The trail's coordinates start out expressed against the scroll the bar is
        // standing on, so the crossing's first re-base is the difference and not the whole
        // offset. See `_journeyScroll`.
        root._journeyScroll = strip.scrollOffset
        // The two FLAGS go up before the columns do, and that order is the fix rather than
        // tidiness. `_revealFocusedRow` refuses to animate a reveal while either is set -
        // the reasoning is at its own definition, and it is right: an eased offset arrives
        // after the column it belongs to - and `onFocusedRowIndexChanged` runs the moment
        // the new `columns` land, which is the same synchronous block. With the flags below
        // that assignment, every switch revealed itself over 300ms while the frame was
        // already travelling, so the frame's own landing target was a MOVING one.
        //
        // Measured, and it is why the trail was not a function of the frame's motion at
        // all: on a switch to row 11 of a twelve-window workspace the offset ran
        // 211.1, 219.5, 225.3, 229.8 and then 238 across five frames of the departure leg,
        // and the frame's arrival target with it - 162.9, 154.5, 148.7, 144.2. The frame
        // was arriving at a target that was still moving, and the trail's head was chasing
        // both.
        root._markerCrossing = true
        root.swapping = true
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
        // The tracker is not told anything here, and that is the design rather than an
        // omission: it was re-aimed by the publish that got here, because that publish
        // replaced the columns and therefore the focused window. `_retargetIndicator`
        // re-aims from wherever the two ends have reached rather than from a committed
        // value, so a second switch landing mid-wake continues that wake instead of
        // replacing it - which is the widget's own answer to switching during a switch.
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
            // No settle here, and nothing to settle. The head has been PINNED to the frame
            // for the whole journey and the frame has just landed on the card, so the head is
            // already exactly where the tracker's committed target has been since the switch
            // was published. What is left is the trail: the tail is `head - d/k` behind, and
            // the hand-back below closes it on the widget's own `slow * 2`/OutSine - which
            // makes the wake's contraction the last 320ms of the switch rather than a second
            // event bolted onto the frame's landing. Snapping it away here used to be
            // deliberate, to hand over a bar at rest at exactly the moment the motion
            // finished, but it is the same snap that made a switch cut a trail short, just at
            // the other end.
            //
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
            root._journeyScroll = strip.scrollOffset
            // ...and the tail goes back to the `Behavior` on the next turn, because a
            // `Behavior` captures its target when `enabled` goes true. See `_closeTrail`.
            Qt.callLater(root._closeTrail)
            root._journeyDirection = 1
        }
    }

    // The pin, driven by the frame itself. Every write the pin makes is a re-evaluation of
    // the frame's own position, so the head is at most one tick behind the frame - which is
    // what "the bar has to stay one `markerOffset` below the outline for the whole journey"
    // asks for. Nothing else in the file may write either end while `_markerCrossing` is
    // set, and `_syncIndicator` is where that is enforced.
    //
    // `crossingTop` is a function of the clock AND of the focused row's own top edge, so it
    // also moves on a reveal scroll AFTER the clock has finished - which is why the pin
    // checks the flag rather than trusting to be called only while a journey is running.
    // Without the check the pin was a third mechanism: measured on a switch into a
    // twelve-window workspace focused on row 9, the landing's reveal re-fired the handler
    // with the flag already down, the pin wrote the head back to a stale journey target
    // under the two ends that were flying home, and the head froze at 132.4 against a
    // committed 307.0 while the tail ran on to 74.0 and stopped there. Both ends stranded,
    // the bar stretched across two rows it was never on, and no animation left to close it.
    onCrossingTopChanged: _followJourney()

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
    // The wake, and the bar's geometry from it: `Workspaces.qml`'s `_edgeRectLeft` and
    // `_edgeSpan`, read down a column instead of across a row. RAW separation, no cap and
    // no clamp, because that is the widget's rule and the widget has never bounded it - and
    // because the cap was what produced the reported fault. `indicatorWakeCap` existed
    // because the head was PINNED to the focus frame AND the tail was a slow follower, so a
    // separation with no bound was whatever the frame's speed happened to make it. Measured
    // across one switch with that pair: 26, 43, 50, 60, 73, 87, then 91, 91, 91, 91 for five
    // consecutive frames, then 90, 54 in one 16ms step, then 43, 63, 76, 85, 89 again - and
    // 52.5 still open 480ms after the switch began. A bar at 3.5x its resting length, held,
    // then dropped, then re-opened and closed over the better part of a second. A cap
    // cannot fix that, because the cap IS the plateau: it converts a growing wake into a
    // held one and the held one into the drop at the corner.
    //
    // The cause was neither the arithmetic nor the follower but the FOLLOWER'S RATE. A
    // wake is the distance between two positions converging on ONE place, so a fixed target
    // bounds it and closes it. A sweep has no such place, so its wake is a function of
    // SPEED - and speed is unbounded at the corner, where the head jumps the panel's whole
    // height plus a card at each end in a single tick. A follower that closed 0.12 of the
    // gap a tick (a 131ms time constant) turned that one jump into 392px of bar, which is
    // two and a half times the panel is tall: a plateau wide enough to need a cap, and a
    // cap is the drop. The rate is the whole of it, and it is measured - see
    // `trailCatchUp`.
    //
    // `Workspaces` slides `activeHighlight` to the new square on its own `medium`/OutQuad
    // while its indicator stretches and flies there on its own two-speed clock, so the two
    // motions in the widget are already separate and deliberate. This panel is that widget
    // magnified, and the frame is the magnified highlight.
    //
    // ---- TWO MECHANISMS, AND WHICH ONE OWNS THE POSITION ------------------
    //
    // The bar travels two different ways, and the conflict between them is the design, so
    // it is stated here rather than discovered later.
    //
    // AT REST, and on a focus change inside one workspace, the bar is `Workspaces.qml`'s
    // indicator and nothing else: ONE committed target - the focused row - head on
    // `medium`/OutQuad, tail on `slow * 2`/OutSine, wake the raw separation, no bound,
    // one blink per change of identity. That is a DISPLACEMENT, so the wake is a FRACTION
    // of how far the bar is going: 55.5% analytically, 55.3% measured across a 4.7x range
    // of travel, 55.2% of a 646px journey. Correct, and the widget's own answer.
    //
    // DURING A CROSSING the target is the frame's own journey, and that is not a
    // displacement but a SWEEP: down off the panel, back in through the other edge, onto
    // the card. A sweep has no end for the widget's pair to fly to, so it needs a follower.
    //
    // And what was got wrong is the TARGET, not the follower. Two workspaces focused on the
    // SAME row are the SAME row, so a fixed target gives the bar nowhere to go at all -
    // which is the report, and which is not a defect of a travelling target but a defect of
    // this one. Measured with the bar aimed at the landing row across such a switch: the
    // drawn bar's top read 137.0 on every one of 60 samples and the wake 0.0 on every one,
    // while the frame it is supposed to be travelling with ran
    // 139.3, 146.7, 146.7, 160.4, 160.4, 178.9, 190.1, -38.6, 40.3, 60.4, 83.1, 101.7,
    // 115.6, 126.4, 129.7, 134.6 and then sat at 136. The frame crossed the panel twice
    // and the bar did not move by one pixel. That is "the indicator does not move at all,
    // it teleports", in numbers.
    //
    // So during a crossing the HEAD IS PINNED to the frame and the TAIL FOLLOWS it. The
    // pin is not only where the trail comes from; it is what hides BOTH of the crossing's
    // discontinuities. The frame's corner teleport is off-panel VERTICALLY by construction
    // - `_offTop` and `_offBottom` are a whole card past each edge - so a bar travelling
    // with the frame is off-panel at the corner too, and the COLUMN swap underneath it is
    // invisible. Un-pinned, the bar sits on the landing row through the corner and the
    // swap becomes a visible horizontal jump: measured on that same switch, the bar's x ran
    // 119.7, 92.7, 72.2, 36.8, 23.4, 14.1, 9.2, then 194.0 - a 185px step in one frame, at
    // a y that never moved.
    //
    // THE CONFLICT, named: `_retargetIndicator` commits BOTH ends to one target and
    // blinks. That is the widget's answer to a change of identity, it is right at rest, and
    // it is wrong during a crossing - where it would hand both ends to the landing row on
    // the switch's first frame and leave the bar sitting still under a frame that is
    // already leaving the panel. So the PIN owns the position for the whole crossing, the
    // commit does not run there at all (`_syncIndicator` returns before reaching it), and
    // the only part of the widget's response a crossing keeps is the BLINK, which changes
    // an overlay's opacity and has nothing to do with where the bar is.
    //
    // The two are not two tunings of one mechanism, which is why neither can be asserted
    // as the other. A DISPLACEMENT's wake is a fraction of its travel; a SWEEP's wake is
    // proportional to the head's SPEED, because speed is all a lag can know. Different
    // laws, so the suite samples them with two separate instruments.
    //
    // `head > tail` is a downward journey, and the wake trails above the head; upward, the
    // head leads and the wake trails below. `Math.min` agrees with both at a wake of zero,
    // so the direction cannot introduce a step of its own.
    readonly property real _wake: Math.abs(_headY - _tailY)
    readonly property real _barTop: Math.min(_headY, _tailY) - strip.scrollOffset
    readonly property real _barLength: indicatorLength + _wake

    readonly property bool hasTarget: focusedRowIndex >= 0
            && activeColumn
            && focusedRowIndex < activeColumn.rows.length

    // The two ends AT REST, and they are `Workspaces.qml`'s two ends: the head on
    // `medium`/OutQuad, the tail on `slow * 2`/OutSine - three times the head's flight,
    // which is what makes the stretch readable rather than a blur. Both are gated on the
    // same terms and both are handed to a SINGLE committed target, so neither can be
    // re-targeted per frame.
    //
    // A `Behavior` really is the wrong tool for a target that moves every frame, and that
    // was measured rather than assumed: re-assigning one every frame restarts its easing
    // every frame, and an easing that has just started is at the beginning of its curve.
    // `OutSine` covered `sin(0.033 * PI/2)`, about 5% of the gap, on the first tick of a
    // 480ms flight, so the tail sat at exactly 60.0 for nineteen consecutive frames of a
    // switch while the head ran from 137 to 196 - frozen, and the bar's length was the
    // head's motion alone. That is why a crossing uses the follower below instead of
    // these two, and it is not a reason for these two to be wrong at rest: at rest the
    // target moves ONCE, which is the one thing a `Behavior` is for.
    //
    // `!_markerCrossing` on both gates is the handover between the two mechanisms, and it
    // has to be `enabled` rather than only `_snapping`: setting a `Behavior`'s `enabled`
    // false stops an animation already in flight, while `_snapping` only prevents a new one
    // from starting. Without it, a focus glide that was still running when a switch was
    // published would keep writing one of the two ends every tick underneath the pin, which
    // is the frozen-tail fault arriving through the other door.
    //
    // The recipes are exposed, because "the hint's tail runs the widget's tail" is a claim
    // about numbers and a suite that re-read `MotionTokens` would only be checking that a
    // token exists somewhere in the file. Both are asserted, including the two-speed ratio
    // that makes the shape the widget's rather than merely similar - and both are claimed
    // of the AT REST mechanism only. During a crossing neither of these animations runs at
    // all; the number that governs the bar then is `trailCatchUp`.
    readonly property alias indicatorHeadMotion: indicatorHeadAnimation
    readonly property alias indicatorTailMotion: indicatorTailAnimation

    // How much of its gap the trail's tail closes per FRAME while the frame is travelling,
    // and the only number that sets the wake during a crossing. Per frame and not per
    // millisecond because the pin runs from `onCrossingTopChanged` - once per frame of the
    // journey - so a frame is this mechanism's tick, and a rate per millisecond would be a
    // second number to keep true of a clock this file does not own.
    //
    // A follower at rate k lags a head moving d px per frame by exactly d/k, so the wake IS
    // the head's own per-frame travel divided by this - the length of the shadow is how far
    // the thing moved, which is what a motion trail IS. Verified exactly, stepping the
    // marker's clock so each step is one tick of the follower: the wake settled at 24.0px
    // against a 16.8px step and at 21.3px against a 14.9px one, which is 16.8 / 0.7 and
    // 14.9 / 0.7 to a tenth of a pixel.
    //
    // There is therefore no way to make it short by choosing k: at k = 1 the tail is one
    // tick behind and the shortest wake this mechanism can produce is one frame of the
    // head's own travel.
    //
    // The number that came first was 0.12, a 131ms time constant, which put the wake at 2.5
    // times the head's travel - 333px at the fastest point of a sweep, thirteen times the
    // bar's resting length, and the plateau the report calls 异常地长.
    //
    // CHOSEN FROM THE MEASURED WAKE, and the instrument had to be the pin's own clock to
    // measure it: `_followJourney` runs from `onCrossingTopChanged`, so it runs once per
    // frame of the journey, and a 16ms wall-clock sample cannot resolve that - in this
    // environment one such sample spans several frames of it, a 320ms crossing finishing in
    // thirteen of them. So the sweep's own travel range and the wake it produces at this
    // rate:
    //
    //   the frame's per-frame travel      16.8px (departure) .. 42px (at InOutQuad's peak)
    //   the wake at 0.7                   24px           .. 60px
    //   the wake at 0.4                   42px           .. 105px
    //   the wake at 0.85                  20px           .. 49px
    //
    // 0.7 against a 26px resting bar is a trail: barely longer than the bar at rest on a
    // switch's calmer half and two and a quarter times it where the frame is moving fastest,
    // which is the workspace widget's own proportion on a real switch (148.9px of wake on a
    // 26px bar). 0.4's 105px is a second bar. The time constant that goes with 0.7 is one
    // frame over the rate, 16ms / 0.7 = 23ms.
    readonly property real trailCatchUp: 0.7

    // `_snapping` is the load-bearing gate on both of these, and it is a
    // property rather than anything about the crossing, so a `Behavior` sees it at the
    // moment the property CHANGES - which is what a write inside `_snapIndicator` needs
    // and a flag read inside `_syncIndicator` would arrive a step too late for.
    Behavior on _headY {
        enabled: root._placed && !root._markerCrossing
            && !MotionTokens.reducedMotion && !root._snapping
        NumberAnimation {
            id: indicatorHeadAnimation
            duration: MotionTokens.medium * debugTimeScale
            easing.type: Easing.OutQuad
        }
    }
    // Three times the head's flight: the tail lingers long after the head lands, and that
    // lingering is the stretch. Its recipe is the widget's verbatim, which is why the wake
    // is worth measuring rather than tuning - a fixed point gives this curve a fixed shape.
    Behavior on _tailY {
        enabled: root._placed && !root._markerCrossing
            && !MotionTokens.reducedMotion && !root._snapping
        NumberAnimation {
            id: indicatorTailAnimation
            duration: MotionTokens.slow * 2 * debugTimeScale
            easing.type: Easing.OutSine
        }
    }

    // Where the bar belongs while the frame is travelling: on the frame, in the bar's own
    // length, in the tracker's UNSCROLLED coordinates like every other target -
    // `_targetYFor` is pre-scroll too, and `_barTop` subtracts the offset back out.
    //
    // A FUNCTION and not a `readonly` property, which is the trap this file has paid for
    // twice. A property's binding is re-evaluated when its dependencies change, and
    // nothing orders that before the `onCrossingTopChanged` handler that reads it - so the
    // handler is handed the PREVIOUS frame's target and the head trails the frame by exactly
    // one frame, for the whole journey. Measured across a crossing at quarters: `journeyY`
    // ran 69, 118.5, -42, -20.5, 1 while the head ran 74, 69, 118.5, -42, -20.5 - the same
    // series, one step behind, throughout. A function is evaluated on the call, so it can
    // only ever be current.
    function _journeyTarget() {
        return root.crossingTop + root.markerOffset + strip.scrollOffset
    }

    // The scroll offset the trail's coordinates are currently expressed against.
    //
    // The pin has to carry `scrollOffset` in its target - `_barTop` subtracts it on the way
    // out - and a crossing can CHANGE it, because publishing one rebuilds the strip with
    // the arriving column's own scroll. Measured: a twelve-window workspace focused on row
    // 9 sits at a scroll offset of 170, and switching into a workspace focused on row 1
    // drops it to 0. So the head's stored value gains or loses the whole difference while
    // the tail's does not, and a wake measured on the two would be reporting a scroll rather
    // than a lag: 170px of trail on the crossing's first frame, out of nothing.
    //
    // Both ends are therefore re-based together, by the same amount, on the tick the scroll
    // moves. The drawn bar does not move - which is the point: only the wake's frame of
    // reference changes.
    property real _journeyScroll: 0
    // The head's own last pinned position, and whether there has been one yet. The pin
    // needs both to tell a DISCONTINUITY in the frame's position from fast motion, which is
    // what the trail must not follow. See the note in `_followJourney`.
    property real _pinHead: 0
    property bool _pinArmed: false

    // Hand the tracker to the crossing, and give the trail its follower - in one function,
    // on one clock.
    //
    // The head SNAPS to the frame's position and the tail closes `trailCatchUp` of what is
    // left, and the asymmetry is the design rather than an inconsistency. The head has to be
    // the frame: the bar stays one `markerOffset` below the outline for the whole journey or
    // the two stop being one gesture, and an easing chasing a target that moves every frame
    // is always behind it - a lag, not a lead. The tail then has nothing to chase but the
    // head, so it trails by the head's own speed times `trailCatchUp`'s time constant.
    //
    // BOTH WRITES ARE IN HERE RATHER THAN THE TAIL'S IN A TIMER, and the reason is that
    // there is only one clock in a crossing: the frame's. A separate 16ms timer would have
    // its own tick, and two clocks means the tail's rate is multiplied by however much
    // faster the frame is drawn than the timer fires - which is exactly what the frozen
    // 60.0 was, before the two were on one clock.
    //
    // `_anchorY` is NOT written. The committed target stays the landing row, because that is
    // what `_syncIndicator` maintains during the crossing, what the landing dedupes against,
    // and what makes `_closeTrail` a re-aim rather than a second retarget.
    function _followJourney() {
        // The pin only writes while it is in charge. `crossingTop` is a function of the
        // clock AND of the focused row, so a reveal scroll moves it after the flag is down -
        // and a pin that keeps writing then is a third mechanism, fighting the two the file
        // means to have. See the measured shape at the note on `onCrossingTopChanged`.
        if (!root._markerCrossing) {
            _pinArmed = false
            return
        }
        const target = root._journeyTarget()
        if (!isFinite(target))
            return
        // Re-base BOTH ends before the head is written, so the wake is measured in one
        // frame of reference. See `_journeyScroll`.
        const scroll = strip.scrollOffset
        if (_journeyScroll !== scroll) {
            _tailY += scroll - _journeyScroll
            _journeyScroll = scroll
        }
        // THE DISCONTINUITY, and the one predicate that catches every one of them.
        //
        // At the corner the frame does not move fast, it TELEPORTS: `crossingTop` jumps
        // from `exitTo` to `crossingFrom`, the panel's whole height plus a card at each end,
        // in one tick. A follower reads that as speed, and speed is the only thing it can
        // read - a gap is the head's travel, and 244px of travel in a tick asks for a 244px
        // trail. Measured with the corner left to the follower: the wake opened to 99.9px at
        // the corner of a twelve-row switch, from a steady 23-29px either side of it, and
        // three crossings in a row each produced a 113.9, 116.5 and 114.8px spike - a 140px
        // green bar in the middle of a panel whose resting bar is 26px.
        //
        // It is not a bound, and that is the whole point: the trail is not being shortened,
        // it is being CARRIED. The head crosses the panel and the trail crosses with it,
        // keeping the length it had. The corner is off-panel by construction - `_offTop`
        // and `_offBottom` are a whole card past each edge - which is what "the position
        // discontinuity is the one thing never on screen" is for, and a trail that opened
        // for a teleport is visible precisely because it is enormous.
        //
        // THE PREDICATE IS THE SIGN OF THE STEP, and it is the sign because the journey's
        // direction is a fact rather than a threshold. `_journeyDirection` is captured once
        // per journey and deliberately not recaptured by a re-aim, so a downward sweep's
        // head can only ever INCREASE and an upward one's can only ever DECREASE; any step
        // against that is a discontinuity and not motion. Measured, it catches two that a
        // leg-flip test would each miss differently: the corner itself, and a layout blip
        // where `_offBottom` - which is the panel's own live height - momentarily collapsed
        // while the arriving column rebuilt, taking the frame's target from 193.5 to 62.6
        // and back on one frame. Both are the same fault in the pin's terms: a step the
        // frame's own motion cannot produce.
        //
        // A zero step is not a corner, and deliberately: the frame is stationary wherever
        // the journey degenerates (no departing row, an empty arriving workspace), and a
        // trail that had nothing to follow must not be re-based on it.
        const step = target - _pinHead
        if (_pinArmed && step * root._journeyDirection < 0)
            _tailY += step
        else if (Math.abs(_headY - _tailY) < 0.5)
            _tailY = target
        else
            _tailY += (_headY - _tailY) * trailCatchUp
        _pinArmed = true
        _pinHead = target
        _snapping = true
        _headY = target
        _snapping = false
    }

    // The crossing's other end: hand BOTH ends back to the widget's own curves once the
    // frame has landed.
    //
    // Deferred a turn, and the deferral is load-bearing. A `Behavior` captures its target
    // when its `enabled` goes true, so a write made in the same turn as the flag would be
    // made while the `Behavior` is still disabled - and a write to a disabled `Behavior`'s
    // property is a positional snap, which is a cut of exactly the width the follower left.
    // By the next turn `enabled` has been re-evaluated and each assignment is a re-aim: the
    // `Behavior` takes its `from` from wherever the pin and the follower stopped and eases
    // home, the tail on `slow * 2`/OutSine and the head on `medium`/OutQuad - which are the
    // widget's own closing curve and its own arrival.
    //
    // THE HEAD IS WRITTEN TOO, and that is not tidiness. On a landing the pin's last write
    // already left the head ON `_anchorY` - the frame lands on the card and the journey
    // target is that card - so re-assigning the same value starts nothing, and the call is a
    // no-op on every crossing that ends the way it is meant to. It is the CANCELLED crossing
    // that needs it, and it needs it badly: `_commitHint` clears `_markerCrossing` to stop a
    // journey that never showed the marker travelling, which abandons the head wherever the
    // frame had got to, and nothing else ever writes it again. Measured on a switch to row 0
    // out of row 2, interrupted by the next publish: the head was stranded at 136.8 against a
    // committed target of 307.0, the tail at 75.7, and 90 ticks of `settleBar`'s wait could
    // not close a 61px gap that no animation was ever asked to close - the bar sat stretched
    // across two rows it was never on, for good.
    //
    // It also fires when the follower already converged and both ends are home, which is the
    // whole of a switch that did not travel: no spurious flight from a gap that is not there.
    function _closeTrail() {
        if (_markerCrossing || !_placed)
            return
        _headY = _anchorY
        _tailY = _anchorY
    }

    // Commit head and tail together with the Behaviors suppressed. Both writes use
    // a precomputed target: reading _headY back would return the animation frame,
    // not the committed value.
    //
    // NEVER DURING A CROSSING, and the pin is what stops it: `_syncIndicator` returns
    // before it can reach here while `_markerCrossing` is set, so a journey's ends are
    // only ever written by `_followJourney`. The comment above the two `Behavior`s records
    // why the flag has to gate on `enabled` rather than on `_snapping` alone - `_snapping`
    // cannot end an animation already in flight, and these two are declared inside
    // `Behavior` blocks, so they are not root nodes and `stop()` on them warns and does
    // nothing.
    function _snapIndicator(top) {
        _snapping = true
        _anchorY = top
        _headY = top
        _tailY = top
        _snapping = false
    }

    // Route every re-anchor through here, which is `Workspaces.qml`'s `retargetEdges`
    // with the numbers renamed: a genuine target switch commits the anchor, desyncs the
    // two ends into the wake and blinks once; same-target layout drift snaps both so
    // content churn never stretches the bar; the first placement snaps so it never slides
    // in from zero.
    //
    // The commit writes BOTH ends to the target, and that is not a contradiction of the
    // wake: a `Behavior` animates from the value the property holds when the write
    // arrives, so each end flies from wherever it actually was to the one place they now
    // share. Writing them is how the widget says "these two are aimed at one target", and
    // it is why a switch arriving mid-wake continues the wake instead of cutting it -
    // there is nothing here that can shorten the bar, only retarget it.
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

    // Apply a drift that landed mid-trail, once the tail has caught up. The widget's
    // `_edgePendingCenterX` timer, and for the same reason: it waits on the TAIL rather
    // than on a duration, so a trail is never cut short by the wait's own length.
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
            NumberAnimation {
                id: focusFrameGlide
                duration: MotionTokens.settingsSidebarCollapse * debugTimeScale
                easing.type: Easing.OutQuint
            }
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
    // On a workspace SWITCH this same instance is what moves, and it moves with the OUTLINE
    // rather than to the row: the outline sweeps the panel's whole height and the bar is
    // pinned to it one `markerOffset` below, with a trail behind, for the whole journey.
    //
    // It used to be aimed at the landing row instead, which is `Workspaces`' answer for its
    // own indicator on a DISPLACEMENT - and it was wrong for this one for a reason the
    // widget's never has to face: this frame does not slide between two squares, it leaves
    // the panel on both legs and re-enters through the opposite edge. So the widget's
    // arrival on a new square is a fixed point and this frame's is not, and a bar aimed at
    // a fixed point that a sweep passes through twice has nowhere to go. Measured with the
    // bar aimed at the row and the frame sweeping: the bar's top read 137.0 on all 60
    // samples and its wake 0.0 on all 60, while the frame ran 139.3, 146.7, 160.4, 178.9,
    // 190.1, -38.6, 40.3, 60.4, 83.1, 101.7, 126.4, 134.6 and landed on 136.
    //
    // The second thing the pin buys is that the bar's COLUMN now changes while the bar is
    // off the panel, so the crossing's own horizontal discontinuity is invisible with it.
    // Un-pinned, the bar sat on the landing row through the corner and its x ran 119.7,
    // 92.7, 72.2, 36.8, 23.4, 14.1, 9.2, then 194.0 - a 185px step in one frame, at a y
    // that never moved.
    //
    // So the two are ONE motion on purpose, and `Workspaces` is the precedent rather than
    // the exception: its indicator and its `activeHighlight` are aimed at the same square
    // and stretch as one gesture, and this panel is that widget magnified with a tall frame
    // in place of a square.
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
        // The tracker's two ends, ALWAYS - and on a switch that means the two ends of a TRAIL
        // behind the frame, not two ends easing onto a row: the stretch is the bar's own
        // dual-speed motion, on a workspace switch as much as on a focus change inside one
        // workspace, and it is drawn from the LOWER of the two through the higher -
        // `Workspaces.qml`'s `_edgeRectLeft` and `_edgeSpan` read down a column instead of
        // across a row.
        //
        // It was `crossingTop + markerOffset` at a fixed `indicatorLength` for the whole
        // crossing, and then the tracker's two ends at the landing row. Both were one
        // motion each and neither is: the first had no trail at all, and the second had a
        // trail that could not open, because two workspaces focused on the same row are the
        // same target. This is `_barTop` from a head that is pinned to the frame, so the
        // bar is the outline's own lower edge all the way across and the length is the
        // trail. See the indicator section at the top.
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
    //
    // NO SCROLL HOOK, and the reason is worth recording because there was one here for a
    // whole round. AT REST the tracker's target is `_targetYFor(index)`, which is in the
    // column's UNSCROLLED space, so a scroll does not move it: the bar is drawn in scrolled
    // space by `_barTop`, which subtracts the offset on the way out. The retarget a scroll
    // used to trigger therefore always passed the target the tracker already held and always
    // deduped - it existed only to re-add the scroll to a journey target derived from
    // `crossingTop`, and that derivation is gone and then came back. A scroll that DOES move
    // the bar is one that reveals a different row, and that arrives as a different
    // `focusedRowIndex`.
    //
    // DURING A CROSSING the pin's target is `crossingTop + markerOffset + scrollOffset`, so
    // a scroll does move it - and it moves BOTH ends, by the same amount, on the same tick.
    // See `_journeyScroll`, which is the whole of why a scroll during a crossing is not
    // `trailCatchUp` seconds of travel the follower has to make up for.

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

    // The tracker's one entry point, and it routes the two mechanisms by asking which one
    // is running. A crossing owns the POSITION and this routine only maintains the
    // bookkeeping the landing needs; everything else is the widget's pair, aimed at the
    // FOCUSED ROW.
    //
    // The crossing branch is the conflict named at the top of the indicator section, and it
    // is placed before the `!hasTarget` branch deliberately: a switch into an empty
    // workspace has no focused row, and taking the no-target branch there would snap both
    // ends to the off-panel parking position on the switch's own first frame - a cut of
    // exactly the width the trail had reached, at the exact instant the frame is leaving the
    // panel. The arrival leg of such a crossing is out of sight anyway (`markerHasTarget` is
    // false and the frame is off the top), so the bar's own hidden state needs no
    // bookkeeping; the committed target and the identity are what the landing reads.
    function _syncIndicator() {
        var target = root._restingY()
        if (root._markerCrossing) {
            root._pendingTop = -1
            if (root._placed && root.focusedWindowKey !== root._targetKey) {
                _targetKey = root.focusedWindowKey
                _flashIndicator.restart()
            }
            root._anchorY = target
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
            root._targetKey = root.focusedWindowKey
            root._snapIndicator(target)
            return
        }
        root._retargetIndicator(target, root.focusedWindowKey)
    }

    onFocusedRowIndexChanged: {
        // The tracker waits a turn, and the ordering is why. `_syncIndicator` reads
        // `hasTarget` and `focusedRowIndex`, both of which are derived from `activeColumn`
        // and `plan`; a change handler runs as soon as its own property is notified, which
        // is before the bindings depending on it have necessarily been recomputed, so
        // taking it at face value can hand the routine the previous frame's answer. A
        // `Behavior` then animates FROM that, and the bar lands a frame behind the window
        // it is marking. One turn is enough because everything that decides it - the plan,
        // `swapping`, `_markerCrossing` - is set synchronously inside the same publish.
        Qt.callLater(_syncIndicator)
        _revealFocusedRow()
    }
    // The OTHER hook, and the one that makes a switch between two workspaces focused on
    // the same row reach the tracker at all. `focusedRowIndex` does not move in that case,
    // so the hook above never fires and nothing would run - which used to mean no commit, no
    // blink and no stretch, three of the widget's four responses missing at once. It is still
    // what carries the BLINK there, since a change of identity is what blinks and the row
    // index is not it; the position itself no longer depends on this hook, because a switch
    // that changes nothing about the row is driven by the crossing's own pin. Keyed on the
    // window, `focusedWindowKey` moves, and the one routine runs. Both hooks call it; the
    // second is a no-op when the first already ran.
    onFocusedWindowKeyChanged: Qt.callLater(_syncIndicator)
    onHasTargetChanged: _syncIndicator()

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
