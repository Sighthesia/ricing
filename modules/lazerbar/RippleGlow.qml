import QtQuick
import "RippleGlowLogic.js" as Glow

// Show the shell's glow pulse, clipped to one host surface.
//
// The pulse is global: rings defined in screen coordinates, owned by
// RipplePulseService, one per event and several at once. This component does not
// re-fit any of them and does not keep a clock. It hands over the screen extent,
// projects each ring's origin from the screen into its own coordinates, and lets
// `clip` mask whatever part of each ring crosses it — so a card shows slices of
// exactly the rings the bar shows, at the same instants and at the same weight,
// instead of a second smaller version of the effect.
//
// Several properties the full-screen version got for free and this one earns:
//   * nothing fades — a ring holds full strength for its whole sweep and ends
//     because the light has left the display, not because it stopped shining;
//   * nothing lingers — every layer is a ring hugging the leading edge, so no
//     layer can cover a surface and sit on it as a flat tint;
//   * nothing interrupts — a ring already travelling is left alone, so events
//     arriving in quick succession cross the screen together instead of one
//     cutting off the last.
Item {
    id: root

    // The shared pulse. Injected rather than imported so this component stays
    // loadable — and testable — without Quickshell; production passes
    // RipplePulseService.
    property var pulse: null
    // This surface's output. A ring tagged for another screen is not ours to
    // answer; an untagged one is every screen's to answer.
    property string screenName: ""
    // The output the rings are defined against. Both hosts know it, and it is
    // what makes a ring the same size everywhere instead of re-fitted per
    // surface.
    property real screenWidth: 0
    property real screenHeight: 0
    // Master switch. Named for the effect rather than reusing Item.enabled,
    // which would silently gate input on the host's children.
    property bool glowEnabled: true
    // Ring size at the seed, in screen pixels.
    property real minDiameter: 12

    // This item's own place on its output, in screen coordinates, supplied by
    // the host rather than mapped here.
    //
    // Two reasons, both learned the hard way. `mapToGlobal` is per-window, so a
    // layer-shell surface anchored to one side of the screen reports its own
    // window-local zero as if it were the screen edge. And a freshly created
    // child's first `mapToGlobal` is read before the scene has adopted its
    // anchor-derived position, so it answers with a stale point — for a
    // notification delegate that put the ring a screen's width off the card. The
    // host knows its own placement deterministically, so it states it.
    property real hostScreenX: 0
    property real hostScreenY: 0

    // The shared clock's state, read straight through. Idle costs nothing.
    readonly property bool playing: pulse ? pulse.active === true : false

    // The rings this surface is answering: those tagged for its screen, plus the
    // untagged ones every screen answers.
    //
    // Read from the service each time rather than latched to a token, so a
    // surface that appears mid-sweep — a card sliding in while a ring is already
    // travelling — reveals the rings already crossing it instead of missing the
    // event, and a surface that has just been tagged out stops immediately.
    function answerableRings() {
        if (!pulse)
            return []
        const out = []
        for (let i = 0; i < pulse.rings.length; ++i) {
            if (pulse.matchesRing(pulse.rings[i], screenName))
                out.push(pulse.rings[i])
        }
        return out
    }

    readonly property var rings: answerableRings()

    // True when at least one ring is this surface's to play. With one clock and
    // one origin this was a screen-tag test; with several rings it is whether
    // any of them is ours.
    readonly property bool answersPulse: rings.length > 0

    // The newest ring this surface is answering, and its projected origin, size
    // and progress. Diagnostics, and the subject of tests: the layers themselves
    // are built per ring from `rings`.
    readonly property var newestRing: rings.length ? rings[rings.length - 1] : null
    readonly property real cover: newestRing ? coverRadiusFor(newestRing) : 0
    readonly property real travelRadius: newestRing ? travelRadiusFor(newestRing) : 0
    readonly property real originX: newestRing ? newestRing.originX - root.hostScreenX : 0
    readonly property real originY: newestRing ? newestRing.originY - root.hostScreenY : 0
    readonly property real progress: newestRing && pulse ? pulse.progressOf(newestRing) : 1
    // The newest ring's current radius, for hosts' diagnostics: whether a
    // surface is lit at all is a question about this number against the
    // surface's own size, not about the clock.
    readonly property real radius: newestRing
        ? Glow.ringDiameter(progress, travelRadius, minDiameter) / 2 : 0

    // How many sets of layers are actually instantiated. The model can hold a
    // ring the renderer has not built yet, and a ring that is never drawn is
    // exactly the failure this shape of component can hide, so it is counted
    // rather than inferred from the model.
    property int drawnRings: 0

    // Radius that clears the display from a ring's origin, and the radius it
    // travels to: the ring is off-screen exactly as its own sweep runs out.
    function coverRadiusFor(ring) {
        return Glow.coverRadius(ring.originX, ring.originY, screenWidth, screenHeight)
    }

    function travelRadiusFor(ring) {
        return Glow.travelRadius(coverRadiusFor(ring), Glow.MAX_RING_STROKE)
    }

    clip: true
    visible: glowEnabled && !MotionTokens.reducedMotion && playing && answersPulse

    // One set of layers per ring. Every layer is a ring: a filled disc would
    // outgrow the host and sit there as a flat tint until the sweep ended, which
    // reads as the surface staying lit and then blinking off.
    Repeater {
        model: root.rings

        delegate: Item {
            id: ringRoot

            required property var modelData

            Component.onCompleted: root.drawnRings += 1
            Component.onDestruction: root.drawnRings -= 1
            // Read live rather than latched to a token, so a ring already in
            // flight is drawn where it has actually got to.
            readonly property real ringProgress: root.pulse
                ? root.pulse.progressOf(ringRoot.modelData) : 1
            // The origin projected from screen coordinates into this surface's
            // own, which is what `clip` then masks.
            readonly property real originX: ringRoot.modelData.originX - root.hostScreenX
            readonly property real originY: ringRoot.modelData.originY - root.hostScreenY
            readonly property real travelRadius: root.travelRadiusFor(ringRoot.modelData)

            // Outermost glow, furthest behind the edge.
            Rectangle {
                id: glowHalo

                width: Glow.haloDiameter(ringRoot.ringProgress, ringRoot.travelRadius, root.minDiameter)
                height: width
                x: ringRoot.originX - width / 2
                y: ringRoot.originY - height / 2
                radius: width / 2
                color: "transparent"
                border.width: Glow.haloWidth(glowRing.border.width)
                border.color: LazerTheme.shade(LazerTheme.glowPulseRing, Glow.HALO_OPACITY)
            }

            // Wider soft band right behind the edge. Declared before the ring so
            // the crisp edge paints on top of its own blur; it reads the ring's
            // stroke, hence the forward reference.
            Rectangle {
                id: glowTrail

                width: Glow.trailDiameter(ringRoot.ringProgress, ringRoot.travelRadius, root.minDiameter)
                height: width
                x: ringRoot.originX - width / 2
                y: ringRoot.originY - height / 2
                radius: width / 2
                color: "transparent"
                border.width: Glow.trailWidth(glowRing.border.width, root.width, root.height)
                border.color: LazerTheme.shade(LazerTheme.glowPulseRing, Glow.TRAIL_OPACITY)
            }

            // Leading ring: the heavy, fully opaque edge that carries the
            // motion. It never dims — it is simply larger than the display for
            // the tail of the sweep, and the clip is what takes it off screen.
            Rectangle {
                id: glowRing

                width: Glow.ringDiameter(ringRoot.ringProgress, ringRoot.travelRadius, root.minDiameter)
                height: width
                x: ringRoot.originX - width / 2
                y: ringRoot.originY - height / 2
                radius: width / 2
                color: "transparent"
                border.width: Glow.ringWidth(width)
                border.color: LazerTheme.glowPulseRing
                opacity: Glow.RING_OPACITY
            }
        }
    }

    // A mid-flight reduced-motion toggle must not strand half-drawn rings.
    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion && root.pulse && root.pulse.clear)
                root.pulse.clear()
        }
    }
}