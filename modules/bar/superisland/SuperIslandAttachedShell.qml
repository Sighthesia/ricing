import QtQuick
import QtQuick.Shapes
import qs.config

// Draws the attached SuperIsland shell as one continuous pill-to-panel surface.
Item {
    id: root

    required property Item anchorItem
    required property bool active
    required property bool collapseTailHidden
    required property real visibleWidth
    required property real shellHeight
    required property real shellY
    required property real surfaceOpacity
    required property real surfaceScale
    required property real pillWidth
    required property real pillHeight
    required property real panelY
    required property real attachmentOverlap
    required property real shellRadius
    required property real bridgeOutset
    required property real inwardCornerRadius
    required property real pulseOpacity

    visible: root.active && !root.collapseTailHidden
    width: root.visibleWidth
    height: root.shellHeight
    y: root.shellY
    z: -1
    opacity: root.surfaceOpacity
    scale: root.surfaceScale
    anchors.horizontalCenter: root.anchorItem.horizontalCenter
    transformOrigin: Item.Top

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            id: shellPath

            readonly property real minRadius: 0.01
            readonly property real pillLeft: (root.width - root.pillWidth) / 2
            readonly property real pillRight: pillLeft + root.pillWidth
            readonly property real pillRadius: Math.max(minRadius, root.pillHeight / 2)
            readonly property real panelLeft: 0.5
            readonly property real panelRight: root.width - 0.5
            readonly property real panelTop:
                Math.max(root.pillHeight, root.panelY - root.y + root.attachmentOverlap)
            readonly property real panelBottom: root.height - 0.5
            readonly property real panelRadius:
                Math.max(minRadius, Math.min(root.shellRadius, Math.max(1, (panelBottom - panelTop) / 2)))
            readonly property real availableCornerHeight:
                Math.max(minRadius, panelTop - root.pillHeight)
            readonly property real neckRight:
                Math.max(pillRight, Math.min(panelRight - panelRadius - minRadius, pillRight + root.bridgeOutset))
            readonly property real neckLeft:
                Math.min(pillLeft, Math.max(panelLeft + panelRadius + minRadius, pillLeft - root.bridgeOutset))
            readonly property real cornerHorizontalSpan:
                Math.max(minRadius, Math.min(panelRight - panelRadius - neckRight, neckLeft - (panelLeft + panelRadius)))
            readonly property real cutRadius:
                Math.max(minRadius, Math.min(root.inwardCornerRadius, availableCornerHeight, cornerHorizontalSpan))
            readonly property real cornerStartY: panelTop - cutRadius
            readonly property real rightShoulderX: neckRight + cutRadius
            readonly property real leftShoulderX: neckLeft - cutRadius

            strokeColor: Colors.border
            strokeWidth: 1
            fillColor: Qt.rgba(
                Colors.surface.r * (1 - root.pulseOpacity) + Colors.highlight.r * root.pulseOpacity,
                Colors.surface.g * (1 - root.pulseOpacity) + Colors.highlight.g * root.pulseOpacity,
                Colors.surface.b * (1 - root.pulseOpacity) + Colors.highlight.b * root.pulseOpacity,
                1
            )
            startX: pillLeft + pillRadius
            startY: 0

            PathLine { x: shellPath.pillRight - shellPath.pillRadius; y: 0 }
            PathArc {
                x: shellPath.pillRight
                y: shellPath.pillRadius
                radiusX: shellPath.pillRadius
                radiusY: shellPath.pillRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: shellPath.pillRight; y: root.pillHeight }
            PathLine { x: shellPath.neckRight; y: root.pillHeight }
            PathLine { x: shellPath.neckRight; y: shellPath.cornerStartY }
            PathArc {
                x: shellPath.rightShoulderX
                y: shellPath.panelTop
                radiusX: shellPath.cutRadius
                radiusY: shellPath.cutRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: shellPath.panelRight - shellPath.panelRadius; y: shellPath.panelTop }
            PathArc {
                x: shellPath.panelRight
                y: shellPath.panelTop + shellPath.panelRadius
                radiusX: shellPath.panelRadius
                radiusY: shellPath.panelRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: shellPath.panelRight; y: shellPath.panelBottom - shellPath.panelRadius }
            PathArc {
                x: shellPath.panelRight - shellPath.panelRadius
                y: shellPath.panelBottom
                radiusX: shellPath.panelRadius
                radiusY: shellPath.panelRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: shellPath.panelLeft + shellPath.panelRadius; y: shellPath.panelBottom }
            PathArc {
                x: shellPath.panelLeft
                y: shellPath.panelBottom - shellPath.panelRadius
                radiusX: shellPath.panelRadius
                radiusY: shellPath.panelRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: shellPath.panelLeft; y: shellPath.panelTop + shellPath.panelRadius }
            PathArc {
                x: shellPath.panelLeft + shellPath.panelRadius
                y: shellPath.panelTop
                radiusX: shellPath.panelRadius
                radiusY: shellPath.panelRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: shellPath.leftShoulderX; y: shellPath.panelTop }
            PathArc {
                x: shellPath.neckLeft
                y: shellPath.cornerStartY
                radiusX: shellPath.cutRadius
                radiusY: shellPath.cutRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: shellPath.neckLeft; y: root.pillHeight }
            PathLine { x: shellPath.pillLeft; y: root.pillHeight }
            PathLine { x: shellPath.pillLeft; y: shellPath.pillRadius }
            PathArc {
                x: shellPath.pillLeft + shellPath.pillRadius
                y: 0
                radiusX: shellPath.pillRadius
                radiusY: shellPath.pillRadius
                direction: PathArc.Clockwise
            }
        }
    }
}
