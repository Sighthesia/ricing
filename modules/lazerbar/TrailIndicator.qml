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

    // The target is TRAVELLING: the thing this mark points at is itself moving, so
    // `targetCenter` is a new number on every frame rather than a place it was committed to.
    //
    // This is the one case the two-`Behavior` recipe cannot serve, and the reason is in the
    // numbers above: a `Behavior` animates toward the value it is next ASSIGNED, and an
    // assignment re-aimed every frame restarts its easing before it leaves the start of its
    // curve - measured at ~5% of the gap on the first tick, which is a tail that never
    // moves. It is also why the drift branch below cannot be the answer: that branch treats
    // a moved target as layout churn and CUTS to it, which is right for a resize and wrong
    // for a mark whose subject is crossing the strip.
    //
    // So this is the pinned case, and it uses the pinned mechanism: the head is written
    // straight to the target every frame, and the tail follows it on a wall-clock tick.
    // `modules/bar/BarWindowHintContent.qml` is where both halves of that split were
    // measured; `lazer-motion-perf` records it.
    property bool targetTravelling: false

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
    //
    // Both stand down while `targetTravelling` is set: see the pinned path below, which is
    // the one case where a fixed target does not exist.
    Behavior on _head {
        enabled: root._committed && !MotionTokens.reducedMotion && !root._snapping
            && !root.targetTravelling
        NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
    }
    Behavior on _tail {
        enabled: root._committed && !MotionTokens.reducedMotion && !root._snapping
            && !root.targetTravelling
        NumberAnimation { duration: MotionTokens.slow * 2; easing.type: Easing.OutSine }
    }

    // --- the pinned path: a target that is itself moving -------------------
    //
    // While `targetTravelling` is set the two `Behavior`s above are disabled and this pair
    // takes over: the head is WRITTEN to the target every frame (a sweep has no fixed place
    // to fly to), and the tail closes a fraction of the remaining gap per tick, so the wake
    // is the head's own travel over the last `interval / k` of wall time.
    //
    // The rate is `BarWindowHintContent.trailCatchUp`'s 0.2, which is the value that split
    // was tuned to: a wake is `1/k` of the head's per-tick travel, so 0.2 draws a trail five
    // times the distance the head covers in a tick, and it closes in about 330ms.
    readonly property real followRate: 0.2

    // Pinned every frame by the handler below, so nothing here needs to know how often the
    // target moves - it only has to be told that it did.
    function _pin() {
        if (!root.targetTravelling || !root.targetValid || !isFinite(root.targetCenter))
            return
        const target = root._target
        if (!root._committed) {
            root._snapTo(root.targetCenter)
            return
        }
        // A new identity while travelling is still a switch: commit the anchor and blink,
        // and let the travel carry both ends from wherever they are.
        if (String(root.targetKey) !== root._key) {
            root._key = String(root.targetKey)
            root._anchor = target
            flashAnimation.restart()
        }
        root._snapping = true
        root._head = target
        root._snapping = false
        root._anchor = target
        root._hasPending = false
    }

    Timer {
        id: followTick
        interval: 16
        repeat: true
        running: root.targetTravelling && root._committed && !MotionTokens.reducedMotion
        onTriggered: {
            const gap = root._head - root._tail
            if (Math.abs(gap) < 0.5)
                return
            root._snapping = true
            root._tail += gap * root.followRate
            root._snapping = false
        }
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
            }
        }
    }

    // --- Geometry changes and target changes all land here ---------------

    onTargetCenterChanged: {
        // A travelling target is pinned on the frame it moves; the coalesced commit below is
        // for a target that was COMMITTED to a place, and would cut the wake.
        if (root.targetTravelling) {
            root._pin()
            return
        }
        _schedule()
    }
    onTargetTravellingChanged: {
        if (root.targetTravelling) {
            // Hand the head to the target now rather than easing into a sweep, and let the
            // tail follow from wherever it was - that is the wake the travel starts with.
            root._pin()
            return
        }
        // The travel is over: hand both ends back to the `Behavior`s, which re-aim from
        // where they are onto the committed anchor. Deferred a turn, because a `Behavior`
        // captures its target when its `enabled` goes true.
        Qt.callLater(function () {
            if (root.targetTravelling || !root._committed)
                return
            root._anchor = root._target
            root._head = root._target
            root._tail = root._target
        })
    }
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