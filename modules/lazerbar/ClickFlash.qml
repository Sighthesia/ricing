import QtQuick

// The shell's one click-flash: a non-interactive wash that fades out over
// `MotionTokens.clickFlashDuration` to confirm an accepted activation.
//
// It is a Rectangle on purpose. Every call site already anchors a flash layer
// over its own surface, and the anchors, radius and colour are the only things
// that differ between them - so this keeps that shape (anchor it like the layer
// it replaces) and owns the part that must not differ: the timing, the easing,
// the reduced-motion behaviour, and the "start from full opacity, not from
// wherever it currently is" restart.
//
// Restart semantics matter: `NumberAnimation.restart()` assigns `from`
// synchronously, so `flashActive` reads true on the click frame. A test never
// has to sample mid-decay, and a second click during a fade restarts the wash
// instead of stacking a second one.
Rectangle {
    id: root

    // Callers that paint their wash over a lifted surface pass
    // `LazerTheme.textPrimary`; the rest leave the default.
    color: LazerTheme.textPrimary
    // A wash that confirms a discrete value change follows the part of the
    // control that carries it (a slider's travelled fill), not the whole
    // control. Those callers leave `followItem` set and keep their own
    // geometry; every other caller anchors this layer itself.
    property Item followItem: null
    opacity: 0
    // Never takes input: the layer sits above the control it confirms.
    enabled: false

    // Follow the carrier's travelled geometry when one was given. Written as
    // anchors rather than x/y/width/height so a caller that does NOT pass a
    // carrier keeps its own anchoring untouched - assigning those four
    // properties here would silently override `anchors.fill` on every other
    // instance.
    anchors.fill: followItem
    visible: followItem === null || followItem.visible

    // True while a wash is visible, including the frame it was started on.
    readonly property bool flashActive: flashAnimation.running || root.opacity > 0
    // Published for hosts that forward the seam to a test.
    readonly property Item flashOverlayItem: root
    readonly property Animation flashAnimationItem: flashAnimation

    // Play the wash from full strength. Reduced motion lands on the end state
    // instead of travelling, and a disabled host never flashes at all.
    function restart() {
        if (MotionTokens.reducedMotion) {
            flashAnimation.stop()
            root.opacity = 0
            return
        }
        flashAnimation.restart()
    }

    // Stop the wash without waiting for it to fade.
    function cancel() {
        flashAnimation.stop()
        root.opacity = 0
    }

    NumberAnimation {
        id: flashAnimation

        target: root
        property: "opacity"
        from: MotionTokens.clickFlashOpacity
        to: 0
        duration: MotionTokens.clickFlashDuration
        easing.type: MotionTokens.clickFlashEasing
        running: false
    }

    // A user who turns reduced motion on mid-fade must not be left with a wash
    // that keeps decaying on a curve they asked not to see.
    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion)
                root.cancel()
        }
    }
}
