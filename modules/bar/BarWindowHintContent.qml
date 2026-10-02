import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic

// Body of the mod-key window hint: the windows on the workspace you are on, plus
// the windows either side of it. Rendered inside the bar's popup, so it reuses
// the popup's surface colors, section fill and shared reveal instead of owning a
// surface of its own.
//
// A workspace switch is a WHOLE-BODY change, once, without turning back: two
// copies of the same strip, and one clock. Neither copy MOVES. The panel is a
// window onto a fixed frame, and a single vertical seam sweeps across it - the
// frame you are leaving to the left of the seam, the frame you are arriving at to
// the right, and at every point of the travel the seam sits between two different
// workspaces.
//
// Why nothing is translated, when the last four commits built this as a
// full-panel displacement and made the traverse finish on its own clock. Because
// the panel is a three-column frame of CONSECUTIVE workspaces, the frame you are
// leaving and the frame you are arriving at SHARE TWO OF THEIR THREE COLUMNS. A
// page turn is the right motion for a panel whose pages are disjoint, and this
// one's are not: sliding one frame off and the other on by a whole panel width
// puts the shared workspaces on screen in two places at once, and the user reads
// that as duplicated window-title cards rather than as motion. Measured with a
// probe replaying the publishes WindowHintService makes for one activation,
// sampling which titles are actually inside the panel every 40ms across the whole
// traverse:
//
//   forward 1->2   22 of 24 samples had a title painted twice (41 double-painted)
//   backward 2->0  22 of 24 samples had a title painted twice (44 double-painted)
//
// A seam cannot have that fault, and the reason is arithmetic rather than taste.
// The two frames' shared workspace W sits in the leaving frame's slot j and the
// arriving frame's slot j-d, where d is how far the workspace moved. The leaving
// copy is shown where 180j < seam and the arriving copy where seam < 180(j-d+1),
// and those two cannot both hold for any d >= 1. The seam separates the shared
// workspace from its own second copy by construction, at every progress value.
//
// Why two copies and not one. A single copy replaced in place leaves the panel
// blank for a frame or fades, and both read as a fault rather than as motion. The
// two gates below are complementary halves of the panel at every progress value,
// so a band of uncovered panel is not expressible - the coverage this design
// exists for is a property of the geometry rather than of two carefully matched
// travel distances.
//
// Only the arriving copy carries the focus highlight and the indicator. Focus
// belongs to the workspace you are moving to, and a marker on the outgoing copy
// would blink a second time for a workspace you have already left.
Item {
    id: root

    // The live snapshot from WindowHintService, replaced wholesale on every
    // refresh, so each binding below re-evaluates on a workspace switch.
    property var hint: null
    signal windowActivated(string windowId)

    // What is painted: the incoming copy's columns. Replaced at the START of a
    // slide, not at the end - the outgoing copy is the one being held, and the
    // panel is sized from what is arriving so a width change is masked by the
    // arriving frame still being behind the seam.
    property var columns: HintLogic.cappedColumns(null)
    // The frame on its way out, held for the length of one slide. A depth-1
    // hold is the whole of it: the launcher's display pool solves the same problem
    // for a list that refills on every keystroke, which is not what a
    // hold-to-see popup does.
    property var outgoingColumns: HintLogic.cappedColumns(null)
    property bool shownReady: false
    // +1 when the workspace moved later in the list, -1 earlier, 0 unknown. It
    // steers the seam's direction, not a transform - see `leavingHoldsTheLeft`.
    property int swapDirection: 0
    // 0 while a slide is in flight, 1 at rest. The one clock the whole motion
    // runs on: both gates read it, so they cannot disagree about where the seam
    // is, and there is no second animation to fall out of step.
    property real slideProgress: 1
    property bool swapping: slideProgress < 1

    readonly property bool ready: root.shownReady
    // Three columns of one fixed width, always. The count does not vary with the
    // content: the active workspace sits in the middle, and it can only stay in
    // the middle if the frame around it is the same size whatever the neighbours
    // are running. It also means the panel does not resize under the pointer as
    // the user moves between an interior workspace and an edge one.
    readonly property int columnWidth: HintLogic.COLUMN_WIDTH
    readonly property int shownColumnCount: HintLogic.COLUMN_COUNT
    // Where the seam is, in panel coordinates. 0 means the arriving frame owns
    // the whole panel; the panel's own width means the leaving frame owns all of
    // it. Read straight off `slideProgress` and NOT gated on `swapping`, because
    // the resting seam is the answer in one direction and the other end in the
    // other - and getting that wrong leaves the arriving gate shut at rest, which
    // is a blank panel rather than a subtle fault.
    //
    // Which way it travels is the direction the workspace moved. Going to a later
    // workspace, the workspace you are moving to was sitting to the RIGHT of the
    // one you are leaving, so its frame arrives from the right: the seam starts at
    // the far edge and the leaving copy holds the left. Going earlier, the mirror.
    readonly property real seam: swapDirection >= 0
        ? width * (1 - slideProgress) : width * slideProgress
    readonly property bool leavingHoldsTheLeft: swapDirection >= 0
    // The two gates. They are the same cut read twice: one of them is anchored to
    // the panel's left edge and the other to its right, they meet at `seam`, and
    // together they are exactly the panel at every progress value.
    readonly property real outgoingGateX: leavingHoldsTheLeft ? 0 : root.seam
    readonly property real outgoingGateWidth: leavingHoldsTheLeft
        ? root.seam : width - root.seam
    readonly property real incomingGateX: leavingHoldsTheLeft ? root.seam : 0
    readonly property real incomingGateWidth: leavingHoldsTheLeft
        ? width - root.seam : root.seam
    // How far both copies dim at the middle of the crossing, 0 at either end.
    //
    // A seam that swaps content in place has nothing about the content changing
    // to carry it, so a small dip gives the panel some weight. It is safe here for
    // the same reason it was safe before: both copies take the SAME value at the
    // same moment, so the panel darkens uniformly instead of one copy showing
    // through the other. Shallow on purpose: enough to register, far too little to
    // read as a fade.
    readonly property real slideDip: Math.sin(Math.PI * slideProgress) * 0.12
    // Where the head hands over to the tail, as a share of the traverse.
    //
    // Small on purpose. The head is the quick departure, so the temptation is to
    // let it carry most of the distance - and on a panel-width travel that reads as
    // a lunge, because the bulk of the movement lands in the first fifth of a
    // second and the rest crawls. Two tenths of the way is a departure; four tenths
    // is most of the motion, and the seam looks like it is being thrown across the
    // panel rather than carried.
    readonly property real slideHeadShare: 0.4
    // The two clocks, carrying the indicator's two-speed SHAPE at a distance the
    // indicator's clocks were never asked to cover.
    //
    // `medium`/`slow * 2` is right for the indicator because the indicator has to
    // cover sixteen pixels: its head really can put the bar there in 160ms. The
    // crossing covers the panel's whole width, so the same head clock moves a
    // third of a metre of content in the same breath - a different motion wearing
    // the same numbers. These are scaled to the travel, not copied from it, and the
    // two stay in the indicator's proportions: the tail is three times the head, so
    // the arrival keeps lingering after the departure has finished.
    readonly property int slideHeadDuration: MotionTokens.slow
    readonly property int slideTailDuration: MotionTokens.slow * 3
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
    // The one row the focus indicator belongs to, or -1. Read from the INCOMING
    // column, which is the content the user is looking at.
    readonly property int focusedRowIndex: HintLogic.focusedIndexIn(columns.current.rows)
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
    // The outgoing copy's height, while it is still on screen. The panel is sized
    // to the taller of the two so a workspace with more windows on it does not have
    // its bottom rows cut off by the panel edge for the length of the slide.
    readonly property int _outgoingHeight: root.swapping ? outgoingStrip.contentHeight : 0

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
    // held, the arriving frame is put in its place, and one clock drives the seam
    // between them across the panel.
    //
    // Reduced motion, a first snapshot, and a change with no knowable direction
    // (a window title edit on the same workspace) all commit straight away: an
    // un-aimed animation would be motion for its own sake, and a title edit is not
    // a page turn.
    function _onHintChanged() {
        if (MotionTokens.reducedMotion || !root.shownReady)
            return root._commitHint()
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
        if (direction === 0)
            return root.swapping ? root._replaceArriving() : root._commitHint()
        root.swapDirection = direction
        // Already crossing: replace the arriving content and let the crossing
        // continue. Re-holding the leaving frame here would put the seam back at
        // the start of the panel - a visible jump backwards - and stopping the run
        // would snap it to the end, which is the same artefact by another route.
        if (root.swapping)
            return root._replaceArriving()
        root._startSlide()
    }

    function _commitHint() {
        slideRun.stop()
        root.slideProgress = 1
        root._replaceArriving()
        // Nothing is on its way out, so the held copy goes with the commit.
        root.outgoingColumns = HintLogic.cappedColumns(null)
    }

    // Swap the content of the arriving copy without touching the crossing. The
    // seam is what carries the motion and the content does not move, so the rows
    // change under the crossing and the user sees the new workspace's list
    // revealed from behind the seam.
    function _replaceArriving() {
        root.columns = HintLogic.cappedColumns(root.hint)
        root.shownReady = HintLogic.ready(root.hint)
    }

    // Hold what is on screen, put the new content behind the seam, and run the
    // clock. The held copy is a reference to the same columns object, so nothing
    // is copied and the leaving rows keep their own delegates.
    function _startSlide() {
        root.outgoingColumns = root.columns
        root.columns = HintLogic.cappedColumns(root.hint)
        root.shownReady = HintLogic.ready(root.hint)
        root.slideProgress = 0
        slideRun.restart()
    }

    SequentialAnimation {
        id: slideRun
        // The crossing runs on the INDICATOR'S SHAPE: a quick departure on OutQuad,
        // then a long settle on OutSine, the tail three times the head.
        //
        // That two-speed shape is what makes the indicator read as carrying weight
        // rather than being dragged, and a single ease cannot produce it - the
        // symmetric `InOutSine` this replaced left and arrived at the same gentle
        // rate, which read as a shove.
        //
        // The SHAPE is the indicator's; the clocks are not, and cannot be. The
        // indicator has sixteen pixels to cross and can honestly put its bar
        // somewhere in `medium`. The seam has the panel's whole width to cross, so
        // the same clock throws most of the panel across before the settle even
        // starts - measured on the previous numbers, 70% of the panel in 160ms and
        // the remaining 30% over 480ms, which reads as a lunge followed by a crawl
        // rather than as a carried crossing. The clocks here are scaled to the
        // travel and the share is cut so the departure stays a departure.
        //
        // What cannot be reproduced at all is the indicator's structure: its head
        // and tail are two positions running in PARALLEL with a drawn bar between
        // them, so it settles in `slow * 2`. Here there is one position - the seam -
        // and it has to cover both phases. Giving the two gates the two speeds
        // separately would be the literal version and it does not work: they are
        // complementary halves of the panel, so a gate running ahead of the other
        // does not overlap it, it just leaves the panel's far edge uncovered.
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
            // The seam has reached the far edge, so the leaving copy's gate has
            // closed to nothing and releasing the copy costs nothing on screen
            // while keeping exactly one set of rows alive.
            root.outgoingColumns = HintLogic.cappedColumns(null)
            root.slideProgress = 1
        }
    }

    onHintChanged: _onHintChanged()

    readonly property real _barTop: Math.min(_headY, _tailY)
    readonly property real _barLength: indicatorLength + Math.abs(_headY - _tailY)
    readonly property bool hasTarget: focusedRowIndex >= 0
            && focusedRowIndex < columns.current.rows.length

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

    // Three columns, always. The popup measures its geometry from this, so the host's
    // `window-hint` width reads the body rather than keeping its own number - and
    // the body reports the same number whether the neighbour workspaces are busy
    // or empty, so the panel never changes size mid-hold.
    implicitWidth: shownColumnCount * columnWidth
    // The taller of the two copies while one is leaving. The empty-workspace
    // placeholder lives inside the columns, so the columns' own height already
    // accounts for it.
    //
    // The gates' widths are deliberately not in here. A gate's rect is a per-frame
    // change, and the popup sizes its layer-shell surface from the body's
    // implicitWidth / implicitHeight, so anything that fed a gate's width into
    // them would re-commit the surface on every frame of the crossing.
    implicitHeight: ready
        ? Math.max(root._outgoingHeight, incomingStrip.contentHeight)
        : emptyText.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // The window onto the panel through which the outgoing copy is seen, and the
    // share of the panel that window currently holds. The copy itself never
    // moves: the strip below is parked at -x so the frame's three columns keep
    // their own slots whatever the gate is doing, and the gate's rect is what
    // decides how much of them there is to see.
    //
    // `clip` is a paint-time rect, not an input region - Qt Quick delivers events
    // by geometry. That is fine here because nothing inside a gate is a tap
    // target while the seam is moving (both strips report `interactive: false`),
    // and once it lands the arriving gate is the whole panel.
    Item {
        id: outgoingLayer
        objectName: "windowHintOutgoingLayer"
        x: root.outgoingGateX
        width: root.outgoingGateWidth
        height: parent.height
        clip: true
        visible: root.ready && root.swapping
        // Dims with its opposite number, so the seam never shows one copy through
        // the other.
        opacity: 1 - root.slideDip
    }

    BarWindowHintStrip {
        id: outgoingStrip
        objectName: "windowHintOutgoingStrip"
        // Held in the outgoing layer, not beside it: the layer is the window, and
        // the strip has to sit at absolute zero inside it so its columns stay in
        // the frame's own slots - a copy that slid with the gate would be drawing
        // the leaving frame from the wrong place.
        parent: outgoingLayer
        x: -outgoingLayer.x
        y: 0
        columns: root.outgoingColumns
        columnWidth: root.columnWidth
        listSpacing: root.listSpacing
        rowHeight: root.rowHeight
        glyphInset: root.glyphInset
        glyphWidth: root.glyphWidth
        // What is leaving is not a tap target: the pointer is over content that
        // is about to be somewhere else.
        interactive: false
    }

    // The window onto the panel through which the arriving copy is seen - the
    // other half of the same cut, and the whole of it once the seam has passed.
    Item {
        id: incomingLayer
        objectName: "windowHintIncomingLayer"
        x: root.incomingGateX
        width: root.incomingGateWidth
        height: parent.height
        clip: true
        visible: root.ready
        opacity: 1 - root.slideDip
    }

    BarWindowHintStrip {
        id: incomingStrip
        objectName: "windowHintIncomingStrip"
        parent: incomingLayer
        // Absolute zero inside the gate, like the leaving copy: the arriving
        // frame's columns keep their slots and the gate only decides how much of
        // them the panel shows.
        x: -incomingLayer.x
        y: 0
        columns: root.columns
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
    // A child of the arriving gate, so it is on the same side of the seam as the
    // row it marks and is revealed with it: while the arriving frame is still
    // behind the seam the marker is behind it too, and it comes into view as the
    // seam uncovers the arriving active column. Pinned to the panel instead, it
    // would be claiming a row the user is not being shown yet.
    Rectangle {
        id: focusFrame
        objectName: "windowHintFocusFrame"
        parent: incomingLayer
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
        x: incomingStrip.activeColumnX
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
        parent: incomingLayer
        z: 6

        width: root.indicatorThickness
        height: root._barLength
        radius: LazerTheme.barIndicatorRadius
        color: LazerTheme.osuGreen
        // Measured from the active column's own left edge, which is the same origin
        // the highlight uses, so the bar and the fill it marks always move together.
        x: incomingStrip.activeColumnX + root.indicatorInset
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
