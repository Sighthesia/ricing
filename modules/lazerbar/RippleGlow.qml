import QtQuick
import "RippleGlowLogic.js" as Glow

// Show the shell's glow pulse, clipped to one host surface.
//
// The pulse is global: one ring, in screen coordinates, owned by
// RipplePulseService. This component does not re-fit it. It hands over the
// screen extent, projects the ring's origin from the screen into its own
// coordinates, and lets `clip` mask whatever part of the ring crosses it — so
// the card shows a slice of exactly the ring the bar shows, at the same moment
// and at the same weight, instead of a second smaller version of the effect.
//
// Two properties the full-screen version got for free and this one earns:
//   * nothing fades — the ring holds full strength for the whole sweep and the
//     pulse ends because the light has left the display, not because it stopped
//     shining;
//   * nothing lingers — every layer is a ring hugging the leading edge, so no
//     layer can cover a surface and sit on it as a flat tint.
Item {
    id: root

    // The shared pulse. Injected rather than imported so this component stays
    // loadable — and testable — without Quickshell; production passes
    // RipplePulseService.
    property var pulse: null
    // This surface's output. A pulse tagged for another screen is not ours to
    // answer; an untagged one is every screen's to answer.
    property string screenName: ""
    // The output the ring is defined against. Both hosts know it, and it is
    // what makes the ring the same size everywhere instead of re-fitted per
    // surface.
    property real screenWidth: 0
    property real screenHeight: 0
    // Master switch. Named for the effect rather than reusing Item.enabled,
    // which would silently gate input on the host's children.
    property bool glowEnabled: true
    // Ring size at the seed, in screen pixels.
    property real minDiameter: 12

    // The shared clock, read straight through. 1 is the settled end state, so a
    // host costs nothing while the pulse is idle.
    readonly property real progress: pulse ? Number(pulse.progress) : 1
    readonly property bool playing: pulse ? pulse.active === true : false
    // One shared clock means a pulse triggered anywhere would replay here, so
    // the screen tag is what keeps a volume step on one monitor from re-ringing
    // a card on another.
    readonly property bool answersPulse: !pulse || pulse.matchesScreen(screenName)

    // This item's own place on its output, in screen coordinates, supplied by
    // the host rather than mapped here.
    //
    // Two reasons, both learned the hard way. `mapToGlobal` is per-window, so a
    // layer-shell surface anchored to one side of the screen reports its own
    // window-local zero as if it were the screen edge. And a freshly created
    // child's first `mapToGlobal` is read before the scene has adopted its
    // anchor-derived position, so it answers with a stale point — for a
    // notification delegate that put the ring a screen's width off the card.
    // The host knows its own placement deterministically, so it states it.
    property real hostScreenX: 0
    property real hostScreenY: 0
    // Radius that clears the display from the ring's origin, and the radius it
    // travels to: the ring is off-screen exactly as the clock runs out.
    readonly property real cover: Glow.coverRadius(originOnScreenX(), originOnScreenY(),
                                                   screenWidth, screenHeight)
    readonly property real travelRadius: Glow.travelRadius(cover, Glow.MAX_RING_STROKE)
    // The ring's radius right now. Read by hosts for diagnostics: whether a
    // surface is lit at all is a question about this number against the
    // surface's own size, not about the clock.
    readonly property real radius: glowRing.width / 2
    // The same origin the bar sees, expressed in this surface's coordinates.
    readonly property real originX: originOnScreenX() - hostScreenX
    readonly property real originY: originOnScreenY() - hostScreenY

    // The origin is read live, not latched to a token. Triggers that arrive
    // during a sweep are coalesced rather than restarted, so a surface that
    // appears mid-sweep — a card sliding in while the ring is already
    // travelling — reveals the ring where it actually is instead of missing
    // the event. Reading the point twice keeps the two call sites honest.
    function originOnScreenX() {
        return pulse ? Number(pulse.originScreenX) : 0
    }

    function originOnScreenY() {
        return pulse ? Number(pulse.originScreenY) : 0
    }

    clip: true
    visible: glowEnabled && !MotionTokens.reducedMotion && playing && answersPulse

    // Outermost glow, furthest behind the edge. Every layer is a ring: a filled
    // disc would outgrow the host and sit there as a flat tint until the sweep
    // ended, which reads as the surface staying lit and then blinking off.
    Rectangle {
        id: glowHalo

        width: Glow.haloDiameter(root.progress, root.travelRadius, root.minDiameter)
        height: width
        x: root.originX - width / 2
        y: root.originY - height / 2
        radius: width / 2
        color: "transparent"
        border.width: Glow.haloWidth(glowRing.border.width)
        border.color: LazerTheme.shade(LazerTheme.glowPulseRing, Glow.HALO_OPACITY)
    }

    // Wider soft band right behind the edge. Declared before the ring so the
    // crisp edge paints on top of its own blur; it reads the ring's stroke,
    // hence the forward reference.
    Rectangle {
        id: glowTrail

        width: Glow.trailDiameter(root.progress, root.travelRadius, root.minDiameter)
        height: width
        x: root.originX - width / 2
        y: root.originY - height / 2
        radius: width / 2
        color: "transparent"
        border.width: Glow.trailWidth(glowRing.border.width, root.width, root.height)
        border.color: LazerTheme.shade(LazerTheme.glowPulseRing, Glow.TRAIL_OPACITY)
    }

    // Leading ring: the heavy, fully opaque edge that carries the motion. It
    // never dims — it is simply larger than the display for the tail of the
    // sweep, and the clip is what takes it off screen.
    Rectangle {
        id: glowRing

        width: Glow.ringDiameter(root.progress, root.travelRadius, root.minDiameter)
        height: width
        x: root.originX - width / 2
        y: root.originY - height / 2
        radius: width / 2
        color: "transparent"
        border.width: Glow.ringWidth(width)
        border.color: LazerTheme.glowPulseRing
        opacity: Glow.RING_OPACITY
    }

    // A mid-flight reduced-motion toggle must not strand a half-drawn ring.
    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion && root.pulse && root.pulse.progressAnimation)
                root.pulse.progressAnimation.stop()
        }
    }
}
