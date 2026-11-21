import QtQuick
import "../lazerbar"

// Render a mirrored low-opacity spectrum that can sit behind bar widgets.
// Sharp rectangular bars (radius 0) follow the osu!lazer sharp language:
// large surfaces stay rectangular; only small control details use rounding.
// A beat wave — a rectangular highlight front sweeping from the left edge —
// brightens bars as it passes, driven by triggerWave() on each beat signal.
Item {
    id: root

    property var values: []
    // lazer accent (#765BFF) at 34% — caller may override for theming.
    property color barColor: Qt.rgba(0.462, 0.356, 1.0, 0.34)
    // Wavefront tint: transparent keeps the legacy alpha boost (dark glass);
    // an opaque color whitens the bars toward it as the front passes, so the
    // sweep brightens instead of saturating on light backgrounds.
    property color waveColor: "#00000000"
    // Scales the color mix toward waveColor (1.0 = full glow core); the
    // alpha lift stays untouched so bar presence never changes with it.
    property real waveStrength: 1.0
    // Sweep duration; callers derive it from the current BPM so a new wave
    // launches right as the previous one reaches the far edge.
    property int waveDuration: MotionTokens.beatWave
    // How far ahead of the front the brightness bump reaches.
    readonly property real waveWidth: Math.max(20, root.width * 0.16)
    // The light a bar throws while the beat front is on it: the accent's own hue,
    // pulled toward the surface the spectrum sits on, so it reads as that surface
    // brightening rather than as a band of its own.
    property color glowColor: LazerTheme.glowFor(LazerTheme.accentColor, root.glowSurface)
    // What the light lands on, so it reads as that surface brightening.
    property color glowSurface: "transparent"
    // How far the light reaches outside a bar, and the peak alpha it reaches.
    // Bars are thin and sit close together, so the reach has to stay smaller
    // than the gap between them or the whole spectrum lights up as a block.
    readonly property real glowSpread: 5
    readonly property real glowAlpha: LazerTheme.flashGlowEdge

    // Sweep-front position in root coordinates; parked far left when idle so
    // no bar ever sees a boost from it.
    property real waveX: -root.waveWidth * 4
    readonly property bool waveActive: waveSweep.running

    readonly property int valuesCount: (root.values && root.values.length !== undefined) ? root.values.length : 0
    readonly property int totalBars: root.valuesCount > 0 ? root.valuesCount * 2 : 0
    readonly property real slotWidth: root.totalBars > 0 ? root.width / root.totalBars : 0
    readonly property real floorInset: 3
    readonly property real usableHeight: Math.max(0, root.height - root.floorInset)

    // How far short of the next beat the front aims to finish. The sweep is
    // timed from a measured beat period, but the beat that ends it is an actual
    // detection with its own jitter, so a front timed to land exactly on it is
    // cut off about as often as it lands in time. Banking a few percent turns
    // "interrupted mid-flight" into "arrived just before".
    readonly property real waveAnticipation: 0.05

    // Kick off one left-to-right highlight sweep; safe to retrigger mid-sweep
    // (the front restarts from the left edge, matching the new beat).
    function triggerWave() {
        if (MotionTokens.reducedMotion || !root.visible || root.width <= 0)
            return
        // A front that is still travelling is not thrown away mid-flight: being
        // cut in half is exactly what reads as unnatural, and the beat that ends
        // this sweep is a detection while the period its duration came from is
        // an estimate that keeps moving, so a mismatch is normal rather than
        // exceptional. A beat that lands while the front is still short of
        // the edge is dropped; the front finishes, and the wave re-arms on the
        // next beat - at most one beat late, and never cut.
        // Near the edge it does restart, so a slightly overestimated period
        // cannot halve the wave's rate by dropping every other beat.
        const travel = root.width + root.waveWidth * 2
        const progress = travel > 0 ? (root.waveX + root.waveWidth) / travel : 1
        if (waveSweep.running && progress < 0.85)
            return
        // Sampled here, not bound: a running NumberAnimation keeps the duration
        // it started with, so a binding that re-evaluates mid-flight changes
        // nothing until the next sweep anyway - it only makes the number this
        // sweep is running on harder to read from the code.
        const base = root.waveDuration > 0 ? root.waveDuration : MotionTokens.beatWave
        const duration = Math.max(160, Math.round(base * (1 - root.waveAnticipation)))
        waveSweep.stop()
        waveSweep.duration = duration
        root.waveX = -root.waveWidth
        waveSweep.restart()
    }

    NumberAnimation {
        id: waveSweep

        target: root
        property: "waveX"
        from: -root.waveWidth
        to: root.width + root.waveWidth
        // Assigned per sweep by triggerWave(); this is only the fallback.
        duration: MotionTokens.beatWave
        easing.type: Easing.OutQuad
    }

    Repeater {
        model: root.totalBars

        Rectangle {
            id: waveRoot

            readonly property int mirroredIndex: index < root.valuesCount ? root.valuesCount - 1 - index : index - root.valuesCount
            readonly property real amplitude: (root.values && root.values[mirroredIndex] !== undefined) ? root.values[mirroredIndex] : 0
            readonly property real emphasis: {
                if (root.totalBars <= 1)
                    return 1
                var center = (root.totalBars - 1) / 2
                var distance = Math.abs(index - center) / Math.max(1, center)
                return 0.8 + ((1 - distance) * 0.45)
            }
            // Gaussian brightness bump while the beat front passes this bar.
            readonly property real waveBoost: {
                if (!root.waveActive)
                    return 0
                var barCenter = x + width / 2
                var offset = (barCenter - root.waveX) / (root.waveWidth * 0.5)
                return Math.exp(-offset * offset)
            }

            width: Math.max(1, root.slotWidth * 0.42)
            height: root.usableHeight * amplitude
            radius: 0
            x: index * root.slotWidth + ((root.slotWidth - width) / 2)
            y: root.height - height - root.floorInset
            // Transparent waveColor preserves the legacy alpha-only boost;
            // otherwise the front mixes the bar toward waveColor (brighten).
            color: {
                var boost = Math.max(0, Math.min(1, waveBoost * root.waveStrength))
                if (root.waveColor.a <= 0 || boost <= 0)
                    return Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b,
                        Math.min(1, root.barColor.a * emphasis + waveBoost * 0.85))
                return Qt.rgba(root.barColor.r + (root.waveColor.r - root.barColor.r) * boost,
                    root.barColor.g + (root.waveColor.g - root.barColor.g) * boost,
                    root.barColor.b + (root.waveColor.b - root.barColor.b) * boost,
                    Math.min(1, root.barColor.a * emphasis + waveBoost * 0.85))
            }
            visible: height > 0.5 && root.visible

            // The beat front's light, thrown by the bar it has actually reached:
            // a halo hugging that bar, not a wash across the spectrum. Only the
            // few bars under the front carry one, so the spectrum reads as a
            // wave of light moving through it.
            GlowBleed {
                anchors.fill: parent
                visible: waveRoot.visible && root.waveActive && waveRoot.waveBoost > 0.02
                glowColor: root.glowColor
                spread: root.glowSpread
                // Scheme correction on the layer, never on the edge alpha: a
                // value above 1 there would clip the ramp flat at its inner end.
                edgeAlpha: root.glowAlpha
                opacity: waveRoot.waveBoost * LazerTheme.glowPeakSweep
            }
        }
    }
}
