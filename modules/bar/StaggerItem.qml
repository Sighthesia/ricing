import QtQuick
import qs.services

// General-purpose stagger animation wrapper.
//
// Wrap ANY Item content inside StaggerItem and call runEnter() / runExit()
// from the parent to animate in/out with configurable delay, duration and
// X/Y-offset. Suitable for list delegates (Repeater), structural blocks,
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

    implicitWidth: width
    implicitHeight: height

    // Delay (ms) before the ENTER animation begins after runEnter() is called.
    // Use: baseDelay + index * step for list delegates.
    property int delay: 0

    // Delay (ms) before the EXIT animation begins after runExit() is called.
    // Defaults to 0 (immediate start) — set explicitly per-delegate when needed.
    property int exitDelay: 0

    // Duration for enter/exit animations.
    property int enterDuration: SettingsService.effectiveAnimation.staggerEnterDuration
    property int exitDuration:  SettingsService.effectiveAnimation.staggerExitDuration

    // Translation distance: items can start offset on enter and retire with a
    // separate exit offset.
    property real enterOffsetX: 0
    property real enterOffsetY: SettingsService.effectiveAnimation.staggerEnterOffsetY
    property real exitOffsetX: 0
    property real exitOffsetY:  SettingsService.effectiveAnimation.staggerExitOffsetY
    property real enterStartOpacity: 0.0
    property real enterStartOffsetX: enterOffsetX
    property real enterStartOffsetY: enterOffsetY

    // Initial state: invisible and offset downward.
    // runEnter() snaps to this state before starting the timer, ensuring a
    // clean cycle even when called repeatedly (e.g. panel rapidly toggled).
    opacity: 0.0
    property real _tx: enterOffsetX
    property real _ty: enterOffsetY
    transform: Translate {
        x: staggerItem._tx
        y: staggerItem._ty
    }

    // Public API ─────────────────────────────────────────────────────────────

    function stopAnimations() {
        _enterTimer.stop()
        _exitTimer.stop()
        _opacityEnter.stop()
        _offsetXEnter.stop()
        _offsetEnter.stop()
        _opacityExit.stop()
        _offsetXExit.stop()
        _offsetExit.stop()
    }

    // Start the enter animation after `delay` ms.
    function runEnter() {
        stopAnimations()
        // Snap to initial state (handles interrupted cycle gracefully)
        staggerItem.opacity = enterStartOpacity
        staggerItem._tx     = enterStartOffsetX
        staggerItem._ty     = enterStartOffsetY
        _enterTimer.interval = staggerItem.delay
        _enterTimer.restart()
    }

    // Start the exit animation after `exitDelay` ms.
    function runExit() {
        _enterTimer.stop()
        _opacityEnter.stop()
        _offsetXEnter.stop()
        _offsetEnter.stop()
        _opacityExit.stop()
        _offsetXExit.stop()
        _offsetExit.stop()
        _exitTimer.interval = staggerItem.exitDelay
        _exitTimer.restart()
    }

    // ── Internal machinery ────────────────────────────────────────────────────

    Timer {
        id: _enterTimer
        repeat: false
        onTriggered: {
            _opacityEnter.restart()
            _offsetXEnter.restart()
            _offsetEnter.restart()
        }
    }
    Timer {
        id: _exitTimer
        repeat: false
        onTriggered: {
            _opacityExit.restart()
            _offsetXExit.restart()
            _offsetExit.restart()
        }
    }

    PropertyAnimation {
        id: _opacityEnter; target: staggerItem; property: "opacity"
        to: 1.0; duration: staggerItem.enterDuration; easing.type: Easing.OutCubic
    }
    PropertyAnimation {
        id: _offsetXEnter; target: staggerItem; property: "_tx"
        to: 0.0; duration: staggerItem.enterDuration; easing.type: Easing.OutCubic
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
        id: _offsetXExit; target: staggerItem; property: "_tx"
        to: staggerItem.exitOffsetX; duration: staggerItem.exitDuration; easing.type: Easing.InCubic
    }
    PropertyAnimation {
        id: _offsetExit; target: staggerItem; property: "_ty"
        to: staggerItem.exitOffsetY; duration: staggerItem.exitDuration; easing.type: Easing.InCubic
    }
}
