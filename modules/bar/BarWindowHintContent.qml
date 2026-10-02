import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic

// Body of the mod-key window hint: the windows on the workspace you are on, plus
// the windows either side of it. Rendered inside the bar's popup, so it reuses
// the popup's surface colors, section fill and shared reveal instead of owning a
// surface of its own.
//
// A workspace switch is a WHOLE-BODY displacement: the outgoing content leaves by
// one full panel width and the incoming content enters from the far side, both
// moving the same way, once, without turning back. Two copies of the same strip,
// translating in step - see the two layers below.
//
// Why two layers and not one crossfading list. A single layer that slides out and
// comes back leaves a band of empty panel on one side for the length of the
// travel, and a hole in a panel reads as a fault rather than as motion. A
// crossfade leaves the panel translucent in the middle, which reads as a flicker.
// Two layers cover each other's vacated ground: the seam between them is a single
// vertical edge sweeping across the panel, and the panel is never less than fully
// covered at any point in the slide.
//
// Only the incoming copy carries the focus highlight and the indicator. Focus
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
    // content being off-panel at that moment.
    property var columns: HintLogic.cappedColumns(null)
    // The columns on their way out, held for the length of one slide. A depth-1
    // hold is the whole of it: the launcher's display pool solves the same problem
    // for a list that refills on every keystroke, which is not what a
    // hold-to-see popup does.
    property var outgoingColumns: HintLogic.cappedColumns(null)
    property bool shownReady: false
    // +1 when the workspace moved later in the list, -1 earlier, 0 unknown.
    property int swapDirection: 0
    // 0 while a slide is in flight, 1 at rest. The one clock the whole motion
    // runs on: both layers read it, so they cannot disagree about where the seam
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
    // How far each layer travels: exactly the panel's own width, and NOT a
    // constant. This is the whole reason the panel is never left uncovered.
    //
    // At progress p the outgoing copy spans [-pW, -pW + W] and the arriving one
    // spans [(1-p)W, (1-p)W + W]. The first copy's right edge and the second's
    // left edge are both (1-p)W, so they meet at a single seam that sweeps across
    // the panel - the pair covers [0, W] for every p. Any other distance breaks
    // that identity: a longer travel opens a gap between them, a shorter one
    // leaves them overlapping and double-drawing the rows in the middle.
    //
    // The panel's width is the NEW one, from the count of columns now on screen.
    // An outgoing copy that was wider than the panel it is leaving simply overflows
    // to its right as it slides out, which is what a narrower panel taking a wider
    // one out should look like.
    readonly property int slideDistance: width
    // How far both layers dim at the middle of the crossing, 0 at either end.
    //
    // A pure translation across a fixed frame reads as two rigid boards being
    // swapped past each other: it has no weight, because nothing about the content
    // changes. A small dip gives it some, and it is safe to do here precisely
    // because the two layers are the same shape at the same offset - both dim
    // together, so the panel darkens uniformly instead of one layer showing
    // through the other. Shallow on purpose: enough to register, far too little to
    // read as a fade.
    readonly property real slideDip: Math.sin(Math.PI * slideProgress) * 0.12
    // Where the head hands over to the tail, as a share of the traverse.
    //
    // Chosen so the tail has real distance left to close rather than a crawl: the
    // indicator's own tail is still a third of its way along when the head lands,
    // and that is what keeps the settle readable instead of looking like the motion
    // stopped and then restarted.
    readonly property real slideHeadShare: 0.7
    // The two clocks, which are the indicator's two clocks and nothing else. The
    // same tokens, in the same roles, that drive the head and tail Behaviors below
    // - see the note on `slideRun` for why the crossing cannot be a single ease.
    readonly property int slideHeadDuration: MotionTokens.medium
    readonly property int slideTailDuration: MotionTokens.slow * 2
    // Both phases, for anything that has to wait the crossing out. This is longer
    // than the indicator's 480ms settle, because there the two speeds run in
    // parallel and here they run one after the other - the same two speeds in the
    // same order, not the same total.
    readonly property int slideDuration: slideHeadDuration + slideTailDuration
    // The crossing's own recipe, and the indicator's, so a suite can compare the
    // two against each other. A test that reads `MotionTokens.slow > MotionTokens.fast`
    // instead checks that two numbers exist somewhere in the file, not that the
    // crossing runs on them - which is exactly the mistake a retune would
    // reintroduce, and which one already had.
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
    // are simply gone and remade between two frames. Here the outgoing content is
    // held, the incoming content takes its place off-panel, and both are driven
    // across by one clock.
    //
    // Reduced motion, a first snapshot, and a change with no knowable direction
    // (a window title edit on the same workspace) all commit straight away: an
    // un-aimed animation would be motion for its own sake, and a title edit is not
    // a page turn.
    function _onHintChanged() {
        if (MotionTokens.reducedMotion || !root.shownReady)
            return root._commitHint()
        const direction = HintLogic.switchDirection(root.hint)
        if (direction === 0)
            return root._commitHint()
        root.swapDirection = direction
        // Already sliding: replace the arriving content and let the crossing
        // continue. Re-holding the outgoing copy here would send the arriving layer
        // back to its starting offset - a visible jump backwards - and stopping the
        // run would snap it home, which is the same artefact by another route.
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

    // Swap the content of the arriving copy without touching the slide. The layer's
    // offset is what carries the motion, so the rows change under it mid-crossing
    // and the user sees the new workspace's list slide in from where the old one
    // was heading.
    function _replaceArriving() {
        root.columns = HintLogic.cappedColumns(root.hint)
        root.shownReady = HintLogic.ready(root.hint)
    }

    // Hold what is on screen, put the new content in its place off-panel, and run
    // the clock. The held copy is a reference to the same columns object, so
    // nothing is copied and the outgoing rows keep their own delegates.
    function _startSlide() {
        root.outgoingColumns = root.columns
        root.columns = HintLogic.cappedColumns(root.hint)
        root.shownReady = HintLogic.ready(root.hint)
        root.slideProgress = 0
        slideRun.restart()
    }

    SequentialAnimation {
        id: slideRun
        // The crossing runs on the INDICATOR's motion: same two speeds, same two
        // curves, same order.
        //
        // The indicator beside the rows moves a head that commits fast on OutQuad
        // and a tail that lingers on a much longer OutSine. That two-speed shape
        // is what makes it read as carrying weight rather than being dragged, and
        // a single ease cannot produce it - the symmetric `InOutSine` this replaced
        // left and arrived at the same gentle rate, which read as a shove.
        //
        // So the traverse is the same two phases in sequence on one progress
        // value, on the indicator's own clocks: `medium` to commit the head, then
        // `slow * 2` to settle the tail. The durations are the indicator's, not a
        // rescaled approximation of them - a faster version of the same curve is
        // a different motion, and it is the speed as much as the shape that makes
        // the indicator what it is.
        //
        // What cannot be identical is the total: the indicator's head and tail run
        // in PARALLEL on two positions with a drawn bar between them, so it settles
        // in `slow * 2`. Here there is one position - the seam - and it has to
        // cover both phases, so the crossing is `medium + slow * 2`. Giving the two
        // layers the two speeds separately would have been the literal version and
        // it cannot work: coverage only holds when the arriving layer runs ahead,
        // which means it lands early and hides the content that is supposed to be
        // seen sliding out past it.
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
            // The outgoing copy is fully off-panel by now, so releasing it costs
            // nothing on screen and keeps exactly one set of rows alive.
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
            duration: root.slideHeadDuration
            easing.type: Easing.OutQuad
        }
    }
    Behavior on _tailY {
        enabled: root._placed && !MotionTokens.reducedMotion && !root._snapping
        // 3x the head's flight: the tail lingers long after the head lands, which
        // is what keeps the stretch readable.
        NumberAnimation {
            id: indicatorTailAnimation
            duration: root.slideTailDuration
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
    // The taller of the two layers while one is leaving. The empty-workspace
    // placeholder lives inside the columns, so the columns' own height already
    // accounts for it.
    implicitHeight: ready
        ? Math.max(root._outgoingHeight, incomingStrip.contentHeight)
        : emptyText.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // The outgoing copy. It leaves by a full panel width and never comes back, and
    // the offset is negated against the workspace move: going to a LATER workspace
    // takes the content leftwards, because the workspace you are moving to was
    // sitting to the right of the one you are leaving and has to cross to reach the
    // middle. So `swapDirection` says which way the workspace moved and the content
    // moves the other way - the way a page does when you turn forward.
    Item {
        id: outgoingLayer
        objectName: "windowHintOutgoingLayer"
        width: parent.width
        visible: root.ready && root.swapping
        x: -root.slideProgress * root.slideDistance * root.swapDirection
        // Dims with its opposite number, so the seam never shows one layer
        // through the other.
        opacity: 1 - root.slideDip
    }

    BarWindowHintStrip {
        id: outgoingStrip
        objectName: "windowHintOutgoingStrip"
        // Held in the outgoing layer, not beside it: the layer is what translates,
        // and a strip that slid on its own would move relative to its own layer.
        parent: outgoingLayer
        x: 0
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

    // The incoming copy. It starts a full panel width to one side - off-panel, so
    // the panel is still showing the outgoing content alone - and lands at 0.
    Item {
        id: incomingLayer
        objectName: "windowHintIncomingLayer"
        width: parent.width
        visible: root.ready
        x: (1 - root.slideProgress) * root.slideDistance * root.swapDirection
        opacity: 1 - root.slideDip
    }

    BarWindowHintStrip {
        id: incomingStrip
        objectName: "windowHintIncomingStrip"
        parent: incomingLayer
        x: 0
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
    // A child of the incoming layer, so it crosses with the content it marks. A
    // highlight pinned to the panel while the column slid out from under it would
    // say the focus stayed put while the window list moved - two different claims
    // about where the current window is.
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
