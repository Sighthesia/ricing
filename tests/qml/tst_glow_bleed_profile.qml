import QtQuick
import QtTest
import "../../modules/lazerbar/RippleGlowLogic.js" as Glow

// The glow must be a falloff, not a set of bands.
//
// Banding is a discrete jump in the brightness ramp across the falloff, so it can
// be measured rather than argued about: draw the bleed with the stops the
// renderer uses, read the pixels back, and look at the largest step between
// neighbouring ones.
//
// This is here because nothing else caught it. The bleed used to be two wide
// rounded-rectangle borders at half and quarter strength, whose crisp edges read
// as a bright edge with two bands behind it — and with several rings in flight
// the bands multiplied into stripes. No assertion caught that, because every
// assertion was about geometry and the geometry was correct; only the rendered
// pixels were wrong.
Item {
    id: root
    width: 320
    height: 96

    // 10% of peak. The old two-band bleed stepped by 50% and 25%, so this still
    // excludes it by 5x while leaving a smooth gradient — whose per-pixel step is
    // just its rise over its own width — comfortably inside it.
    readonly property real maxStep: 0.10

    Canvas {
        id: strip
        width: 256
        height: 64
        visible: false

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = "#000000"
            ctx.fillRect(0, 0, width, height)
            const mid = height / 2
            const ramp = ctx.createRadialGradient(width / 2, mid, 0, width / 2, mid, width / 2)
            ramp.addColorStop(Math.max(0, Glow.bleedInner()), "rgba(255,255,255,0)")
            ramp.addColorStop(Glow.bleedPeak(),
                              "rgba(255,255,255," + Glow.BLEED_ALPHA + ")")
            ramp.addColorStop(1.0, "rgba(255,255,255,0)")
            ctx.fillStyle = ramp
            ctx.fillRect(0, 0, width, height)
        }
    }

    TestCase {
        id: tc
        name: "GlowBleedProfile"
        when: windowShown

        function test_theBleedIsAFalloffAndNotABand() {
            strip.requestPaint()
            // The canvas paints on the render thread's next pass.
            wait(150)
            const ctx = strip.getContext("2d")
            const data = ctx.getImageData(0, Math.floor(strip.height / 2),
                                          strip.width, 1).data
            compare(data.length, strip.width * 4)

            let peak = 0
            let step = 0
            let previous = -1
            for (let x = 0; x < strip.width; ++x) {
                const value = data[x * 4 + 1]
                peak = Math.max(peak, value)
                if (previous >= 0)
                    step = Math.max(step, Math.abs(value - previous))
                previous = value
            }
            // The ramp has to actually be there, or "no step" means "no bleed".
            verify(peak > 8, "peak " + peak)
            verify(peak <= 255 * Glow.BLEED_ALPHA + 2,
                   "peak " + peak + " exceeds the configured alpha")

            const relative = step / peak
            verify(relative <= root.maxStep,
                   "largest step " + (relative * 100).toFixed(1)
                   + "% of peak, limit " + (root.maxStep * 100).toFixed(0) + "%")
        }
    }
}