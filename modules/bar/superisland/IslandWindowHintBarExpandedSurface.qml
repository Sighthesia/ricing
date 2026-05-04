import QtQuick
import qs.config

// Owns the shared backdrop and decorative caps for the combined bar-expanded surface.
Item {
    id: root

    required property Item card

    readonly property real _combinedPulseOpacity: Math.max(
        root.card._switchPulseOpacity,
        root.card._sharedBackgroundPulseOpacity
    )

    implicitWidth: root.card._barExpandedDetachedWidth
    implicitHeight: root.card._barExpandedCombinedHeight
    width: implicitWidth
    height: implicitHeight

    // Shared backdrop keeps the title and workspace lanes readable as one surface.
    Item {
        id: _backdropLayer

        x: 0
        y: root.card._combinedBackdropOffsetY
        width: parent.width
        height: parent.height
        z: -1
        scale: root.card._switchPulseScale
        transformOrigin: Item.Center

        // Pulse placeholder keeps the shared backdrop layering stable.
        Item {
            id: _pulseBackdrop
            anchors.fill: parent
            visible: false
        }

        // Vertical drift keeps the shared backdrop aligned during the title reveal.
        Behavior on y {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        // Title lane keeps the seam square.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Theme.barHeight
            radius: 0
            color: root.card._stageFill
            scale: root.card._switchPulseScale
            transformOrigin: Item.Center
        }

        // Workspace lane keeps the seam square.
        Rectangle {
            x: 0
            y: Theme.barHeight
            width: parent.width
            height: root.card._barExpandedDetachedContentHeight
            radius: 0
            color: root.card._stageFill
            scale: root.card._switchPulseScale
            transformOrigin: Item.Center
        }

        // Pulse overlay reuses the same backdrop lanes and corner caps.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Theme.barHeight
            radius: 0
            color: root.card._switchPulseFill
            opacity: root._combinedPulseOpacity
            visible: opacity > 0
            z: 1
            scale: root.card._switchPulseScale
            transformOrigin: Item.Center
        }

        // Lower pulse lane mirrors the workspace surface.
        Rectangle {
            x: 0
            y: Theme.barHeight
            width: parent.width
            height: root.card._barExpandedDetachedContentHeight
            radius: 0
            color: root.card._switchPulseFill
            opacity: root._combinedPulseOpacity
            visible: opacity > 0
            z: 1
            scale: root.card._switchPulseScale
            transformOrigin: Item.Center
        }

        // Left corner cap sits outside the square seam.
        Canvas {
            id: _leftCornerCapCanvas
            x: -root.card._barExpandedNotchRadius
            y: -root.card._barExpandedNotchRadius
            width: root.card._barExpandedNotchRadius
            height: root.card._barExpandedNotchRadius
            property color canvasFill: root._combinedPulseOpacity > 0 ? root.card._switchPulseFill : root.card._stageFill

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

        // Right corner cap mirrors the same outer arc.
        Canvas {
            id: _rightCornerCapCanvas
            x: parent.width
            y: -root.card._barExpandedNotchRadius
            width: root.card._barExpandedNotchRadius
            height: root.card._barExpandedNotchRadius
            property color canvasFill: root._combinedPulseOpacity > 0 ? root.card._switchPulseFill : root.card._stageFill

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
    }
}
