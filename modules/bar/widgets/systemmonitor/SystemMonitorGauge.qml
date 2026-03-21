import Quickshell
import Qt5Compat.GraphicalEffects
import QtQuick
import qs.config

// Compact circular gauge with optional inline hover details and wheel interaction.
Item {
    id: root

    required property var metric
    property bool interactive: false
    property bool detailPreview: false

    signal stepRequested(int direction)
    signal detailVisibilityChanged(bool visible, var detail)

    readonly property real normalizedProgress: root._clampProgress(root.metric ? root.metric.normalizedProgress : 0)
    readonly property color semanticColor: root._semanticColor()
    readonly property color iconColor: root.metric && root.metric.available === false ? Colors.textMuted : root.semanticColor
    readonly property color trackColor: Colors.border
    readonly property color surfaceColor: Colors.surface
    readonly property real gaugeSize: Theme.barWidget.pillHeight
    readonly property real ringThickness: Math.max(2, Math.round(Theme.barWidget.contentPaddingV * 0.75))
    readonly property real iconSize: Theme.barWidget.compactIconSize
    readonly property bool _showDetail: (_hoverArea.containsMouse || root.detailPreview) && !!root.metric
    readonly property string _iconGlyph: root._glyphForMetric()
    readonly property bool _useGlyphIcon: root._iconGlyph !== ""
    readonly property string detailLabelText: root._detailLabel()
    readonly property real expandedGaugeWidth: root.gaugeSize
    readonly property var flashDetailData: ({
        key: root.metric && root.metric.key ? root.metric.key : "",
        title: root.metric && root.metric.title ? root.metric.title : "",
        valueText: root._detailValueText(),
        labelText: root.detailLabelText,
        glyph: root._iconGlyph,
        iconName: root.metric && root.metric.icon ? root.metric.icon : "",
        iconColor: root.iconColor,
        available: !!(root.metric && root.metric.available)
    })
    readonly property int gaugeCursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

    implicitWidth: root.gaugeSize
    implicitHeight: root.gaugeSize
    width: implicitWidth

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

    function _glyphForMetric() {
        const entry = root.metric || {}
        const value = Number(entry.value) || 0

        switch (entry.key) {
        case "cpu":
            return ""
        case "memory":
            return ""
        case "temperature":
            return value >= 0.85 ? "" : (value >= 0.6 ? "" : "")
        case "volume":
            return value <= 0 ? "󰖁" : (value < 0.5 ? "" : "")
        case "brightness":
            return ""
        case "battery":
            if (value >= 0.9)
                return ""
            if (value >= 0.65)
                return ""
            if (value >= 0.4)
                return ""
            if (value >= 0.15)
                return ""
            return ""
        default:
            return ""
        }
    }

    function _detailValueText() {
        const text = root.metric && root.metric.displayText ? String(root.metric.displayText).trim() : ""
        const separatorIndex = text.indexOf(" ")

        if (separatorIndex <= 0)
            return text

        return text.slice(separatorIndex + 1).trim()
    }

    function _detailLabel() {
        if (!root.metric)
            return ""

        const title = root.metric.title ? String(root.metric.title) : ""
        const valueText = root._detailValueText()

        return valueText === "" ? title : (title + " " + valueText)
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
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.gaugeSize
        height: root.gaugeSize
        radius: width / 2
        color: root.surfaceColor
        border.color: Colors.border
        border.width: 1
    }

    Canvas {
        id: ringCanvas
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.gaugeSize
        height: root.gaugeSize
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

    Text {
        id: glyphIcon
        objectName: "systemMonitorGaugeIconGlyph"
        anchors.centerIn: ringCanvas
        visible: root._useGlyphIcon
        text: root._iconGlyph
        font.family: Theme.fontMono
        font.pixelSize: root.iconSize
        color: root.iconColor
    }

    Image {
        id: iconSource
        anchors.centerIn: ringCanvas
        source: root._iconSource()
        width: root.iconSize
        height: root.iconSize
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: !root._useGlyphIcon
    }

    ColorOverlay {
        objectName: "systemMonitorGaugeIconOverlay"
        anchors.fill: iconSource
        source: iconSource
        color: root.iconColor
        visible: !root._useGlyphIcon
    }

    HoverHandler {
        id: _cursorHandler

        cursorShape: root.gaugeCursorShape
    }

    MouseArea {
        id: _hoverArea
        objectName: "systemMonitorGaugeHitArea"

        anchors.fill: parent
        enabled: true
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            if (root.interactive)
                root._wheelStepAt(wheel.x, wheel.y, wheel.angleDelta.x, wheel.angleDelta.y)
        }
    }

    onMetricChanged: ringCanvas.requestPaint()
    onNormalizedProgressChanged: ringCanvas.requestPaint()
    onSemanticColorChanged: ringCanvas.requestPaint()
    onDetailPreviewChanged: Qt.callLater(() => root.detailVisibilityChanged(root._showDetail, root.flashDetailData))
    on_ShowDetailChanged: root.detailVisibilityChanged(root._showDetail, root.flashDetailData)
}
