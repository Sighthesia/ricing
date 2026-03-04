import QtQuick

// General-purpose stagger animation wrapper.
//
// Wrap ANY Item content inside StaggerItem and call runEnter() / runExit()
// from the parent to animate in/out with configurable delay, duration and
// Y-offset.  Suitable for list delegates (Repeater), structural blocks,
// and individual menu items.
//
// Typical usage for a Repeater delegate:
//
//   StaggerItem {
//       required property int index
//       delay:     120 + index * 50   // enter: stagger downward by index
//       exitDelay: index * 15         // exit:  stagger downward by index
//       width: parent.width
//       height: _content.implicitHeight
//
//       Connections { target: groupSignalSource
//           function onEnter() { runEnter() }
//           function onExit()  { runExit()  }
//       }
//
//       Column { id: _content; ... }
//   }
Item {
    id: staggerItem

    // Delay (ms) before the ENTER animation begins after runEnter() is called.
    // Use: baseDelay + index * step for list delegates.
    property int delay: 0

    // Delay (ms) before the EXIT animation begins after runExit() is called.
    // Defaults to 0 (immediate start) — set explicitly per-delegate when needed.
    property int exitDelay: 0

    // Duration for enter/exit animations.
    property int enterDuration: 280
    property int exitDuration:  100

    // Y translation distance: items slide UP from +enterOffsetY to 0 on enter,
    // and slide DOWN from 0 to +exitOffsetY on exit.
    property real enterOffsetY: 30.0
    property real exitOffsetY:  10.0

    // Initial state: invisible and offset downward.
    // runEnter() snaps to this state before starting the timer, ensuring a
    // clean cycle even when called repeatedly (e.g. panel rapidly toggled).
    opacity: 0.0
    property real _ty: enterOffsetY
    transform: Translate { y: staggerItem._ty }

    // Public API ─────────────────────────────────────────────────────────────

    // Start the enter animation after `delay` ms:
    //   opacity 0→1 + translateY enterOffsetY→0, using OutCubic easing.
    function runEnter() {
        _enterTimer.stop()
        _exitTimer.stop()
        _opacityExit.stop()
        _offsetExit.stop()
        // Snap to initial state (handles interrupted cycle gracefully)
        staggerItem.opacity = 0.0
        staggerItem._ty     = enterOffsetY
        _enterTimer.interval = staggerItem.delay
        _enterTimer.restart()
    }

    // Start the exit animation after `exitDelay` ms:
    //   opacity 1→0 + translateY 0→exitOffsetY, using InCubic easing.
    function runExit() {
        _enterTimer.stop()
        _opacityEnter.stop()
        _offsetEnter.stop()
        _exitTimer.interval = staggerItem.exitDelay
        _exitTimer.restart()
    }

    // ── Internal machinery ────────────────────────────────────────────────────

    Timer { id: _enterTimer; repeat: false; onTriggered: { _opacityEnter.restart(); _offsetEnter.restart() } }
    Timer { id: _exitTimer;  repeat: false; onTriggered: { _opacityExit.restart();  _offsetExit.restart()  } }

    PropertyAnimation {
        id: _opacityEnter; target: staggerItem; property: "opacity"
        to: 1.0; duration: staggerItem.enterDuration; easing.type: Easing.OutCubic
    }
    PropertyAnimation {
        id: _offsetEnter; target: staggerItem; property: "_ty"
        to: 0.0; duration: staggerItem.enterDuration; easing.type: Easing.OutCubic
    }
    PropertyAnimation {
        id: _opacityExit; target: staggerItem; property: "opacity"
        to: 0.0; duration: staggerItem.exitDuration; easing.type: Easing.InCubic
    }
    PropertyAnimation {
        id: _offsetExit; target: staggerItem; property: "_ty"
        to: staggerItem.exitOffsetY; duration: staggerItem.exitDuration; easing.type: Easing.InCubic
    }
}
