// The ONE owner of a selection marker's position.
//
// A marker is drawn twice - an outline around the focused card and a bar beside it - and
// both are placed from this component's `position` and `tail`. Two drawing elements with
// two animations that have to agree are two animations that can disagree: measured in the
// window hint panel, the outline and the bar sat a whole row apart for the length of an
// exit, each certain it was right.
//
// The state machine is `SelectionMarkerMotion.js`; this file is the QML shell that gives it
// a clock and publishes its two numbers. Nothing else may write them.
//
// REFERENCE: the mode split (fixed target eased, moving target followed) is
// `modules/lazerbar/TrailIndicator.qml`'s, which already carries it for the workspace strip.
// What is not ported is that component's state: it is a marker AND a host in one file, and
// the failures in the window hint panel came from that doubling - several writers, one set
// of properties.
import QtQuick
import Quickshell
import "../lazerbar"
import "SelectionMarkerMotion.js" as SelectionMarkerMotion
import "MotionTokensBridge.js" as MotionTokensBridge

Item {
    id: root

    // WHERE THE MARK IS AIMED. Published by the host, which is the only thing that knows
    // where its rows are:
    //   { key: string, top: real, moving: bool, valid: bool }
    //
    // `key` is the WINDOW, not a row index: it is what tells a focus change (travel) from a
    // layout change (follow). `top` is in the host's own scrolled space. `moving` says the
    // row is being carried right now.
    property var anchor: null

    // The marker's own numbers, and the only ones anything draws from.
    // `revision` is read for its DEPENDENCY and nothing else: `_state` is a plain JS object
    // and writing a field on it notifies nobody, so every value derived from it has to say
    // which tick it belongs to.
    readonly property real position: { revision; return _state.position }
    readonly property real tail: { revision; return _state.tail }
    readonly property real trailLength: { revision; return Math.abs(_state.position - _state.tail) }
    readonly property string mode: { revision; return _state.mode }
    readonly property bool valid: { revision; return _state.valid }

    // The state machine's numbers, in a plain object: a JS object's fields do not notify, so
    // `revision` is bumped on every tick and the properties above read it for their
    // dependency. One revision for the whole object, like the strip's `rowRevision`.
    property var _state: SelectionMarkerMotion.createState()
    property int revision: 0

    readonly property bool _animate: !MotionTokens.reducedMotion

    // Durations come from `MotionTokens` through the bridge, so the state machine never
    // carries a magic number and this file never carries a second copy of one.
    Component.onCompleted: {
        MotionTokensBridge.configure(MotionTokens.medium, 0.2)
    }

    // A new anchor is an EVENT, not a per-frame value: the host publishes one when its
    // layout or its focus changes. That is the whole reason this is a function call and not
    // a binding - a binding would re-aim on every frame of a card's own motion, which is the
    // restart-from-here loop that froze the marker in every earlier attempt.
    onAnchorChanged: _reaim()

    function _reaim() {
        if (!anchor || !_clock)
            return
        SelectionMarkerMotion.aim(_state, anchor, !_animate)
        revision++
        if (_state.mode === SelectionMarkerMotion.MODE_IDLE)
            _stopClock()
        else
            _startClock()
    }

    function _startClock() {
        if (_clock && !_clock.running)
            _clock.start()
    }
    function _stopClock() {
        if (_clock && _clock.running)
            _clock.stop()
        _lastTick = 0
    }

    // The clock: only runs while something is moving, so a settled panel costs nothing.
    property double _lastTick: 0
    Timer {
        id: _clock
        interval: 16
        repeat: true
        running: false
        onTriggered: {
            var now = Date.now()
            var dt = root._lastTick > 0 ? Math.min(64, now - root._lastTick) : 16
            root._lastTick = now
            if (SelectionMarkerMotion.step(root._state, dt, !root._animate))
                root.revision++
            else
                root._stopClock()
        }
        onRunningChanged: if (running) root._lastTick = 0
    }

    // Start from where the anchor says, without a first-frame jump from zero. Called by the
    // host when the surface opens: a panel that is shown again should begin settled.
    function place() {
        if (!anchor || anchor.valid !== true)
            return
        _state.position = anchor.top
        _state.tail = anchor.top
        _state.target = anchor.top
        _state.key = String(anchor.key)
        _state.valid = true
        _state.mode = SelectionMarkerMotion.MODE_IDLE
        _state.duration = 0
        _state.elapsed = 0
        revision++
    }

    function settleNow() {
        SelectionMarkerMotion.settle(_state)
        revision++
        _clock.stop()
        _lastTick = 0
    }
}
