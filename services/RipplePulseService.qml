pragma Singleton
import QtQuick

// The shell's glow pulse.
//
// This is the pre-lazer `main`-branch ripple, brought back as a single shared
// ring rather than a full-screen overlay: a heavy leading edge with two soft
// bands bleeding off it, growing from a point on the screen and leaving it.
//
// One shape, many rings at once. Every event on the shell starts a ring, and a
// ring is never cut short by the next one: two notifications in a row are two
// rings crossing the screen together, and a notification arriving while a volume
// ring is still travelling adds to it rather than replacing it. A single clock
// with a single origin could only ever show one of them, which is what made the
// effect look like it interrupted itself — and what left a second notification
// with no ring at all, because the ring that was already out there had moved on
// before the card existed.
//
// A ring is defined in *screen* coordinates and sized by its host against the
// *screen* extent, so every surface answering an event is showing that same ring
// at the same instant — a notification card reveals the slice crossing the card,
// the bar the slice crossing the bar. Nothing here knows what a surface is; that
// is what keeps the effect from splitting into a glow for notifications and a
// glow for the bar.
//
// Repeats of one event do not stack. A trigger that lands on a ring already in
// flight — the same control being adjusted, one discrete step after the next — is
// the same event, and folds into that ring so a dragged slider produces one sweep
// instead of a stutter. Only a tagged trigger can repeat: a tag means one widget
// announcing its own step, where the next step is the same event by definition.
// An untagged trigger is a notification, an occurrence every time.
QtObject {
    id: root

    // How many rings may be in flight at once. A burst of notifications should
    // read as several rings crossing, not as a strobe; past a handful the later
    // ones are too faint to separate anyway, so the oldest is retired.
    readonly property int maxRings: 4

    // How close two triggers have to be, in screen pixels, to count as the same
    // event repeating. Sized to a couple of icon widths: consecutive steps on one
    // control land within a pixel or two of each other, while two different
    // widgets are further apart than this.
    readonly property real continuationRadius: 24

    // Bumped on every trigger, for hosts that want an edge rather than a binding.
    property int token: 0
    // Wall-clock milliseconds, advanced once a frame while any ring lives. The
    // rings themselves carry their own start time, so a second ring added mid
    // sweep gets its own full length instead of inheriting the first one's
    // remaining time.
    property real now: 0
    // The rings in flight, oldest first. Replaced only when one is added or
    // retired — never per frame, because a host draws one set of layers per ring
    // and rebuilding that model every frame would thrash them.
    property var rings: []
    readonly property bool active: rings.length > 0
    // How many repeats have been folded into a ring already in flight, for
    // diagnostics. Reset when a new ring actually starts.
    property int coalescedCount: 0
    // Sweep length in ms. shell.qml injects MotionTokens.glowSweep, which is
    // where the project's motion timings live; the literal is only a fallback
    // for harnesses that mount the service without the shell.
    property int duration: 900

    // The ring that started most recently, and its state. Diagnostics and the
    // subject of tests: hosts read `rings` and draw all of them.
    readonly property var newestRing: rings.length ? rings[rings.length - 1] : null
    readonly property real progress: newestRing ? progressOf(newestRing) : 1
    readonly property string pulseScreen: newestRing ? newestRing.screen : ""
    readonly property real originScreenX: newestRing ? newestRing.originX : 0
    readonly property real originScreenY: newestRing ? newestRing.originY : 0

    // Where one ring is in its own sweep: 0 at the seed, 1 once it has left the
    // display. Read against `now`, so it advances once a frame and each ring
    // keeps its own start.
    function progressOf(ring) {
        if (!ring || !(ring.duration > 0))
            return 1
        const elapsed = (root.now - ring.startedAt) / ring.duration
        return elapsed < 0 ? 0 : (elapsed > 1 ? 1 : elapsed)
    }

    // A ring published for one screen is not another screen's to answer; an
    // untagged one — a notification — is every screen's to answer.
    function matchesRing(ring, screen) {
        return !ring || ring.screen === "" || ring.screen === String(screen == null ? "" : screen)
    }

    // True when a pulse published for `screen` should be played by that
    // screen's surfaces. About the newest ring; hosts ask per ring instead.
    function matchesScreen(screen) {
        return root.matchesRing(root.newestRing, screen)
    }

    // Drop the rings whose sweep is over, keeping the rest in order.
    function pruneFinished(at) {
        const kept = []
        for (let i = 0; i < root.rings.length; ++i) {
            if (at - root.rings[i].startedAt < root.rings[i].duration)
                kept.push(root.rings[i])
        }
        return kept
    }

    // Record an event: `screen` empty means every screen may answer, and the
    // origin is a point in that screen's coordinates.
    function trigger(screen, originX, originY) {
        const tag = screen == null ? "" : String(screen)
        const x = Number(originX) || 0
        const y = Number(originY) || 0
        const at = Date.now()
        root.now = at
        ++root.token

        // A repeat of a ring already in flight is the same event, and folds into
        // it: restarting the clock on every step snapped the ring back to the
        // seed, so a dragged slider never got anywhere.
        for (let i = root.rings.length - 1; i >= 0; --i) {
            const ring = root.rings[i]
            if (tag !== "" && ring.screen === tag
                    && Math.abs(x - ring.originX) <= root.continuationRadius
                    && Math.abs(y - ring.originY) <= root.continuationRadius) {
                ++root.coalescedCount
                return
            }
        }

        root.coalescedCount = 0
        const kept = root.pruneFinished(at)
        kept.push({ screen: tag, originX: x, originY: y,
                    startedAt: at, duration: root.duration })
        while (kept.length > root.maxRings)
            kept.shift()
        root.rings = kept
        if (!root.pulseClock.running)
            root.pulseClock.start()
    }

    // The clock is a heartbeat, not an animation: with several rings in
    // flight there is no single progress to drive, and each ring's own start
    // time already fixes its length. Held as a property rather than declared as a
    // child, because a QtObject has no default property to put one in.
    property Timer pulseClock: Timer {
        interval: 16
        repeat: true
        onTriggered: {
            const at = Date.now()
            root.now = at
            const kept = root.pruneFinished(at)
            if (kept.length !== root.rings.length) {
                root.rings = kept
                if (kept.length === 0)
                    root.pulseClock.stop()
            }
        }
    }

    // A mid-flight reduced-motion toggle must not strand half-drawn rings.
    function clear() {
        root.pulseClock.stop()
        root.rings = []
        root.now = Date.now()
    }
}