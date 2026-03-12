import Quickshell
import QtQuick
import qs.config

// Animated drop-down base for PanelWindows.
//
// Replace `visible:` with `active:` in subtype declarations and use this
// component as the root element instead of PanelWindow.  Children placed
// directly inside this component are automatically routed into the animated
// wrapper item via the default alias.
//
// Open sequence : scaleY 0→1 (OutBack 280ms) + opacity 0→1 (OutQuad 180ms, delayed 60ms)
// Close sequence: opacity 1→0 (InQuad 120ms) || scaleY 1→0 (InBack 200ms) simultaneously
// Origin is at (0,0) — the panel grows downward from the bar's bottom edge.
PanelWindow {
    id: root

    // Children placed in this component are routed into the animated wrapper.
    default property alias data: _wrapper.data

    // Logical open/close trigger — replaces `visible:` bindings in child panels.
    property bool active: false
    property int openOpacityDelay: Math.max(1, Math.round(Theme.anim.highlightDuration / 3))
    property int openOpacityDuration: Theme.anim.highlightDuration
    property int openScaleDuration: Math.max(1, Math.round(Theme.anim.springDuration * 0.78))
    property int closeOpacityDelay: 0
    property int closeOpacityDuration: Math.max(1, Math.round(Theme.anim.highlightDuration * 0.67))
    property int closeScaleDuration: Math.max(1, Math.round(Theme.anim.springDuration * 0.56))
    property int closeScaleDelay: 0

    color: "transparent"

    // Keep Wayland surface alive while the close animation is still running;
    // only destroy it once the state machine reaches "closed".
    visible: _state !== "closed"

    // Internal state machine: "closed" | "opening" | "open" | "closing"
    property string _state: "closed"

    // Broadcast open/close transitions so child content can run stagger animations.
    // Emitted before animations start, giving listeners time to schedule their own timers.
    signal panelOpening
    signal panelClosing

    onActiveChanged: {
        if (active) {
            if (_state === "closed" || _state === "closing") {
                _scaleCloseAnim.stop();
                _opacityCloseAnim.stop();
                _closeOpacityDelayTimer.stop();
                _closeScaleDelayTimer.stop();
                _opacityDelayTimer.stop();

                _state = "opening";
                panelOpening();
                _scaleOpenAnim.restart();
                _opacityDelayTimer.restart();
            }
        } else {
            if (_state === "open" || _state === "opening") {
                _scaleOpenAnim.stop();
                _opacityOpenAnim.stop();
                _opacityDelayTimer.stop();
                _closeOpacityDelayTimer.stop();
                _closeScaleDelayTimer.stop();

                _state = "closing";
                panelClosing();
                if (root.closeOpacityDelay > 0)
                    _closeOpacityDelayTimer.restart();
                else
                    _opacityCloseAnim.restart();
                if (root.closeScaleDelay > 0)
                    _closeScaleDelayTimer.restart();
                else
                    _scaleCloseAnim.restart();
            }
        }
    }

    // Short delay ensures the scale grow starts visually before the fade-in,
    // mirroring noctalia's sequential opacity trigger.
    Timer {
        id: _opacityDelayTimer
        interval: root.openOpacityDelay
        repeat: false
        onTriggered: _opacityOpenAnim.restart()
    }

    Timer {
        id: _closeOpacityDelayTimer
        interval: root.closeOpacityDelay
        repeat: false
        onTriggered: _opacityCloseAnim.restart()
    }

    Timer {
        id: _closeScaleDelayTimer
        interval: root.closeScaleDelay
        repeat: false
        onTriggered: _scaleCloseAnim.restart()
    }

    // Scale open: 0 → 1, OutBack gives the subtle overshoot that makes the panel
    // feel "snappy" rather than just linearly growing.
    PropertyAnimation {
        id: _scaleOpenAnim
        target: _wrapper
        property: "_scaleY"
        to: 1.0
        duration: root.openScaleDuration
        easing.type: Easing.OutBack
        easing.overshoot: 0.7
        onFinished: if (root._state === "opening") root._state = "open"
    }

    // Scale close: 1 → 0, InBack produces a slight pull-back before the panel
    // shrinks — complement to the OutBack opening feel.
    PropertyAnimation {
        id: _scaleCloseAnim
        target: _wrapper
        property: "_scaleY"
        to: 0.0
        duration: root.closeScaleDuration
        easing.type: Easing.InBack
        easing.overshoot: 0.7
        onFinished: if (root._state === "closing") root._state = "closed"
    }

    // Opacity open: delayed to emphasise the scale motion first.
    PropertyAnimation {
        id: _opacityOpenAnim
        target: _wrapper
        property: "opacity"
        to: 1.0
        duration: root.openOpacityDuration
        easing.type: Easing.OutQuad
    }

    // Opacity close: fast fade — content disappears quickly so the shrink feels clean.
    PropertyAnimation {
        id: _opacityCloseAnim
        target: _wrapper
        property: "opacity"
        to: 0.0
        duration: root.closeOpacityDuration
        easing.type: Easing.InQuad
    }

    // Animated wrapper ─ transforms are applied here so child layout is unaffected;
    // children see a full-size parent and their anchors.fill: parent bindings work
    // exactly as if they were direct children of the PanelWindow.
    Item {
        id: _wrapper
        anchors.fill: parent
        opacity: 0.0
        property real _scaleY: 0.0

        // Origin at the top-left corner of the window (= bar's bottom edge when
        // the window uses anchors { top: true } with margins { top: barHeight }).
        transform: Scale {
            origin.x: 0
            origin.y: 0
            xScale: 1.0
            yScale: _wrapper._scaleY
        }
    }
}
