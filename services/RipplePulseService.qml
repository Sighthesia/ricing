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
// Repeats fire too. Folding a repeat into the ring already in flight was the
// only way to keep a dragged slider from stuttering while there was a single
// clock, and it cost a whole sweep's worth of waiting: one control being adjusted
// could produce one ring and then nothing until that ring had left the screen.
// With several rings in flight there is nothing left to stutter — a second ring
// cannot reset the first — so every event gets its own and the cap below is what
// bounds a burst.
QtObject {
    id: root

    // How many rings may be in flight at once, and the oldest is retired past it.
    //
    // Generous on purpose now that emission is continuous. A ring lives for the
    // whole sweep, and the ring travels a screen's worth of radius in that time,
    // so a stream of events arriving every few tens of milliseconds lands rings
    // roughly a hundred pixels apart along the path. Capping at four would keep
    // only the newest of those and pile them up into a lit blob at the origin,
    // with an empty screen beyond it; the cap has to be deep enough for the train
    // to still be crossing when the next one starts. Ten covers about a second of
    // rapid steps, which is where the ring that started it is leaving anyway.
    readonly property int maxRings: 10

    // Bumped on every trigger, for hosts that want an edge rather than a binding.
    property int token: 0
    // How many times the clock has advanced. Diagnostics: the sweep is only as
    // smooth as the rate this is driven at, and a clock that falls behind the
    // display is indistinguishable from a dropped frame to the eye.
    property int clockTicks: 0
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
    // Sweep length in ms. shell.qml injects MotionTokens.glowSweep, which is
    // where the project's motion timings live; the literal is only a fallback
    // for harnesses that mount the service without the shell.
    property int duration: 900

    // Startup suppression. During startup staging the bar widgets go from their
    // defaults to the services' real values, and an initial status sync must not
    // add another screen-wide sweep on top of the wallpaper reveal and lock wave.
    // The gate only rejects new triggers; it never cancels rings already in flight.
    // The shell clears it after the deferred startup queue, so normal user input
    // remains live immediately afterwards.
    property bool startupMuted: false

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
    //
    // Every event starts a ring, including a repeat of one already in flight.
    // That is what makes the effect continuous: a slider being dragged, or a
    // burst of notifications, puts out one ring per event rather than one ring
    // per sweep, and none of them waits for the one before it.
    function trigger(screen, originX, originY) {
        // Suppression is checked before changing time, token, or the ring list.
        // A startup sync therefore cannot perturb an existing sweep or make a
        // later user event appear to be the second pulse.
        if (root.startupMuted)
            return
        const at = Date.now()
        root.now = at
        ++root.token

        const kept = root.pruneFinished(at)
        kept.push({ screen: screen == null ? "" : String(screen),
                    originX: Number(originX) || 0,
                    originY: Number(originY) || 0,
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
    //
    // 8ms, and the number matters. A ring's position is a function of wall-clock
    // time rather than of tick count, so this does not change how fast a ring
    // travels — it changes how often the display gets a fresh position for it.
    // At 16ms this clock measured 62Hz with a worst gap of 25ms, against a
    // frame-synced reference running at 90Hz with a 14ms gap: a 25ms gap is
    // longer than a 60Hz frame period, so whole frames were rendered with no new
    // sample and the ring stood still for a frame and then jumped the next
    // frame's distance along. That reads as a low frame rate however correct the
    // geometry is.
    //
    // A sampling period shorter than the display's frame period closes that gap
    // by construction: any interval one frame long then contains at least one
    // tick, so every frame is drawn from a fresh position. 8ms covers displays
    // up to 125Hz, and the clock is idle otherwise — one property write per tick,
    // only while a sweep is actually running.
    property Timer pulseClock: Timer {
        interval: 8
        repeat: true
        onTriggered: {
            const at = Date.now()
            root.now = at
            ++root.clockTicks
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
