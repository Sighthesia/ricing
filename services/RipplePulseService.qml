pragma Singleton
import QtQuick

// The shell's one glow pulse.
//
// This is the pre-lazer `main`-branch ripple, brought back as a single shared
// ring rather than a full-screen overlay: a heavy leading edge with two soft
// bands bleeding off it, growing from a point on the screen and leaving it.
//
// One clock, one origin, one ring. The origin is published in *screen*
// coordinates and the ring is sized by its host against the *screen* extent,
// so every surface showing this pulse is showing the same ring at the same
// instant — the notification card reveals the slice of it that crosses the
// card, the bar the slice that crosses the bar. Nothing here knows what a
// surface is; that is what keeps the effect from splitting into a glow for
// notifications and a glow for the bar.
//
// The ring is never interrupted *by a repeat of itself*. A trigger that lands
// on the pulse already in flight — the same control being adjusted, one
// discrete step after the next — is the same event, and folds into it so the
// ring keeps travelling instead of being chopped back to the seed on every
// step. Anything else is a different event and gets its own ring: a
// notification arriving a moment after a volume step is a new thing that
// happened, and folding it into the previous ring left the new card with no
// ring at all — the one-shot behaviour that made the pulse look like it could
// only ever fire once.
QtObject {
    id: root

    // How close two triggers have to be, in screen pixels, to count as the same
    // event repeating. Sized to a couple of icon widths: consecutive steps on one
    // control land within a pixel or two of each other, while two different
    // widgets are further apart than this.
    readonly property real continuationRadius: 24

    // Bumped on every trigger, for hosts that want an edge rather than a binding.
    property int token: 0
    // True while the pulse is in flight. Hosts show nothing when it is false.
    property bool active: false
    // 0 at the seed, 1 once the ring has left the display. The single clock.
    property real progress: 1
    // Where the ring starts, in screen coordinates on `pulseScreen`. Written on
    // every trigger, so a surface reading it live sees the latest event.
    property real originScreenX: 0
    property real originScreenY: 0
    // Screen the event belongs to, or "" for one every screen may answer.
    property string pulseScreen: ""
    // How many repeats have been folded into the pulse in flight, for
    // diagnostics. Reset whenever a new sweep actually starts.
    property int coalescedCount: 0
    // Sweep length in ms. shell.qml injects MotionTokens.glowSweep, which is
    // where the project's motion timings live; the literal is only a fallback
    // for harnesses that mount the service without the shell.
    property int duration: 900

    // Record the event. `screen` empty means every screen may answer; the
    // origin is a point in that screen's coordinates.
    function trigger(screen, originX, originY) {
        const tag = screen == null ? "" : String(screen)
        const x = Number(originX) || 0
        const y = Number(originY) || 0
        // Whether this is a repeat of the pulse in flight, judged against the
        // origin already running and before this one lands.
        //
        // Only a tagged trigger can repeat. A tag means one widget announcing
        // its own discrete step, where a following step from the same place is
        // the same event by definition. An untagged trigger is a notification:
        // an occurrence, every time. Two cards arriving at the same corner
        // within a second are two separate things that happened, and folding the
        // second into the first is precisely how a card ends up with no ring.
        const repeating = root.active
            && tag !== ""
            && tag === root.pulseScreen
            && Math.abs(x - root.originScreenX) <= root.continuationRadius
            && Math.abs(y - root.originScreenY) <= root.continuationRadius

        root.pulseScreen = tag
        root.originScreenX = x
        root.originScreenY = y
        ++root.token

        if (repeating) {
            ++root.coalescedCount
            return
        }
        root.coalescedCount = 0
        progressAnimation.stop()
        progress = 0
        active = true
        progressAnimation.start()
    }

    // True when a pulse published for `screen` should be played by that
    // screen's surfaces.
    function matchesScreen(screen) {
        return root.pulseScreen === "" || root.pulseScreen === String(screen == null ? "" : screen)
    }

    property NumberAnimation progressAnimation: NumberAnimation {
        id: progressAnimation

        target: root
        property: "progress"
        from: 0
        to: 1
        // Linear, deliberately not the OutCubic the old full-screen ripple
        // used. That easing is read as "the wave settles" when the ring is
        // enormous and diffuse; on a card or a 48px bar strip the ring is a
        // hard opaque edge, and an ease-out spends the last third of the sweep
        // creeping the last sliver of distance. The ring is the only thing
        // carrying this effect, so it crosses at a constant speed and leaves
        // exactly as the clock runs out.
        easing.type: Easing.Linear
        duration: root.duration
        onStopped: root.active = false
    }
}
