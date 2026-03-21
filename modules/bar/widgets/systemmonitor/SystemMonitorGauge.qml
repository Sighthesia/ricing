import Quickshell
import Qt5Compat.GraphicalEffects
import QtQuick
import qs.config

Item {
    id: root

    required property var metric
    property bool interactive: false

    signal stepRequested(int direction)

    readonly property real normalizedProgress: root._clampProgress(root.metric ? root.metric.normalizedProgress : 0)
    readonly property color semanticColor: root._semanticColor()
    readonly property color iconColor: root.metric && root.metric.available === false ? Colors.textMuted : root.semanticColor
    readonly property color trackColor: Colors.border
    readonly property color surfaceColor: Colors.surface
    readonly property real gaugeSize: Theme.barWidget.pillHeight
    readonly property real ringThickness: Math.max(2, Math.round(Theme.barWidget.contentPaddingV * 0.75))
    readonly property real iconSize: Theme.barWidget.compactIconSize

    implicitWidth: root.gaugeSize
    implicitHeight: root.gaugeSize

    function _clampProgress(value) {
        const numericValue = Number(value)
        if (!Number.isFinite(numericValue))
            return 0

        return Math.max(0, Math.min(1, numericValue))
    }

    function _semanticColor() {
        if (!root.metric || root.metric.available === false)
            return Colors.textMuted

        if (root.metric.severity === "critical")
            return Colors.destructive

        if (root.metric.severity === "warning")
            return Colors.highlight

        return Colors.text
    }

    function _iconSource() {
        if (!root.metric || !root.metric.icon)
            return Quickshell.iconPath("application-x-executable", "application-x-executable")

        return Quickshell.iconPath(root.metric.icon, "application-x-executable")
    }

    function _wheelStep(horizontalDelta, verticalDelta) {
        if (!root.interactive)
            return 0

        const horizontal = Number(horizontalDelta) || 0
        const vertical = Number(verticalDelta) || 0
        const useHorizontal = Math.abs(horizontal) > Math.abs(vertical)
        const delta = useHorizontal ? horizontal : vertical

        if (delta === 0)
            return 0

        const direction = delta > 0 ? 1 : -1
        root.stepRequested(direction)
        return direction
    }

    function _pointerWithinGauge(pointerX, pointerY) {
        const x = Number(pointerX)
        const y = Number(pointerY)
        if (!Number.isFinite(x) || !Number.isFinite(y))
            return false

        return x >= 0 && y >= 0 && x <= width && y <= height
    }

    function _wheelStepAt(pointerX, pointerY, horizontalDelta, verticalDelta) {
        if (!root._pointerWithinGauge(pointerX, pointerY))
            return 0

        return root._wheelStep(horizontalDelta, verticalDelta)
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.surfaceColor
        border.color: Colors.border
        border.width: 1
    }

    Canvas {
        id: ringCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            const cx = width / 2
            const cy = height / 2
            const radius = Math.max(0, Math.min(width, height) / 2 - root.ringThickness)
            const arcStart = Math.PI * 0.75
            const arcSpan = Math.PI * 1.5
            const progress = root.normalizedProgress

            ctx.clearRect(0, 0, width, height)
            ctx.lineCap = "round"
            ctx.lineWidth = root.ringThickness

            ctx.beginPath()
            ctx.strokeStyle = root.trackColor
            // FIXME: keep the arc span literal here until a shared gauge-arc token exists.
            ctx.arc(cx, cy, radius, arcStart, arcStart + arcSpan, false)
            ctx.stroke()

            ctx.beginPath()
            ctx.strokeStyle = root.semanticColor
            // FIXME: keep the same three-quarter ring span aligned with the track path above.
            ctx.arc(cx, cy, radius, arcStart, arcStart + arcSpan * progress, false)
            ctx.stroke()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Image {
        id: iconSource
        anchors.centerIn: parent
        source: root._iconSource()
        width: root.iconSize
        height: root.iconSize
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    ColorOverlay {
        objectName: "systemMonitorGaugeIconOverlay"
        anchors.fill: iconSource
        source: iconSource
        color: root.iconColor
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            root._wheelStepAt(wheel.x, wheel.y, wheel.angleDelta.x, wheel.angleDelta.y)
        }
    }

    onMetricChanged: ringCanvas.requestPaint()
    onNormalizedProgressChanged: ringCanvas.requestPaint()
    onSemanticColorChanged: ringCanvas.requestPaint()
}
