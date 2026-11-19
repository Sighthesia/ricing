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
    // `LazerTheme.textPrimary`; the rest leave the default, which follows the
    // scheme: a light surface takes the theme colour so the blink reads as colour
    // instead of as the control dimming.
    color: LazerTheme.clickFlashWash
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

    // Halo around the wash: light leaving the host surface, so a click still
    // reads on a control too small or too dark to show the wash itself.
    property bool glow: true
    property color glowColor: LazerTheme.flashGlow
    property real glowSpread: 8
    // Follows this layer's own radius, so a caller that set one gets a halo that
    // wraps its corners without having to pass the radius a second time.
    property real glowRadius: root.radius

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

    // The wash's own halo, painted outside this layer's bounds. It follows the
    // same fade, so there is no second animation to keep in step, and the
    // scheme's correction rides the layer's opacity rather than the panel alphas
    // (a factor above 1 in those would clip the ramp flat).
    GlowBleed {
        anchors.fill: parent
        visible: root.glow && root.opacity > 0.001
        opacity: Math.min(1, root.opacity * LazerTheme.flashGlowGain)
        glowColor: root.glowColor
        spread: root.glowSpread
        surfaceRadius: root.glowRadius
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
