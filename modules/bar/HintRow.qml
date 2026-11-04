import QtQuick
import "../lazerbar"

// ONE row slot in a hint column: the slot itself, the row that lives in it, and the
// two animations that let a window arrive in it or leave it.
//
// The slot is the layout box and the row is the content, and they are two objects for
// the same reason the tray's slot and glyph are: the box has to close around a row
// that is on its way out, and the row has to be able to dissolve inside a box that is
// still moving. One object cannot be both, because a height and an opacity are two
// curves and the interesting part of this effect is where they differ - the ink is
// gone before the gap is, so the row below rides up onto an empty slot rather than
// onto a half-drawn card.
//
// The recipe is the tray strip's, in the same order (`modules/bar/widgets/Tray.qml`):
// the slot opens FIRST and the ink follows, so an arriving row never fades in inside a
// box still being cut open; on the way out the ink goes first and the box closes
// after, so the neighbours never slide across a readable card.
//
// THE GAP RIDES INSIDE THE SLOT. `Column.spacing` would leave its gap behind when a
// slot collapses to zero, so the row pitch is this item's height and the gap is baked
// into it - exactly why `Tray` keeps its `slotGap` inside each slot instead of in
// `Row.spacing`.
//
// And nothing here animates `y`. A row's position is whatever the layout says it is,
// so the rows below a collapsing slot move because the slot is shorter, not because a
// second animation pushed them - which is what makes the list read as closing rather
// than as a set of cards each playing its own part.
Item {
    id: root

    // The row this slot renders, as `WindowHintRowMotion.reconcileRows` built it. The
    // record is the durable half of the pair: this item is destroyed and rebuilt on
    // every publish, so anything that has to survive one lives on the record.
    property var record: null
    // Cards in the active column, plain labels in the neighbours. One component for
    // both, because a workspace column's two renderings differ in what they draw and
    // not in how they enter or leave - and the neighbour column would otherwise need
    // its own copy of the whole exit.
    property bool active: true
    property bool interactive: true

    property real rowHeight: 28
    property real listSpacing: 6
    property real glyphInset: 8
    property real glyphWidth: 16
    // The card's own width, resolved by the column so every row on a strip mid-resize
    // is given the same number rather than each measuring its own parent.
    property real cardWidth: 180
    // The focus mask, resolved by the column against this row's CONTENT item - the
    // mask is a geometric function of where the card is, and the card is inside here.
    // Handed in as a function so the arithmetic stays in the strip, where the frame's
    // own rectangle lives.
    property var maskFor: null
    property bool maskVisible: false

    // The slot's two states. `presence` is the height, `ink` is the content's opacity.
    property real presence: root.record && root.record.presence !== undefined
        ? root.record.presence : 1
    property real ink: root.record && root.record.ink !== undefined
        ? root.record.ink : 1
    // 0 at rest, 1 fully drawn inwards. The row leaves along its own axis - the card
    // shrinking towards its centre as it dissolves - which is the tray icon's fall
    // turned ninety degrees, and the same statement: it goes the way it is laid out.
    property real insetAmount: 0
    // 0 where a reorder found this row, 1 where it belongs. A window moved inside its
    // workspace keeps its row and travels to the new one, so this is the travel - and it is
    // the row's own clock, not the layout's: the slot above it may be collapsing on a
    // different curve at the same time, and the two displacements are added where the row
    // is placed rather than fought over here.
    readonly property string rowKey: root.record && root.record.key !== undefined
        ? String(root.record.key) : ""
    readonly property string phase: root.record && root.record.phase !== undefined
        ? String(root.record.phase) : "live"

    signal activated(string windowId)
    // The exit has played and the slot may go. Emitted by this item rather than counted
    // out by the column, so the thing that knows when its own animation finished is the
    // thing that says so.
    signal retireRequested(string rowKey)
    // The slot moved, which the column has to be TOLD because a record's `presence` is a
    // field of a plain object: writing it notifies nobody, so the layout arithmetic that
    // adds those presences up has no binding to invalidate on its own.
    signal rowMoved()

    // The gap is part of the slot, so a closed slot takes its gap with it.
    readonly property real slotPitch: root.rowHeight + root.listSpacing

    implicitWidth: cardWidth
    implicitHeight: slotPitch * presence
    width: implicitWidth
    height: implicitHeight
    // Off while it has no size or no ink: a slot mid-flight takes no hover and no tap,
    // and a half-dissolved card must not be clickable through its own fade.
    enabled: root.interactive && presence > 0.99 && ink > 0.99
    // NEVER `visible`, and that is a layout fact rather than an omission: a positioner
    // SKIPS an invisible child entirely, so a slot whose height was the thing being
    // animated would be dropped out of the column for the whole of its opening - the rows
    // below it would not move and a closing row would not close at all. A zero height is
    // what takes it out of the layout, and a zero-height slot paints nothing because its
    // content is given `rowHeight * presence` and the card fills that content.

    // Keep the record current, so a delegate rebuilt by the next publish resumes from
    // where this one had got to instead of starting the animation again.
    onPresenceChanged: {
        if (root.record)
            root.record.presence = root.presence
        root.rowMoved()
    }
    onInkChanged: if (root.record) root.record.ink = root.ink
    onSlotIndexChanged: root.rowMoved()

    // The row's content, in the slot's own space: full height while open, nothing while
    // closed. Sized from `presence` rather than from the slot's height so the content's
    // height and the slot's height are one number - a card shorter than its own box
    // would read as a card that shrank before the gap closed.
    Item {
        id: content
        objectName: "windowHintRowContent"
        x: root.insetAmount * MotionTokens.windowRowExitInset
        y: 0
        width: Math.max(0, root.cardWidth - 2 * root.insetAmount
            * MotionTokens.windowRowExitInset)
        height: root.rowHeight * root.presence
        opacity: root.ink

        // The active column's row: the card the panel has always drawn, now given its
        // record and the focus mask instead of a delegate's context.
        HintWindowCard {
            objectName: "windowHintWindowCard"
            visible: root.active
            anchors.fill: parent
            record: root.record
            glyphInset: root.glyphInset
            glyphWidth: root.glyphWidth
            interactive: root.enabled
            maskFor: root.maskFor
            maskVisible: root.maskVisible
            onActivated: windowId => root.activated(windowId)
        }

        // The neighbour column's row, which is the same label the panel has always
        // drawn: it brings its own hover, its own focus mask and its own tap, and the
        // slot here only decides when it may be seen.
        BarWindowHintLabel {
            id: label
            objectName: "windowHintNeighbourRow"
            visible: !root.active
            enabled: root.enabled
            // The label is a row, not a delegate of anything: it declares `modelData`
            // and `index` as required because it used to be instantiated by a
            // `Repeater`, and `index` is read by nothing in it. Handed the record and a
            // zero rather than left to a context property that no longer exists.
            modelData: root.record
            index: 0
            // Laid out from the slot's numbers rather than anchored: an anchor would
            // keep it at full height while the slot closed.
            width: content.width
            height: content.height
            rowHeight: root.rowHeight
            glyphInset: root.glyphInset
            glyphWidth: root.glyphWidth
            focusMaskTop: root.maskFor ? root.maskFor(label).top : 0
            focusMaskHeight: root.maskFor ? root.maskFor(label).height : 0
            focusMaskVisible: root.maskVisible
            onActivated: windowId => root.activated(windowId)
        }
    }

    // --- arrival: open the slot, then let the ink in ------------------------
    // Sequential on purpose, and it is the tray's ordering for the tray's reason: a row
    // that faded in while its slot was still opening would be a card drawn at forty
    // percent of its own height, which reads as a squeezed row rather than as one
    // arriving.
    SequentialAnimation {
        id: enterAnim
        animations: [openSlotAnim, enterInkAnim]
        onFinished: root.settlePhase("enter")
    }

    Timer {
        id: enterDelay
        onTriggered: enterAnim.restart()
    }

    NumberAnimation {
        id: openSlotAnim
        target: root
        property: "presence"
        to: 1
        duration: MotionTokens.windowRowEnter
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: enterInkAnim
        target: root
        property: "ink"
        to: 1
        duration: MotionTokens.windowRowEnterInk
        easing.type: Easing.OutQuad
    }

    // --- departure: dissolve the ink while the slot closes under it ----------
    // Parallel, and the two curves are deliberately different speeds. The ink is the
    // faster one and OutQuad, so the row is already going when the gap starts to close;
    // the slot is `slow` and InQuad, which starts gently and commits. The rows below
    // therefore ride up onto a row that has stopped being readable, which is the whole
    // of what "the list closes" has to look like.
    ParallelAnimation {
        id: exitAnim
        animations: [exitInkAnim, closeSlotAnim, insetAnim]
        // A departure ends by the slot being DROPPED, and this is the moment it is empty:
        // the group's own last frame, rather than a timer set from its nominal length.
        // The timer was tuned against `windowRowExit` while the animation itself is
        // shortened to the part of the leg that is left, so the gap it guessed at was the
        // one thing on screen that did not match the row above it - measured, a slot
        // dropped with eight pixels still in it and the rows below snapping that far.
        //
        // Guarded on the phase, because a publish can hand this delegate a different row
        // while it is still playing - and the row it is carrying now is not the row this
        // animation was for.
        onFinished: if (root._animPhase === "exit") root.retireRequested(root.rowKey)
    }

    Timer {
        id: exitDelay
        onTriggered: exitAnim.restart()
    }

    NumberAnimation {
        id: exitInkAnim
        target: root
        property: "ink"
        to: 0
        duration: MotionTokens.windowRowExitInk
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: closeSlotAnim
        target: root
        property: "presence"
        to: 0
        duration: MotionTokens.windowRowExit
        easing.type: Easing.InQuad
    }

    NumberAnimation {
        id: insetAnim
        target: root
        property: "insetAmount"
        to: 1
        duration: MotionTokens.windowRowExitInk
        easing.type: Easing.OutQuad
    }

    // A reorder: one ease over the whole swap, and `OutCubic` because it is a displacement
    // between two places that are both on screen. The row that left a place and the row
    // that took it are the same gesture, so they share a clock - see
    // `MotionTokens.windowRowMove`.
    // Drives the RECORD, not a property of this item, for the reason at `moveOffset`: the
    // item is rebuilt on the next publish and would lose whatever it was holding.
    // The travel itself, on a property of THIS item.
    //
    // It cannot animate `record.moveProgress`, and that was the whole reason the rows did
    // not move: a record is a plain JS object, so assigning one of its fields notifies
    // nothing - no binding that read it is invalidated, and the layout kept the offset it
    // computed on the first frame. A property of the item is a real QML property, so it
    // notifies, and the `rowMoved()` in its handler is what tells the strip that the sum
    // it places rows by has changed.
    //
    // The record still carries the START of the travel (`moveFrom`, `moveEpoch`), because
    // that has to survive the delegate being rebuilt; the PROGRESS lives here, because it
    // only means anything while this item is drawing.
    property real _moveProgress: 1
    on_MoveProgressChanged: root.rowMoved()

    NumberAnimation {
        id: moveAnim
        target: root
        property: "_moveProgress"
        to: 1
        duration: MotionTokens.windowRowMove
        easing.type: Easing.OutCubic
        // The travel is SPENT once it has arrived, and the record says so. `moveFrom` is
        // what the next delegate reads to know where to start, so leaving it set makes every
        // later rebuild of this row replay the same journey - measured, a reorder followed
        // by a departing slot being retired slid the moved row into place and then slid it
        // again from the same place, because the record still named it.
        onFinished: if (root.record) root.record.moveFrom = -1
    }

    // The resting state, written without an animation: the values a finished entry
    // would have left behind. It is the reduced-motion answer and the one a row created
    // into a settled list takes.
    function snap() {
        enterDelay.stop()
        exitDelay.stop()
        enterAnim.stop()
        exitAnim.stop()
        root.insetAmount = 0
        root.presence = 1
        root.ink = 1
    }

    // An animation has run to its end, so the row is where it was going. Written as a
    // function and called from the animations' own handlers rather than inline, because
    // the record it writes is no longer necessarily the one the animation was started
    // for: a `Repeater` whose model keeps its count reuses its delegate, so a publish can
    // hand this item a different row while an animation for the old one is still
    // running. Reporting that animation's completion onto the NEW record is what kept a
    // closing row's phase reading `"live"` - measured, a row leaving next to a row
    // arriving settled back to rest one frame after its exit began, and the exit never
    // played at all.
    //
    // So the phase is written only when it still says what this animation was for, and
    // the item's own memory of what it is playing is cleared with it - left on `"enter"`,
    // a later record saying `"enter"` again would be read as "nothing changed" and would
    // start from wherever this item had settled instead of from zero.
    function settlePhase(phase) {
        if (root._animPhase !== phase)
            return
        if (phase === "live") {
            root.presence = 1
            root.ink = 1
            root.insetAmount = 0
        }
        if (root.record)
            root.record.phase = "live"
        root._animPhase = "live"
    }

    // `resume` says this delegate was created into an animation already under way: the
    // record carries the values it had reached, and only the part of each leg that is
    // left runs. Without it every publish would restart the animation it is meant to be
    // continuing, and a row mid-flight would take the full duration again.
    function startEnter(resume) {
        if (MotionTokens.reducedMotion) {
            root.snap()
            return
        }
        enterDelay.interval = resume ? 0
            : (root.record ? Number(root.record.delayMs) || 0 : 0)
        openSlotAnim.duration = MotionTokens.windowRowEnter
            * Math.max(0.05, 1 - root.presence)
        enterInkAnim.duration = MotionTokens.windowRowEnterInk
            * Math.max(0.05, 1 - root.ink)

        if (enterDelay.interval > 0)
            enterDelay.restart()
        else
            enterAnim.restart()
    }

    function startExit(resume) {
        if (MotionTokens.reducedMotion) {
            root.presence = 0
            root.ink = 0
            root.insetAmount = 1
            root.retireRequested(root.rowKey)
            return
        }
        exitDelay.interval = resume ? 0
            : (root.record ? Number(root.record.delayMs) || 0 : 0)
        // The same rule as an arrival's: only the remaining part of each leg. The
        // durations are per-delegate because a delegate is rebuilt on every publish, so
        // a curve started again at its own beginning is a row that restarts its exit
        // each time something else about the workspace changes.
        exitInkAnim.duration = MotionTokens.windowRowExitInk * Math.max(0.05, root.ink)
        closeSlotAnim.duration = MotionTokens.windowRowExit * Math.max(0.05, root.presence)
        insetAnim.duration = MotionTokens.windowRowExitInk
            * Math.max(0.05, 1 - root.insetAmount)
        if (exitDelay.interval > 0)
            exitDelay.restart()
        else
            exitAnim.restart()
    }

    // The phase this item is currently playing, so an unrelated publish can be told
    // apart from the event this component exists to animate.
    property string _animPhase: ""

    // Take this item's state from its record. Called when the item is created AND when
    // the record under it is replaced, because those are two different things and only
    // one of them constructs the item: a `Repeater` whose model keeps its count REUSES
    // its delegates and re-evaluates their bindings, so a publish that closes one row and
    // opens another hands an existing slot a new record without ever running
    // `Component.onCompleted` on it. Without this the slot would keep the progress it had
    // and the new record's phase would be a word nothing acted on - measured, a row
    // arriving next to a row leaving sat at presence 1 from the first frame while the
    // record still said `"enter"`.
    function syncFromRecord() {
        if (!root.record)
            return
        const phase = root.phase
        // A REORDER is its own event and it is orthogonal to the phase: the row stays
        // `"live"` through it, because nothing about it is arriving or leaving. Handled
        // first and outside the phase gate below, or the very case this exists for - a
        // settled row that moved - would be answered "nothing changed".
        root.syncMove()
        // The same phase this item is already in: the publish said nothing about this
        // row, so nothing restarts. Only a settled row adopts a value it somehow missed.
        if (phase === root._animPhase) {
            if (phase === "live" && !enterAnim.running && !exitAnim.running)
                root.snap()
            return
        }
        root._animPhase = phase
        root.presence = root.record.presence !== undefined ? root.record.presence : 1
        root.ink = root.record.ink !== undefined ? root.record.ink : 1
        root.insetAmount = phase === "exit" ? 1 - root.presence : 0
        const resume = root.record.started === true
        if (phase === "enter")
            root.startEnter(resume)
        else if (phase === "exit")
            root.startExit(resume)
        else
            root.snap()
        root.record.started = true
    }

    // A REORDER, and why its state lives on the record and not here.
    //
    // `Repeater` is given the row COUNT, and it rebuilds its delegates on every publish -
    // measured, three items for a list of three replaced by three new ones for the same
    // three rows. So an item cannot remember where it was: it does not survive the frame
    // the list changes on. What survives is the record, exactly as it does for `presence`
    // and `ink`, and the reconcile is what knows both positions - where the window was and
    // where it went. This item's job is only to DRIVE the progress the record carries.
    //
    // The travel is in ROW PITCHES, and it is signed: a row that moved up starts below its
    // new place and has to come up to it.
    readonly property real moveOffset: {
        if (!root.record || root.record.moveFrom === undefined || root.record.moveFrom < 0)
            return 0
        var progress = Math.max(0, Math.min(1, root._moveProgress))
        return (root.record.moveFrom - root.slotIndex) * (1 - progress)
    }
    // This slot's own index in the column. Handed in rather than `index`, because the
    // `Repeater`'s injected `index` is the slot's place and the travel is measured against
    // the ROW's place - see the note above.
    property int slotIndex: -1

    // Start the travel the record is carrying, if it is carrying one this item has not
    // already begun. `moveEpoch` is the tell: the record outlives the item, so "there is a
    // move in flight" is not enough - a second move landing before the first finished has
    // the same shape, and only a counter says "this is a new journey".
    property int _drivenEpoch: -1
    function syncMove() {
        if (!root.record)
            return
        const epoch = root.record.moveEpoch === undefined ? 0 : root.record.moveEpoch
        if (epoch === root._drivenEpoch)
            return
        root._drivenEpoch = epoch
        if (root.record.moveFrom === undefined || root.record.moveFrom < 0)
            return
        // From the old place. Written before the restart so the animation's `from` is the
        // start of this travel rather than wherever the record happened to be.
        root._moveProgress = 0
        if (MotionTokens.reducedMotion) {
            root._moveProgress = 1
            root.record.moveFrom = -1
            return
        }
        moveAnim.restart()
    }

    onRecordChanged: {
        root.syncMove()
        root.syncFromRecord()
    }
    Component.onCompleted: {
        root.syncMove()
        root.syncFromRecord()
    }
}
