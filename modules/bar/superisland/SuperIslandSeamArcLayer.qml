import QtQuick

// Decorative seam arcs keep the detached panel silhouette rounded without rounding the seam itself.
Item {
    id: root

    required property QtObject host
    required property Item panelHost

    x: panelHost.x
    y: panelHost.y
    width: panelHost.width
    height: host._barExpandedSeamArcRadius
    visible: host._barExpandedHintActive
        && !host._barExpandedTitleWidthClamped
        && panelHost.visible
        && host._barExpandedSeamArcProgress > 0.01
    z: panelHost.z + 1
    opacity: host._attachedPanelOpacity
    scale: host._attachedSurfaceScale
    transformOrigin: Item.Top

    // Left seam arc restores the outer silhouette on the leading edge.
    Canvas {
        id: _leftSeamArcCanvas

        x: -host._barExpandedSeamArcRadius * host._barExpandedSeamArcProgress
            + (1 - host._barExpandedSeamArcProgress) * host._barExpandedTopRadius
        y: 0
        width: host._barExpandedSeamArcRadius
        height: host._barExpandedSeamArcRadius
        visible: host._barExpandedSeamArcProgress > 0.01
        property color canvasFill: host._barExpandedPanelSurfaceColor

        onCanvasFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = canvasFill
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width, height)
            ctx.arc(0, height, width, 0, -Math.PI / 2, true)
            ctx.fill()
        }
    }

    // Right seam arc mirrors the same contour on the trailing edge.
    Canvas {
        id: _rightSeamArcCanvas

        x: parent.width
            - host._barExpandedSeamArcRadius * (1 - host._barExpandedSeamArcProgress)
            - (1 - host._barExpandedSeamArcProgress) * host._barExpandedTopRadius
        y: 0
        width: host._barExpandedSeamArcRadius
        height: host._barExpandedSeamArcRadius
        visible: host._barExpandedSeamArcProgress > 0.01
        property color canvasFill: host._barExpandedPanelSurfaceColor

        onCanvasFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = canvasFill
            ctx.beginPath()
            ctx.moveTo(width, 0)
            ctx.lineTo(0, 0)
            ctx.lineTo(0, height)
            ctx.arc(width, height, width, Math.PI, Math.PI * 1.5, false)
            ctx.fill()
        }
    }
}
