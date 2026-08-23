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
    // How far ahead of the front the brightness bump reaches.
    readonly property real waveWidth: Math.max(20, root.width * 0.16)

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
        duration: MotionTokens.beatWave
        easing.type: Easing.OutQuad
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
            color: Qt.rgba(
                root.barColor.r,
                root.barColor.g,
                root.barColor.b,
                Math.min(1, root.barColor.a * emphasis + waveBoost * 0.55))
            visible: height > 0.5 && root.visible
        }
    }
}
