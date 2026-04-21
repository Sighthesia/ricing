import QtQuick
import QtQuick.Shapes
import qs.config

import "AttachedExpansionGeometry.js" as AttachedExpansionGeometry

// Draws an attached expansion shell as one continuous pill-to-panel surface.
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
    property real throwOffsetY: 0
    required property real pillWidth
    required property real pillHeight
    required property real panelWidth
    required property real panelY
    required property real attachmentOverlap
    required property real shellRadius
    required property real bridgeOutset
    required property real inwardCornerRadius
    required property real pulseOpacity
    required property real surfaceFillOpacity

    visible: root.active && !root.collapseTailHidden
    width: root.visibleWidth
    height: root.shellHeight
    y: root.shellY + root.throwOffsetY
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
            readonly property real effectiveShellRadius: Math.max(root.shellRadius, Theme.screenCornerRadius)
            readonly property var shapeMetrics: AttachedExpansionGeometry.metrics(root, effectiveShellRadius)

            strokeColor: Colors.border
            strokeWidth: 1
            fillColor: Qt.rgba(
                Colors.surface.r * (1 - root.pulseOpacity) + Colors.highlight.r * root.pulseOpacity,
                Colors.surface.g * (1 - root.pulseOpacity) + Colors.highlight.g * root.pulseOpacity,
                Colors.surface.b * (1 - root.pulseOpacity) + Colors.highlight.b * root.pulseOpacity,
                root.surfaceFillOpacity
            )
            startX: shapeMetrics.pillLeft + shapeMetrics.pillRadius
            startY: 0

            PathLine { x: shellPath.shapeMetrics.pillRight - shellPath.shapeMetrics.pillRadius; y: 0 }
            PathArc {
                x: shellPath.shapeMetrics.pillRight
                y: shellPath.shapeMetrics.pillRadius
                radiusX: shellPath.shapeMetrics.pillRadius
                radiusY: shellPath.shapeMetrics.pillRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: shellPath.shapeMetrics.pillRight; y: root.pillHeight }
            PathLine { x: shellPath.shapeMetrics.neckRight; y: root.pillHeight }
            PathLine { x: shellPath.shapeMetrics.neckRight; y: shellPath.shapeMetrics.cornerStartY }
            PathArc {
                x: shellPath.shapeMetrics.rightShoulderX
                y: shellPath.shapeMetrics.panelTop
                radiusX: shellPath.shapeMetrics.cutRadius
                radiusY: shellPath.shapeMetrics.cutRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: shellPath.shapeMetrics.panelRight - shellPath.shapeMetrics.panelRadius; y: shellPath.shapeMetrics.panelTop }
            PathArc {
                x: shellPath.shapeMetrics.panelRight
                y: shellPath.shapeMetrics.panelTop + shellPath.shapeMetrics.panelRadius
                radiusX: shellPath.shapeMetrics.panelRadius
                radiusY: shellPath.shapeMetrics.panelRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: shellPath.shapeMetrics.panelRight; y: shellPath.shapeMetrics.panelBottom - shellPath.shapeMetrics.panelRadius }
            PathArc {
                x: shellPath.shapeMetrics.panelRight - shellPath.shapeMetrics.panelRadius
                y: shellPath.shapeMetrics.panelBottom
                radiusX: shellPath.shapeMetrics.panelRadius
                radiusY: shellPath.shapeMetrics.panelRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: shellPath.shapeMetrics.panelLeft + shellPath.shapeMetrics.panelRadius; y: shellPath.shapeMetrics.panelBottom }
            PathArc {
                x: shellPath.shapeMetrics.panelLeft
                y: shellPath.shapeMetrics.panelBottom - shellPath.shapeMetrics.panelRadius
                radiusX: shellPath.shapeMetrics.panelRadius
                radiusY: shellPath.shapeMetrics.panelRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: shellPath.shapeMetrics.panelLeft; y: shellPath.shapeMetrics.panelTop + shellPath.shapeMetrics.panelRadius }
            PathArc {
                x: shellPath.shapeMetrics.panelLeft + shellPath.shapeMetrics.panelRadius
                y: shellPath.shapeMetrics.panelTop
                radiusX: shellPath.shapeMetrics.panelRadius
                radiusY: shellPath.shapeMetrics.panelRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: shellPath.shapeMetrics.leftShoulderX; y: shellPath.shapeMetrics.panelTop }
            PathArc {
                x: shellPath.shapeMetrics.neckLeft
                y: shellPath.shapeMetrics.cornerStartY
                radiusX: shellPath.shapeMetrics.cutRadius
                radiusY: shellPath.shapeMetrics.cutRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: shellPath.shapeMetrics.neckLeft; y: root.pillHeight }
            PathLine { x: shellPath.shapeMetrics.pillLeft; y: root.pillHeight }
            PathLine { x: shellPath.shapeMetrics.pillLeft; y: shellPath.shapeMetrics.pillRadius }
            PathArc {
                x: shellPath.shapeMetrics.pillLeft + shellPath.shapeMetrics.pillRadius
                y: 0
                radiusX: shellPath.shapeMetrics.pillRadius
                radiusY: shellPath.shapeMetrics.pillRadius
                direction: PathArc.Clockwise
            }
        }
    }
}
