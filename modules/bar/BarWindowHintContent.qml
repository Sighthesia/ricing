import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic

// Body of the mod-key window hint: a strip of the workspaces around the one you
// are on. Rendered inside the bar's popup, so it reuses the popup's surface
// colors, section fill and shared reveal instead of owning a surface of its own.
//
// A workspace switch is a WHOLE-BODY displacement: the strip travels by exactly
// as many columns as the workspace moved, once, without turning back, and it
// carries BOTH frames with it. The panel is a three-column window onto the strip;
// the strip is `span + 3` columns wide, so while it travels there is always a full
// panel's worth of it under the window and the panel is never less than covered.
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
// left. Both travel WITH the strip, so the marker and the row it marks cross
// together.
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
    property real slideProgress: 1
    property bool swapping: slideProgress < 1

    // The geometry of the crossing in flight, from `HintLogic.stripPlan`, or null
    // at rest. The strip's own offset, the number of columns it is drawn with and
    // the slot the active workspace occupies are all read off this one record, so
    // the three cannot describe different crossings.
    property var plan: null

    readonly property bool ready: root.shownReady
    // Three columns of one fixed width, always. The count does not vary with the
    // content: the active workspace sits in the middle, and it can only stay in the
    // middle if the frame around it is the same size whatever the neighbours are
    // running. It also means the panel does not resize under the pointer as the
    // user moves between an interior workspace and an edge one.
    readonly property int columnWidth: HintLogic.COLUMN_WIDTH
    // Gap between the three columns, and the pitch it produces. `inlineGap` is the
    // bar's workspace widget's own spacing between its squares - see
    // `BarWindowHintStrip.columnGutter` for why the panel needs one.
    readonly property int columnGutter: LazerTheme.inlineGap
    readonly property int columnPitch: columnWidth + columnGutter
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
    // The band's radius: square, like the widget's hover highlight and its active
    // highlight - both are `radius: 0`. A rounded band was tried and read as a slot
    // floating over the panel rather than as the column itself; the design language
    // keeps rounding for component details, and a full-height column band is a band.
    readonly property int bandRadius: 0
    // How far the band swells at the middle of a crossing, as a share of its size.
    // 2% is about 3.6px across a 180px column, which reads as a pulse rather than as
    // a zoom, and stays inside the 6px gutter at either side so it never touches a
    // neighbour's cards.
    readonly property real bandPulse: 0.02
    // Where the band sits: the panel's middle column, always.
    //
    // The active workspace's column is ALWAYS the panel's middle one - the strip
    // travels precisely so that the arriving active column lands there. So the band
    // has no reason to move, and moving it is what broke it twice: glued to the
    // strip's active SLOT it teleported a whole column at the start of a crossing and
    // had to slide back (measured: 161px in one frame), and given a clock of its own
    // it jumped at the end instead, because the body snaps the strip's offset there.
    //
    // Anchored to the panel, both jumps are impossible - there is nothing to be out of
    // step with. The crossing is expressed by the band swelling on the crossing's own
    // progress, which is a pure function of the one clock.
    readonly property real bandX: columnPitch
    readonly property real bandScale: 1
        + Math.sin(Math.PI * slideProgress) * bandPulse
    readonly property int shownColumnCount: HintLogic.COLUMN_COUNT
    // Where the strip's travel starts and ends, in pixels, and the offset as a
    // function of the one clock. Computed rather than animated per layer because
    // there is one object moving: the strip.
    //
    // At progress q the strip's offset is `slideFrom + (slideTo - slideFrom) * q`,
    // and the plan's start and end are the offsets at which the active workspace
    // sits in the panel's middle column - at both ends, by construction, so neither
    // direction needs a case.
    property real slideFrom: 0
    property real slideTo: 0
    readonly property real slideOffset: slideFrom
        + (slideTo - slideFrom) * slideProgress
    // How far the strip dims at the middle of the crossing, 0 at either end.
    //
    // A translation has no weight of its own: nothing about the content changes, so
    // the panel slides rather than moves. A small dip gives it some, and it is safe
    // here precisely because there is only one copy to dim - with two, they would
    // have to dim together or the seam would show one through the other. Shallow on
    // purpose: enough to register, far too little to read as a fade.
    readonly property real slideDip: Math.sin(Math.PI * slideProgress) * 0.12
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
    readonly property alias indicatorHeadMotion: indicatorHeadAnimation
    readonly property alias indicatorTailMotion: indicatorTailAnimation
    readonly property int rowHeight: 28
    // The one row the focus indicator belongs to, or -1. Read from the ARRIVING
    // active column, which is the content the user is being taken to.
    readonly property var activeColumn: root.plan
        ? root.columns[root.plan.activeSlot] : null
    // The plan's slot count as a width, for the strip. Always derivable: the
    // resting plan is three columns and a crossing's is its span plus three.
    readonly property int stripWidth: root.plan
        ? root.plan.slots * root.columnPitch - root.columnGutter : 0
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
    // Top edge of the focused row, 0 when there is none. One source of truth for
    // both markers below, so the frame and the indicator can never disagree about
    // which row is current.
    // Top edge of the focused row, in the strip's space. The cards start at the
    // strip's own top - the band is what sits a padding above them, not the cards -
    // so this carries no padding term. It did, briefly, and put the row highlight a
    // whole padding below the card it is drawn over.
    readonly property real focusedRowTop: focusedRowIndex < 0 ? 0
        : focusedRowIndex * rowPitch
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
        return rows.length * root.rowPitch - root.listSpacing
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
        if (direction === 0) {
            root._lastFrame = root.hint
            return root.swapping ? root._replaceArriving() : root._commitHint()
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
        root.slideFrom = 0
        root.slideTo = 0
        // A rest plan rather than no plan: the strip still needs to be drawn, and
        // this is the one that says "three columns, active slot 1, offset 0" - the
        // same shape the crossing's plan has, so every binding downstream can be
        // written once. See `HintLogic.restPlan`.
        root.plan = HintLogic.restPlan(root.hint)
        root.columns = HintLogic.stripColumns(root.hint, null, root.plan)
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
        root.plan = plan
        root.columns = HintLogic.stripColumns(root.hint, root.leavingHint, plan)
        root.shownReady = HintLogic.ready(root.hint)
        root.slideFrom = plan.startColumn * root.columnPitch
        root.slideTo = plan.endColumn * root.columnPitch
        root.slideProgress = 0
        slideRun.restart()
    }

    // A second switch arrived mid-crossing. The strip must CONTINUE from where it
    // is: re-aiming it to the new plan's own start offset would throw the content
    // back to the edge of the panel, which is a visible jump rather than a
    // correction.
    //
    // The compensation is `stripReshift`. A second move in the SAME direction only
    // extends the union at the right, so the strip's existing slots keep their
    // numbers and no correction is needed - the new plan's base equals the old
    // one's and the strip simply continues. A move in the OTHER direction extends
    // the union at the LEFT, which renumbers every column the strip already holds;
    // shifting the strip left by exactly that many columns puts the content back
    // where it was, so the reversal is a re-aim of the motion in progress and not
    // a rearrangement of what is on screen.
    function _reaimSlide(plan) {
        const reshift = HintLogic.stripReshift(root.plan, plan)
        // The offset the strip is AT right now, before the plan is replaced. Read
        // from the clock rather than from the incoming plan, or the reshift is
        // computed against a position the strip was never in.
        const here = root.slideFrom
            + (root.slideTo - root.slideFrom) * root.slideProgress
        root.plan = plan
        root.columns = HintLogic.stripColumns(root.hint, root.leavingHint, plan)
        root.shownReady = HintLogic.ready(root.hint)
        root.slideFrom = here - reshift * root.columnPitch
        root.slideTo = plan.endColumn * root.columnPitch
        // Restart the clock from the current offset, not from the crossing's own
        // start: the re-aim is a new traverse over the remaining distance, and
        // beginning it at 0 while the strip is already halfway across would jump.
        root.slideProgress = 0
        slideRun.restart()
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
        duration: MotionTokens.medium
        easing.type: Easing.OutQuad
        onFinished: {
            // The strip has landed with the arriving frame's active column in the
            // middle, so the held frame goes with it and exactly one set of rows
            // stays alive. The strip also narrows to the arriving frame's own three
            // columns, and the offset returns to 0 to match: the resting plan says
            // the active column is slot 1, which is the panel's middle column only
            // at offset 0.
            //
            // Both are needed together. Narrowing the strip while the offset is
            // still the crossing's end leaves the last two columns of the panel
            // empty - the strip is three columns wide and sitting one column to the
            // left, so it covers [0, 2C) and nothing else. Measured on the first
            // run of this change: the final sample of every forward crossing had an
            // unreached panel edge for exactly that reason.
            root.leavingHint = null
            root.plan = HintLogic.restPlan(root.hint)
            root.columns = HintLogic.stripColumns(root.hint, null, root.plan)
            root.slideFrom = 0
            root.slideTo = 0
            root.slideProgress = 1
        }
    }

    onHintChanged: _onHintChanged()

    readonly property real _barTop: Math.min(_headY, _tailY)
    readonly property real _barLength: indicatorLength + Math.abs(_headY - _tailY)
    readonly property bool hasTarget: focusedRowIndex >= 0
            && activeColumn
            && focusedRowIndex < activeColumn.rows.length

    Behavior on _headY {
        enabled: root._placed && !MotionTokens.reducedMotion && !root._snapping
        NumberAnimation {
            id: indicatorHeadAnimation
            duration: MotionTokens.medium
            easing.type: Easing.OutQuad
        }
    }
    Behavior on _tailY {
        enabled: root._placed && !MotionTokens.reducedMotion && !root._snapping
        // 3x the head's flight: the tail lingers long after the head lands, which
        // is what keeps the stretch readable.
        NumberAnimation {
            id: indicatorTailAnimation
            duration: MotionTokens.slow * 2
            easing.type: Easing.OutSine
        }
    }

    // Commit head and tail together with the Behaviors suppressed. Both writes use
    // a precomputed target: reading _headY back would return the animation frame,
    // not the committed value.
    function _snapIndicator(top) {
        _snapping = true
        _anchorY = top
        _headY = top
        _tailY = top
        _snapping = false
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

    // Three columns, always. The popup measures its geometry from this, so the
    // host's `window-hint` width reads the body rather than keeping its own number
    // - and the body reports the same number whether the neighbour workspaces are
    // busy or empty, so the panel never changes size mid-hold.
    //
    // The clip is what keeps the rest of the strip off the surface. A crossing
    // carries `span + 3` columns through a three-column window, so up to three
    // extra columns are travelling through the panel, and without a clip here they
    // would paint outside the popup's own rect - and outside the layer-shell input
    // region the host sized from this body's width.
    clip: true
    implicitWidth: shownColumnCount * columnPitch - columnGutter
    // The taller of the two frames while a crossing is in flight, and the strip's
    // own height once it has landed. The empty-workspace placeholder lives inside
    // the columns, so the columns' own height already accounts for it.
    // The card block, plus the band's own padding, less whatever the band covers
    // beyond this body's edges by reaching for the surface. With no host inset that is
    // the block plus its padding; with one it shrinks, because the band is already
    // covering ground the body does not own.
    implicitHeight: ready
        ? Math.max(root._outgoingHeight, strip.contentHeight)
            + cellPaddingY * 2 - bandOutset * 2
        : emptyText.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // The strip. One object, carrying both frames, translated by the one clock. Its
    // width is the whole run of workspaces; the panel is the three-column window
    // onto it, and `clip` on the body is what keeps the rest of the run off the
    // surface.
    // The active workspace's cell. The bar's `Workspaces.qml` draws that as one
    // rectangle behind the squares - `activeHighlight`, covering the square exactly -
    // and this is the same surface one size up, in the same token, with the same
    // geometry: the cell, whose edges are the panel's edges, with the cards sitting
    // `cellPaddingX` inside it.
    //
    // A child of the BODY, not of the strip. The strip travels and its active slot
    // moves; the band does not, because the column you are looking at does not - so
    // making it a strip child is what put a 161px teleport at the start of every
    // crossing.
    Rectangle {
        id: activeBand
        objectName: "windowHintColumnHighlight"
        // `bandInset` from the SURFACE, so `bandInset - surfaceInset` from the body -
        // negative when the popup insets its content column, which is what puts the
        // band's edge near the panel's edge the way the widget's sits near the bar's.
        y: root.bandInset - root.surfaceInset
        x: root.bandX
        width: root.columnWidth
        // The cell, not the card block: the cards sit `cellPaddingY` inside the band's
        // top and bottom edges, so the band is the block plus that padding on each side.
        height: Math.max(0, strip.contentHeight + cellPaddingY * 2)
        radius: root.bandRadius
        color: LazerTheme.activeFill
        // The crossing's own progress, so the pulse cannot drift from the slide: one
        // clock, no second animation to fall behind.
        scale: root.bandScale
        visible: root.ready && strip.contentHeight > 0
        // Inert to input: under the pointer this is decoration, and a surface that
        // swallows taps meant for the cards would be a fault the user only finds by
        // missing a click.
        enabled: false
    }

    BarWindowHintStrip {
        id: strip
        objectName: "windowHintStrip"
        parent: root
        // The strip's own offset. At rest it sits at 0 - the plan's end, with the
        // active column in the panel's middle - and during a crossing it is
        // somewhere between the plan's start and end.
        x: root.slideOffset
        // A padding down from the panel's top edge, and correspondingly shorter than
        // the panel: the strip is the card block, and the padding belongs to the panel
        // around it. Sized from the panel it overran the bottom by a whole padding,
        // which put the band's bottom margin out of step with its top.
        y: root.bandInset - root.surfaceInset + root.cellPaddingY
        height: Math.max(0, root.height - cellPaddingY * 2 + bandOutset * 2)
        width: root.stripWidth
        // One object moving, so one dim. With two copies crossing this had to be
        // applied to both in lockstep or the seam would show one through the other;
        // with one strip there is no seam, and the value is a pure function of the
        // clock - the same progress always gives the same opacity.
        opacity: 1 - root.slideDip
        columns: root.columns
        // Read off the plan the strip was built from, so the column that carries
        // the card fill and the one the focus markers are placed against are the
        // same column by construction.
        activeSlot: root.plan ? root.plan.activeSlot : 1
        columnWidth: root.columnWidth
        columnGutter: root.columnGutter
        cellPaddingX: root.cellPaddingX
        // Read from the same `activeColumn` the strip's own columns come from, so the
        // row that tints and the row the outline glides onto are the same row by
        // construction rather than by two lookups agreeing.
        focusedRowIndex: root.focusedRowIndex
        listSpacing: root.listSpacing
        rowHeight: root.rowHeight
        glyphInset: root.glyphInset
        glyphWidth: root.glyphWidth
        interactive: !root.swapping
        onWindowActivated: windowId => root.windowActivated(windowId)
    }

    // One shared focus highlight for the whole list, the way the launcher's does: a
    // single element that glides to the current row instead of every row showing
    // and hiding its own.
    //
    // BORDER-ONLY, which is the launcher's arrangement and the reason the tint lives
    // in the row. This was a filled wash above the rows at z 5, the only way a
    // separate element could mark an opaque card - and `settingsSelected` is the
    // primary at a quarter alpha, so that wash veiled the icon and the title it was
    // meant to be pointing at. The fill moved into the row's own background, where
    // it sits UNDER the icon and the title as the row's children, and what glides
    // here is the outline around it. Exactly one element still carries the tint at a
    // time: the focused row's.
    //
    // A child of the strip, so it travels with the content it marks. Pinned to the
    // panel, it would say the focus stayed put while the window list moved - two
    // different claims about where the current window is.
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

        // Bounded by the row, not inset: the highlight has to cover exactly the row
        // it marks, and the row spans its column's full width. Measured from the
        // active column's own x, so it cannot be drawn over a column that is not
        // the active one whatever the layout decided.
        x: strip.activeColumnX + root.cellPaddingX
        y: root.focusedRowTop
        width: strip.cardWidth
        height: root.rowHeight
        opacity: root.hasTarget ? 1 : 0

        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
        Behavior on y {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint }
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
    Rectangle {
        id: focusUnderline
        objectName: "windowHintFocusIndicator"
        parent: strip
        z: 6

        width: root.indicatorThickness
        height: root._barLength
        radius: LazerTheme.barIndicatorRadius
        color: LazerTheme.osuGreen
        // Measured from the active column's own left edge - the band's edge, not the
        // card's - so the bar and the outline it marks always move together.
        x: strip.activeColumnX + root.indicatorInset
        y: root._barTop
        visible: root.hasTarget
        opacity: root.hasTarget ? 1 : 0

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
            duration: MotionTokens.clickFlashDuration
            easing.type: MotionTokens.clickFlashEasing
        }

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
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
    function _syncIndicator() {
        var target = root._targetYFor(root.focusedRowIndex)
        if (!root.hasTarget) {
            // No target: the bar is hidden, so it must not be left mid-trail either
            // - a trail still in flight when the next target arrives would stretch
            // out of the wrong place.
            root._pendingTop = -1
            root._snapIndicator(target)
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

    onFocusedRowIndexChanged: _syncIndicator()
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
