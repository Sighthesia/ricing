import QtQuick
import qs.config

// Interruption-safe, committed wipe-reveal highlight.
//
// Design: track left/right edges of the colored bar independently.
//   Enter — rightEdge advances 0 → width  (OutCubic)
//   Exit  — leftEdge chases rightEdge      (InCubic)
//
// Commitment rule:
//   - Enter always plays to full completion; a mouse-leave mid-enter is
//     queued as a pending exit that fires automatically when enter finishes.
//   - Exit can be interrupted immediately by a re-enter (the user is back,
//     no point completing the disappear stroke).
//
// This component is the canonical hover-highlight rule for the whole shell.
// Usage:
//   HoverRevealHighlight {
//     anchors.fill: parent
//     hovered: someMouseArea.containsMouse
//     highlightColor: Colors.surface
//     highlightOpacity: 0.5
//     radius: Theme.cornerRadius - 4
//   }
Item {
    id: root

    property bool hovered: false
    property color highlightColor: Colors.highlight
    property real highlightOpacity: 0.12
    property real radius: 0
    // Enter uses moveDuration (slower reveal); exit uses highlightDuration (quick sweep).
    // Both can be overridden per-instance.
    property int enterDuration: Theme.anim.moveDuration
    property int exitDuration: Theme.anim.highlightDuration

    // Internal edge positions — do not bind externally.
    property real _rightEdge: 0
    property real _leftEdge: 0
    // Queued exit: set when mouse leaves while enter is still running.
    property bool _pendingExit: false

    clip: true

    // Wipe bar
    Rectangle {
        x: root._leftEdge
        width: Math.max(0, root._rightEdge - root._leftEdge)
        height: parent.height
        radius: root.radius
        color: root.highlightColor
        opacity: root.highlightOpacity
    }

    onHoveredChanged: {
        if (hovered) {
            _pendingExit = false
            _leftEdgeAnim.stop()
            // If the bar was fully swept away, start from scratch.
            if (_rightEdge <= _leftEdge) {
                _leftEdge = 0
                _rightEdge = 0
            }
            // Advance right edge from its current position; scale duration to
            // remaining distance so speed feels uniform even after an interrupt.
            _rightEdgeAnim.from     = _rightEdge
            _rightEdgeAnim.to       = root.width
            _rightEdgeAnim.duration = root.width > 0
                ? Math.max(1, Math.round(root.enterDuration * (root.width - _rightEdge) / root.width))
                : root.enterDuration
            _rightEdgeAnim.restart()
        } else {
            if (_rightEdgeAnim.running) {
                // Enter is still in flight — commit to finishing it, then auto-exit.
                _pendingExit = true
            } else {
                _doExit()
            }
        }
    }

    function _doExit() {
        _pendingExit = false
        _leftEdgeAnim.from     = _leftEdge
        _leftEdgeAnim.to       = _rightEdge
        _leftEdgeAnim.duration = root.width > 0
            ? Math.max(1, Math.round(root.exitDuration * (_rightEdge - _leftEdge) / root.width))
            : root.exitDuration
        _leftEdgeAnim.restart()
    }

    // Pushes the right (leading) edge rightward — the reveal stroke.
    NumberAnimation {
        id: _rightEdgeAnim
        target: root
        property: "_rightEdge"
        easing.type: Easing.OutCubic
        onFinished: if (root._pendingExit) root._doExit()
    }

    // Pushes the left (trailing) edge rightward — the wipe-away stroke.
    NumberAnimation {
        id: _leftEdgeAnim
        target: root
        property: "_leftEdge"
        easing.type: Easing.InCubic
        onFinished: {
            root._leftEdge  = 0
            root._rightEdge = 0
        }
    }
}
