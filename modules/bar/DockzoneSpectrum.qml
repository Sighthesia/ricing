import QtQuick
import "../../services" as Services

// Render a configurable audio spectrum behind dockzone widgets.
// Supports bars, wave, and dots styles with mirror, color, and opacity control.
Item {
    id: root

    property var values: []
    property string style: "bars"
    property bool mirror: true
    property real heightScale: Services.SpectrumService.dockzoneHeightScale
    property real maxHeightRatio: Services.SpectrumService.dockzoneMaxHeightRatio
    property real gain: Services.SpectrumService.dockzoneGain
    property real barWidthRatio: Services.SpectrumService.dockzoneBarWidthRatio
    property real barSpacing: Services.SpectrumService.dockzoneSpacing
    property color barColor: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.55)
    // When > 0, overrides the reference height for maxHeightRatio clamping.
    // Typically set to the status bar height so maxHeightRatio caps against the full bar.
    property real barHeightAnchor: 0

    readonly property int valuesCount: (root.values && root.values.length !== undefined) ? root.values.length : 0
    readonly property int mirroredCount: root.mirror ? root.valuesCount * 2 : root.valuesCount
    readonly property int totalElements: mirroredCount
    readonly property real totalSpacing: Math.max(0, root.totalElements - 1) * Math.max(0, root.barSpacing)
    readonly property real slotWidth: root.totalElements > 0 ? Math.max(0, (root.width - root.totalSpacing) / root.totalElements) : 0
    readonly property real floorInset: 4
    readonly property real usableHeight: Math.max(0, root.height - root.floorInset)
    // Anchor-based cap so maxHeightRatio is meaningful even when the container is small.
    readonly property real maxBarHeight: (root.barHeightAnchor > 0 ? root.barHeightAnchor : root.height) * root.maxHeightRatio

    // Map from flat index to value index considering mirror mode.
    function valueIndex(i) {
        if (root.mirror)
            return i < root.valuesCount ? root.valuesCount - 1 - i : i - root.valuesCount
        return i
    }

    // Paint mirrored bars so the spectrum stays centered inside the dockzone body.
    Repeater {
        model: root.style !== "wave" ? root.totalElements : 0

        delegate: Rectangle {
            readonly property int vi: root.valueIndex(index)
            readonly property real amplitude: (root.values && root.values[vi] !== undefined) ? root.values[vi] : 0
            readonly property real scaledAmplitude: Math.max(0, amplitude * root.gain * Math.max(0.1, root.heightScale))
            readonly property real emphasis: {
                if (root.totalElements <= 1)
                    return 1

                var center = (root.totalElements - 1) / 2
                var distance = Math.abs(index - center) / Math.max(1, center)
                return 0.8 + ((1 - distance) * 0.45)
            }

            width: root.style === "dots"
                ? Math.max(2, root.slotWidth * Math.max(0.05, Math.min(1, root.barWidthRatio)))
                : Math.max(1, root.slotWidth * Math.max(0.05, Math.min(1, root.barWidthRatio)))
            height: root.style === "dots"
                ? width
                : Math.min(root.maxBarHeight, root.usableHeight * scaledAmplitude)
            radius: root.style === "dots" ? width / 2 : width / 2
            x: index * (root.slotWidth + Math.max(0, root.barSpacing)) + ((root.slotWidth - width) / 2)
            y: root.style === "dots"
                ? root.height - (root.usableHeight * scaledAmplitude) - height - root.floorInset / 2
                : root.height - height - root.floorInset
            color: Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, root.barColor.a * emphasis)
            visible: height > 0.5 && root.visible
        }
    }

    // Render a smooth filled wave for the "wave" style.
    Canvas {
        id: waveCanvas

        visible: root.style === "wave" && root.visible
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            const w = width
            const h = height
            ctx.clearRect(0, 0, w, h)

            const n = root.valuesCount
            if (n === 0) return

            const mirror = root.mirror
            const total = mirror ? n * 2 : n
            const spacing = Math.max(0, root.barSpacing)
            const totalSpacing = Math.max(0, total - 1) * spacing
            const slotW = Math.max(0, (w - totalSpacing) / total)
            const usable = root.usableHeight

            ctx.beginPath()
            ctx.moveTo(0, h)

            for (let i = 0; i <= total; i++) {
                let vi
                if (i === 0) {
                    vi = mirror ? n - 1 : 0
                } else if (i === total) {
                    vi = mirror ? 0 : n - 1
                } else {
                    vi = root.valueIndex(i)
                }

                const amp = (root.values && root.values[vi] !== undefined) ? root.values[vi] : 0
                const scaledAmp = Math.max(0, amp * root.gain * Math.max(0.1, root.heightScale))
                const cx = i === 0 ? 0 : (i === total ? w : i * (slotW + spacing) + slotW / 2)
                const cy = h - root.floorInset - Math.min(root.maxBarHeight, usable * scaledAmp)
                ctx.lineTo(cx, cy)
            }

            ctx.lineTo(w, h)
            ctx.closePath()

            ctx.fillStyle = root.barColor
            ctx.fill()
        }

        Connections {
            target: root
            function onValuesChanged() { waveCanvas.requestPaint() }
            function onBarColorChanged() { waveCanvas.requestPaint() }
            function onMirrorChanged() { waveCanvas.requestPaint() }
            function onStyleChanged() { waveCanvas.requestPaint() }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
}
