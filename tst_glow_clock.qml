import QtQuick
import Quickshell
import "./services" as Services

// How smoothly does the sweep actually move?
//
// The ring's motion is produced entirely by the pulse clock: every ring's
// geometry is a binding on `progressOf(ring)`, read against `now`, and `now` only
// advances when the clock does. The sweep cannot be smoother than the rate that
// clock runs at. Its position is a function of wall-clock time rather than of
// tick count, so a clock running slower than the display does not make the ring
// move slowly — it makes the ring stand still for a frame and then jump two
// frames' worth, which is what judder looks like.
//
// So this measures the glow's clock against a frame-synced reference over the
// same window: the rate of each, and the worst gap each one leaves. A clock that
// averages the right rate but drifts against the display still judders, and only
// the gaps show that.
Item {
    id: root

    property int failures: 0
    property int phase: 0

    // Frame-synced reference: Qt's animation driver is what drives every
    // vsync-locked animation in the shell, so its step rate is the closest thing
    // to the display's that can be counted without a window.
    property double reference: 0
    property int referenceTicks: 0
    property double referenceGap: 0
    property double referenceLastAt: 0

    // The glow's own clock, same measurements.
    property int glowTicksAtStart: 0
    property int referenceTicksAtStart: 0
    property double glowGap: 0
    property double glowLastAt: 0
    property double windowStart: 0
    readonly property int sweepMs: 2400

    function check(label, cond, detail) {
        const text = detail === undefined ? label : label + " [" + detail + "]"
        if (cond) {
            console.log("PASS:", text)
            return true
        }
        root.failures++
        console.log("FAIL:", text)
        return false
    }

    // One tick of the glow's clock: how long the ring stood still for.
    Connections {
        target: Services.RipplePulseService
        function onNowChanged() {
            if (root.phase !== 1)
                return
            const at = Date.now()
            if (root.glowLastAt > 0) {
                const gap = at - root.glowLastAt
                if (gap > root.glowGap)
                    root.glowGap = gap
            }
            root.glowLastAt = at
        }
    }

    // The same for the reference clock.
    onReferenceChanged: {
        if (root.phase !== 1)
            return
        const at = Date.now()
        ++root.referenceTicks
        if (root.referenceLastAt > 0) {
            const gap = at - root.referenceLastAt
            if (gap > root.referenceGap)
                root.referenceGap = gap
        }
        root.referenceLastAt = at
    }

    // Runs for as long as it is left running, so its steps are the driver's. Started
    // explicitly: a NumberAnimation declared on its own does not start, only a
    // Behavior applies itself.
    NumberAnimation {
        id: referenceAnim
        target: root
        property: "reference"
        from: 0
        to: 1e9
        duration: 1e9
    }

    Component.onCompleted: referenceAnim.start()

    function report() {
        const elapsed = Date.now() - root.windowStart
        const glowTicks = Services.RipplePulseService.clockTicks - root.glowTicksAtStart
        const refTicks = root.referenceTicks - root.referenceTicksAtStart
        const glowHz = glowTicks * 1000 / elapsed
        const refHz = refTicks * 1000 / elapsed
        console.log("frame-synced " + refHz.toFixed(1) + " Hz (worst gap "
                    + root.referenceGap.toFixed(0) + " ms), glow clock "
                    + glowHz.toFixed(1) + " Hz (worst gap " + root.glowGap.toFixed(0)
                    + " ms), over " + elapsed.toFixed(0) + " ms")

        // A degenerate window would make every comparison below pass on zeroes.
        root.check("the measurement window is sane",
                   elapsed > 500 && elapsed < root.sweepMs * 4,
                   "elapsed " + elapsed.toFixed(0) + " ms")
        root.check("the reference clock actually ticked",
                   refHz > 5, "reference " + refHz.toFixed(1) + " Hz")
        // The sweep's samples must land at least once per displayed frame, or the
        // ring stands still for a frame and jumps the next one.
        root.check("the glow clock samples at least once per frame",
                   glowHz >= refHz * 0.95,
                   "glow " + glowHz.toFixed(1) + " Hz vs frame-synced "
                   + refHz.toFixed(1) + " Hz")
        root.check("the glow clock leaves no frame unsampled",
                   root.glowGap <= root.referenceGap + 8,
                   "glow gap " + root.glowGap.toFixed(0) + " ms vs reference "
                   + root.referenceGap.toFixed(0) + " ms")
    }

    Timer {
        interval: 40
        running: true
        repeat: true
        onTriggered: {
            if (root.phase === 0) {
                // A sweep long enough to still be running at the end of the
                // window, so the clock is measured rather than its teardown.
                Services.RipplePulseService.duration = root.sweepMs
                Services.RipplePulseService.trigger("eDP-1", 960, 24)
                Services.RipplePulseService.trigger("eDP-1", 700, 24)
                Services.RipplePulseService.trigger("eDP-1", 440, 24)
                root.phase = 1
                root.windowStart = Date.now()
                root.glowLastAt = 0
                root.referenceLastAt = 0
                root.glowGap = 0
                root.referenceGap = 0
                root.glowTicksAtStart = Services.RipplePulseService.clockTicks
                root.referenceTicksAtStart = root.referenceTicks
                return
            }
            if (root.phase !== 1)
                return
            if (Date.now() - root.windowStart < root.sweepMs)
                return
            root.phase = 2
            root.report()
            console.log("Totals: " + (root.failures === 0 ? "all passed" : root.failures + " failed"))
            Qt.quit()
        }
    }
}