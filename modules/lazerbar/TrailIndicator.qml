import QtQuick

// The shell's one dual-speed selection mark: a fast head and a slow tail
// flying to the SAME committed target, so the drawn strip stretches along the
// direction of travel and contracts as the tail lands.
//
// This is `modules/bar/widgets/Workspaces.qml`'s indicator tracker, lifted out
// of it rather than reimplemented for each rail. Head `MotionTokens.medium`
// (160ms, OutQuad), tail `MotionTokens.slow * 2` (480ms, OutSine) — three times
// the head's flight, which is what keeps the stretch readable instead of a
// blur. Anchored at `min(head, tail)`; the length is the RAW separation, no cap
// and no clamp. The wake peaks at 55.5% of the travel 121ms in and closes
// exactly at 480ms — check any change to the two curves against that number
// rather than against a screenshot.
//
// WHY TWO ENDS AND NOT A HEAD THAT SIMPLY REDRAWS: a mark that eases to a new
// place says only that it moved. A mark whose far end lags says how far and
// which way, which is the whole content of a selection change.
//
// WHY TWO BEHAVIORS AND NOT A PER-FRAME FOLLOWER: a follower is the right tool
// only while the head is PINNED to something that keeps travelling, because that
// case has no fixed target to aim at. Here the target is committed once, so both
// ends can fly at it on their own curves. An assignment re-aimed every frame
// restarts its easing before it leaves the start of its curve — measured at ~5%
// of the gap on the first tick of a 480ms flight, a frozen tail. The crossing
// case in `modules/bar/BarWindowHintContent.qml` genuinely needs the follower
// and is deliberately NOT folded in here; `lazer-motion-perf` records why the
// two are different mechanisms.
//
// THE WAKE IS UNBOUNDED, as it is in the widget: a long jump draws a strip
// longer than the surface it sits in. A cap is not the fix — capping converts a
// growing wake into a held one and the held one into a drop at the far end,
// which is worse than the length it was fixing. If a bound is ever wanted it
// has to bound the DRAWN strip while the mark stays anchored to the head, and
// that is a design decision rather than a bug fix.
//
// A selection change is one blink (the shared click-flash contract, 1.8x peak)
// plus the wake; layout churn is neither. That split is the widget's, and it is
// why this takes a `targetKey` at all.
Item {
    id: root

    // --- Host contract ----------------------------------------------------

    // Axis the mark travels along: "y" for a vertical rail, "x" for a
    // horizontal one.
    property string axis: "y"
    // The strip's resting extent along its axis, and its thickness across it.
    property real markLength: 24
    property real markThickness: 4
    property int markRadius: 2
    property color markColor: "transparent"
    // Where the host wants the strip ACROSS its axis — a rail's left margin, a
    // bar's baseline. The travel axis is the component's own and is NOT a host
    // property, because the leading edge there is `start`, which is half the
    // mark's geometry: a host that placed the mark itself would have to know the
    // wake to get the position right, and the wake is the one thing it must not
    // know.
    property real crossAxis: 0

    // Where the mark's CENTRE belongs, in this item's own coordinates. The
    // host writes it; the tracker never writes it.
    property real targetCenter: 0
    // Identity of the selection `targetCenter` describes. A change of identity
    // is a selection change and earns the wake and the blink; the same identity
    // drifting is layout settling and must not stretch the mark.
    property string targetKey: ""
    // False while there is nothing to mark yet — no selection, a category the
    // current search emptied, or a host that has not shown its rail. The tracker
    // then holds its last committed target rather than flying to a row that is
    // not there, and the host hides the mark. This is also how a host says "not
    // yet": the first target that arrives while `targetValid` is true is a
    // PLACEMENT, landing outright, rather than a switch — so the mark never
    // slides in from zero on the way to its only resting place and never blinks
    // on boot.
//
// Hiding is the host's job on purpose: parking the mark instead would cut a
// live wake every time the content is briefly without a target, which is the
// normal state DURING a switch.
    property bool targetValid: true
    // Moving layout geometry is sampled without queuing an obsolete destination.
    property bool targetMoving: false
    property bool _following: false
    property real _followOffset: 0

    function _followTarget() {
        if (!root.targetValid || !isFinite(root.targetCenter))
            return
        if (!root._following) {
            const from = root._committed ? root._head : root._target
            root._following = true
            root._hasPending = false
            root._followOffset = from - root._target
            followArrival.restart()
        }
        if (root._key !== String(root.targetKey)) {
            followArrival.stop()
            root._followOffset = root._head - root._target
            followArrival.restart()
            root._key = String(root.targetKey)
            flashAnimation.restart()
        }
        root._anchor = root._target
        root._head = root._target + root._followOffset
        root._committed = true
    }

    NumberAnimation {
        id: followArrival
        target: root
        property: "_followOffset"
        to: 0
        duration: MotionTokens.medium
        easing.type: Easing.OutQuad
    }

    // Follow the physical icon and close its wake after layout settles.
    Timer {
        interval: MotionTokens.motionFrame
        repeat: true
        running: root._following
        onTriggered: {
            root._followTarget()
            root._tail += (root._head - root._tail) * MotionTokens.motionFollowRate
            if (!root.targetMoving && !followArrival.running
                    && Math.abs(root._head - root._tail) < 0.5) {
                root._head = root._target
                root._tail = root._target
                root._following = false
            }
        }
    }

    // --- Tracker ----------------------------------------------------------

    // Same-selection movement smaller than this is layout noise, not a
    // re-anchor. The widget's own value.
    readonly property real driftTolerance: 3

    // Committed target, as the strip's leading edge, never animated. Dedupe
    // and drift read this rather than `_head`, whose value is the Behavior's
    // in-flight frame and reads "settled" for a tick after every switch.
    property string _key: ""
    property real _anchor: 0
    // The two ends. Both are written the same value at the same time; the two
    // curves pull them apart, and that separation IS the wake.
    property real _head: 0
    property real _tail: 0
    // Suppresses both Behaviors for exactly one synchronous commit.
    property bool _snapping: false
    // Drift that arrived while the mark was in flight, held here and applied as
    // ONE snap on landing, so layout churn never cuts a wake short.
    property bool _hasPending: false
    property real _pendingCenter: 0
    // Whether a valid target has ever been committed. The first one is a
    // placement and lands outright; that is the one thing the tracker cannot
    // infer from the numbers, because a host computing a target for the first
    // time is indistinguishable from one whose selection just changed.
    property bool _committed: false
    // A publish can write the key and the centre in one synchronous block, and
    // in either order. Committing on the first of the two writes would fly to a
    // stale centre and then snap — the wake dying for no visible reason — so a
    // commit is coalesced into one per event-loop turn, which makes the ORDER
    // irrelevant instead of something each host has to get right.
    property bool _queued: false

    readonly property bool _vertical: root.axis === "y"
    readonly property real _target: root.targetCenter - root.markLength / 2
    readonly property real wake: Math.abs(root._head - root._tail)
    readonly property real start: Math.min(root._head, root._tail)
    readonly property real length: root.markLength + root.wake

    // True while the mark is under way — which is NOT the same question as
    // "is the wake open". Right after a commit both ends read equal, so a gap
    // test says nothing is happening while the head is still flying; the head
    // being short of its anchor is the honest test.
    readonly property bool inFlight: root._head !== root._anchor || root.wake > 0.5

    // The mark's box, placed at the leading edge of the wake. Both of these are the
    // mechanism rather than a convenience: a strip whose length animates while
    // its position stays put is not a wake, it is a strip growing out of
    // nowhere, and nothing in the numbers below can tell the difference — the
    // position has to be asserted too.
    width: root._vertical ? root.markThickness : root.length
    height: root._vertical ? root.length : root.markThickness
    x: root._vertical ? root.crossAxis : root.start
    y: root._vertical ? root.start : root.crossAxis

    // Head on the widget's own curve, tail on its own slower one. Same gate on
    // both, so neither can be re-targeted a frame ahead of the other.
    Behavior on _head {
        enabled: root._committed && !MotionTokens.reducedMotion && !root._snapping && !root._following
        NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
    }
    Behavior on _tail {
        enabled: root._committed && !MotionTokens.reducedMotion && !root._snapping && !root._following
        NumberAnimation { duration: MotionTokens.slow * 2; easing.type: Easing.OutSine }
    }

    // Apply a held drift as one snap, but only once the mark has landed.
    Timer {
        interval: 16
        repeat: true
        running: root._hasPending
        onTriggered: {
            if (root.inFlight)
                return
            root._hasPending = false
            root._snapTo(root._pendingCenter)
        }
    }

    // --- Commits ----------------------------------------------------------

    // Land both ends on a centre at once, with the Behaviors suppressed, so
    // nothing stretches. Both writes use a precomputed value: reading `_head`
    // back would return the Behavior's in-flight frame, not what was set.
    function _snapTo(center) {
        const target = center - root.markLength / 2
        root._snapping = true
        root._committed = true
        root._key = String(root.targetKey)
        root._anchor = target
        root._head = target
        root._tail = target
        root._snapping = false
    }

    function _commitPending() {
        root._queued = false
        if (MotionTokens.reducedMotion) {
            followArrival.stop()
            root._followOffset = 0
            if (root.targetValid)
                root._snapTo(root.targetCenter)
            root._following = false
            return
        }
        if (root.targetMoving || root._following) {
            root._followTarget()
            return
        }
        if (!root.targetValid || !isFinite(root.targetCenter))
            return
        const center = root.targetCenter
        if (!root._committed) {
            root._snapTo(center)
            return
        }
        if (String(root.targetKey) !== root._key) {
            // A genuine selection change: hand BOTH ends the same new target
            // with their Behaviors live. They leave together and separate only
            // because their curves differ, and the separation is the wake. The
            // blink rides the same event — it is the other half of what the
            // widget answers a switch with.
            root._hasPending = false
            root._key = String(root.targetKey)
            root._anchor = root._target
            root._head = root._target
            root._tail = root._target
            flashAnimation.restart()
            return
        }
        // Same selection, new geometry: layout settling, a resize, a scroll.
        // Never a reason to stretch the mark.
        if (Math.abs(root._target - root._anchor) < root.driftTolerance)
            return
        if (root.inFlight) {
            root._hasPending = true
            root._pendingCenter = center
            return
        }
        root._snapTo(center)
    }

    // One blink per genuine switch, matching the shared click-flash contract.
    // No-op under reduced motion, which also parks the overlay at zero rather
    // than leaving it wherever the last blink reached.
    property real flashOpacity: 0
    NumberAnimation {
        id: flashAnimation
        target: root
        property: "flashOpacity"
        from: Math.min(1, MotionTokens.clickFlashOpacity * 1.8)
        to: 0
        duration: MotionTokens.clickFlashDuration
        easing.type: MotionTokens.clickFlashEasing
    }
    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion) {
                flashAnimation.stop()
                root.flashOpacity = 0
                root._schedule()
            }
        }
    }

    // --- Geometry changes and target changes all land here ---------------

    onTargetMovingChanged: _schedule()
    onTargetCenterChanged: _schedule()
    onTargetKeyChanged: _schedule()
    onTargetValidChanged: _schedule()
    onMarkLengthChanged: _schedule()

    function _schedule() {
        if (root._queued)
            return
        root._queued = true
        Qt.callLater(root._commitPending)
    }
    Component.onCompleted: _schedule()

    // --- The mark ---------------------------------------------------------

    Rectangle {
        id: strip
        anchors.fill: parent
        radius: root.markRadius
        color: root.markColor
    }

    // Switch blink, drawn above the mark without changing its geometry — the
    // same tinted wash the workspace indicator uses, at the same strength.
    Rectangle {
        anchors.fill: parent
        radius: strip.radius
        color: LazerTheme.flashWash
        opacity: root.flashOpacity
        enabled: false
    }
}