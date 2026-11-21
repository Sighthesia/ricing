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
    // The surface this flash lands on, when the host knows it. A bar widget's
    // light lands on the bar's tinted field, not on paper, and a halo that ignores
    // that reads as a white ring floating over it.
    property color surfaceColor: "transparent"
    // Derived from this layer's own tint, so the light and the wash it belongs to
    // can never be two different colours.
    property color glowColor: LazerTheme.glowFor(root.color, root.surfaceColor)
    property real glowSpread: 8
    // Follows this layer's own radius, so a caller that set one gets a halo that
    // wraps its corners without having to pass the radius a second time.
    property real glowRadius: root.radius
    // The alpha the halo reaches on its first frame. It is stated as a peak in
    // its own right, not as a multiple of the wash: this layer's opacity tops out
    // at clickFlashOpacity (0.3), so a halo parented inside it could never
    // out-read the wash, and the light would be capped at a tenth of the contrast
    // it needs on a light surface.
    readonly property real glowPeak: Math.min(1, MotionTokens.clickFlashOpacity
                                                * LazerTheme.flashGlowGain)

    // True while a wash is visible, including the frame it was started on.
    readonly property bool flashActive: flashAnimation.running || root.opacity > 0
    // Published for hosts that forward the seam to a test.
    readonly property Item flashOverlayItem: root
    readonly property Animation flashAnimationItem: flashAnimation

    // Play the wash from full strength. Reduced motion lands on the end state
    // instead of travelling, and a disabled host never flashes at all.
    function restart() {
        if (MotionTokens.reducedMotion) {
            cancel()
            return
        }
        flashAnimation.restart()
        haloAnimation.restart()
    }

    // Stop the wash without waiting for it to fade.
    function cancel() {
        flashAnimation.stop()
        haloAnimation.stop()
        root.opacity = 0
        halo.opacity = 0
    }

    // The wash's own halo. It is a sibling of this layer rather than a child on
    // purpose: a child would inherit the wash's peak opacity and be held to a
    // fraction of the contrast a halo needs, so it would only ever read as a
    // slightly darker edge (measured: a 9% dip on a light surface). Laid over the
    // same rectangle and faded on the same clock, it reaches its own peak while
    // the wash reaches its own.
    GlowBleed {
        id: halo

        parent: root.parent
        x: root.x
        y: root.y
        width: root.width
        height: root.height
        // Above its siblings, so the corner patches wrap this control's own
        // rounded corners instead of disappearing under a neighbour.
        z: root.z + 1
        visible: root.glow && root.parent !== null && haloAnimation.running
        glowColor: root.glowColor
        spread: root.glowSpread
        surfaceRadius: root.glowRadius
        edgeAlpha: LazerTheme.flashGlowEdge

        // Same restart, duration and easing as the wash, so the two can never
        // drift apart: both are driven from the one `restart()` call.
        NumberAnimation on opacity {
            id: haloAnimation

            from: root.glowPeak
            to: 0
            duration: MotionTokens.clickFlashDuration
            easing.type: MotionTokens.clickFlashEasing
            running: false
        }
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
