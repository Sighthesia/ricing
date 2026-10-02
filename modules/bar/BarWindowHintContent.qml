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
    // Where the head hands over to the tail, as a share of the traverse.
    //
    // Small on purpose. The head is the quick departure, so the temptation is to
    // let it carry most of the distance - and on a multi-column travel that reads
    // as a lunge, because the bulk of the movement lands in the first fifth of a
    // second and the rest crawls. Two tenths of the way is a departure; four tenths
    // is most of the motion, and the columns look like they are being thrown across
    // the panel rather than carried.
    readonly property real slideHeadShare: 0.4
    // The two clocks, carrying the indicator's two-speed SHAPE at a distance the
    // indicator's clocks were never asked to cover.
    //
    // `medium` / `slow * 2` is right for the indicator because the indicator has to
    // cover sixteen pixels: its head really can put the bar there in 160ms. The
    // strip covers a few columns rather than the panel's whole width, and 160ms of
    // departure followed by 480ms of settle is the same proportion the indicator
    // uses for its much shorter travel - so the SHAPE is shared without the clocks
    // being copied blind. The two stay in the indicator's proportions: the tail is
    // three times the head, so the arrival keeps lingering after the departure has
    // finished.
    readonly property int slideHeadDuration: MotionTokens.medium
    readonly property int slideTailDuration: MotionTokens.slow * 2
    // Both phases, for anything that has to wait the crossing out.
    readonly property int slideDuration: slideHeadDuration + slideTailDuration
    // The crossing's own recipe, and the indicator's, so a suite can compare the
    // two. A test that reads `MotionTokens.slow > MotionTokens.fast` instead checks
    // that two numbers exist somewhere in the file, not that the crossing runs on
    // them - which is exactly the mistake a retune would reintroduce, and which one
    // already had.
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
        ? root.plan.slots * root.columnWidth : 0
    readonly property int focusedRowIndex: HintLogic.focusedIndexIn(
        root.activeColumn ? root.activeColumn.rows : null)
    // Left inset of a row's glyph, shared by the icon and the title so both start
    // on the same x - and derived from the indicator rather than a literal, so the
    // gutter between the marker and the glyph cannot drift when either moves. The
    // indicator sits at the highlight's own edge, so the row needs a real left
    // margin: without it the bar ends 1px before the icon begins.
    readonly property int indicatorInset: 4
    readonly property int indicatorThickness: LazerTheme.barIndicatorHeight
    readonly property int indicatorGutter: 12
    readonly property int glyphInset: indicatorInset + indicatorThickness + indicatorGutter
    readonly property int glyphWidth: 16
    // Vertical pitch of the list: a row plus the Column's gap. The indicator is
    // positioned from this, so it has to agree with the Column's own spacing
    // exactly - asserted against a real row's bottom edge in the suite.
    readonly property int rowPitch: rowHeight + listSpacing
    readonly property int listSpacing: 6
    // Top edge of the focused row, 0 when there is none. One source of truth for
    // both markers below, so the frame and the indicator can never disagree about
    // which row is current.
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
    // The workspace indicator is a 16x3 bar travelling sideways, so its head/tail
    // stretch lengthens it along its own long axis and it stays a bar. This list
    // runs down a column, so the indicator is a 3x16 bar travelling downward: same
    // tokens, same tracker, same formula, rotated 90 degrees. Stretching the WRONG
    // axis would have turned a 3px bar into a tall rectangle mid-flight, which is a
    // shape change rather than a bar growing.
    readonly property int indicatorLength: 16

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
        root.slideFrom = plan.startColumn * root.columnWidth
        root.slideTo = plan.endColumn * root.columnWidth
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
        root.slideFrom = here - reshift * root.columnWidth
        root.slideTo = plan.endColumn * root.columnWidth
        // Restart the clock from the current offset, not from the crossing's own
        // start: the re-aim is a new traverse over the remaining distance, and
        // beginning it at 0 while the strip is already halfway across would jump.
        root.slideProgress = 0
        slideRun.restart()
    }

    SequentialAnimation {
        id: slideRun
        // The crossing runs on the INDICATOR'S SHAPE: a quick departure on OutQuad,
        // then a long settle on OutSine, the tail three times the head.
        //
        // That two-speed shape is what makes the motion read as carrying weight
        // rather than being dragged, and a single ease cannot produce it - the
        // symmetric `InOutSine` this replaced left and arrived at the same gentle
        // rate, which read as a shove.
        //
        // The SHAPE is the indicator's, and so are the clocks: the strip covers a
        // few columns, and the indicator covers sixteen pixels, and `medium` then
        // `slow * 2` is the same proportion of each. The earlier numbers scaled the
        // indicator's clocks by the panel's whole width, which threw most of the
        // content across before the settle began - measured at 70% of the panel in
        // 160ms, a lunge followed by a crawl.
        //
        // What cannot be reproduced at all is the indicator's structure: its head
        // and tail are two positions running in PARALLEL with a drawn bar between
        // them, so it settles in `slow * 2`. Here there is one position - the
        // strip - and it has to cover both phases.
        animations: [
            // The indicator's head, on the indicator's head clock.
            NumberAnimation {
                target: root
                property: "slideProgress"
                to: root.slideHeadShare
                duration: root.slideHeadDuration
                easing.type: Easing.OutQuad
            },
            // The indicator's tail, on the indicator's tail clock.
            NumberAnimation {
                target: root
                property: "slideProgress"
                to: 1
                duration: root.slideTailDuration
                easing.type: Easing.OutSine
            }
        ]
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
    implicitWidth: shownColumnCount * columnWidth
    // The taller of the two frames while a crossing is in flight, and the strip's
    // own height once it has landed. The empty-workspace placeholder lives inside
    // the columns, so the columns' own height already accounts for it.
    implicitHeight: ready
        ? Math.max(root._outgoingHeight, strip.contentHeight)
        : emptyText.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // The strip. One object, carrying both frames, translated by the one clock. Its
    // width is the whole run of workspaces; the panel is the three-column window
    // onto it, and `clip` on the body is what keeps the rest of the run off the
    // surface.
    BarWindowHintStrip {
        id: strip
        objectName: "windowHintStrip"
        parent: root
        // The strip's own offset. At rest it sits at 0 - the plan's end, with the
        // active column in the panel's middle - and during a crossing it is
        // somewhere between the plan's start and end.
        x: root.slideOffset
        y: 0
        width: root.stripWidth
        height: root.height
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
        listSpacing: root.listSpacing
        rowHeight: root.rowHeight
        glyphInset: root.glyphInset
        glyphWidth: root.glyphWidth
        interactive: !root.swapping
        onWindowActivated: windowId => root.windowActivated(windowId)
    }

    // One shared focus highlight for the whole list, the way the launcher's does: a
    // single element that glides to the current row instead of every row showing
    // and hiding its own. A filled wash rather than the launcher's border frame,
    // and the rows give up their own focused tint so exactly one highlight exists
    // at a time - two fills would read as two states.
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
        // The token the rows' focused tint used, so this is that highlight that
        // moved rather than a new colour.
        color: LazerTheme.settingsSelected
        // A Rectangle draws a 1px border by default. This is a fill, and a default
        // black hairline around it would read as an outline again.
        border.width: 0
        // Inert to input, so it can never intercept a tap meant for the row.
        enabled: false

        // Bounded by the row, not inset: the highlight has to cover exactly the row
        // it marks, and the row spans its column's full width. Measured from the
        // active column's own x, so it cannot be drawn over a column that is not
        // the active one whatever the layout decided.
        x: strip.activeColumnX
        y: root.focusedRowTop
        width: root.columnWidth
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
    // 90 degrees for a list that runs down a column: a short green bar beside the
    // focused row's glyph, `barIndicatorHeight` thick with the same radius, in
    // `osuGreen`. One instance for the whole list, driven by the dual-speed tracker
    // above so a switch elongates along the bar's long axis and contracts on arrival
    // rather than sliding at one rate.
    // Stacking: rows paint at the default 0, the shared focus highlight sits above
    // them at 5, and this indicator above the highlight at 6. The order matters —
    // the indicator is a mark ON the highlight, and at the same z the declaration
    // order alone would decide, so it is stated explicitly.
    Rectangle {
        id: focusUnderline
        objectName: "windowHintFocusIndicator"
        parent: strip
        z: 6

        width: root.indicatorThickness
        height: root._barLength
        radius: LazerTheme.barIndicatorRadius
        color: LazerTheme.osuGreen
        // Measured from the active column's own left edge, which is the same origin
        // the highlight uses, so the bar and the fill it marks always move together.
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
