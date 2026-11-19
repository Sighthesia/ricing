import QtQuick
import "../lazerbar"

// Render a mirrored low-opacity spectrum that can sit behind bar widgets.
// Sharp rectangular bars (radius 0) follow the osu!lazer sharp language:
// large surfaces stay rectangular; only small control details use rounding.
// A beat wave — a rectangular highlight front sweeping from the left edge —
// brightens bars as it passes, driven by triggerWave() on each detected beat.
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
    // The light the front throws. Same scheme correction as the click flashes
    // (LazerTheme states it once), because a light surface can only be darkened:
    // a white band there would be worth nothing.
    property color glowColor: LazerTheme.flashGlow
    // Thin on purpose: this is light behind the bars, not a second wash over
    // them - the bars already brighten under the front.
    readonly property real glowAlpha: LazerTheme.spectrumGlowAlpha
    // How wide the light spreads either side of the front, as a fraction of the
    // boost window, so the two read as one event.
    readonly property real glowReach: root.waveWidth * 1.2

    // Sweep-front position in root coordinates; parked far left when idle so
    // no bar ever sees a boost from it.
    property real waveX: -root.waveWidth * 4
    readonly property bool waveActive: waveSweep.running

    readonly property int valuesCount: (root.values && root.values.length !== undefined) ? root.values.length : 0
    readonly property int totalBars: root.valuesCount > 0 ? root.valuesCount * 2 : 0
    readonly property real slotWidth: root.totalBars > 0 ? root.width / root.totalBars : 0
    readonly property real floorInset: 3
    readonly property real usableHeight: Math.max(0, root.height - root.floorInset)

    // Kick off one left-to-right highlight sweep; safe to retrigger mid-sweep
    // (the front restarts from the left edge, matching the new beat).
    function triggerWave() {
        if (MotionTokens.reducedMotion || !root.visible || root.width <= 0)
            return
        waveSweep.stop()
        root.waveX = -root.waveWidth
        waveSweep.restart()
    }

    NumberAnimation {
        id: waveSweep

        target: root
        property: "waveX"
        from: -root.waveWidth
        to: root.width + root.waveWidth
        duration: root.waveDuration > 0 ? root.waveDuration : MotionTokens.beatWave
        easing.type: Easing.OutQuad
    }

    // The beat's own light, painted behind the bars: a soft band travelling with
    // the front, so the flash reads as light crossing the spectrum rather than
    // only as bars brightening. Five stops instead of a triangle, whose centre
    // would show as a crease.
    Rectangle {
        id: waveGlow

        visible: root.waveActive && root.glowAlpha > 0.01
        x: root.waveX - width / 2
        y: 0
        width: Math.max(1, 2 * root.glowReach)
        height: root.height

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: LazerTheme.shade(root.glowColor, 0) }
            GradientStop { position: 0.25; color: LazerTheme.shade(root.glowColor, root.glowAlpha * 0.35) }
            GradientStop { position: 0.5; color: LazerTheme.shade(root.glowColor, root.glowAlpha) }
            GradientStop { position: 0.75; color: LazerTheme.shade(root.glowColor, root.glowAlpha * 0.35) }
            GradientStop { position: 1; color: LazerTheme.shade(root.glowColor, 0) }
        }
    }

    Repeater {
        model: root.totalBars

        Rectangle {
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
        }
    }
}
