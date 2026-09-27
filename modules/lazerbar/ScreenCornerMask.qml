pragma ComponentBehavior: Bound

import QtQuick
import "ScreenCornerMask.js" as MaskLogic

// Fake display bezel for one screen: four corner wedges mask everything outside
// the arc so a flat panel reads as a rounded display. Each wedge is a tiny
// radius-sized canvas rather than a screen-sized sheet with a punched-out
// viewport, which keeps the rasterized texture at a few kilobytes and leaves
// screen resizes from re-rasterizing a full-screen surface.
//
// The wedges are painted on a Canvas (QPainter) instead of QtQuick.Shapes:
// every Shapes renderer leaves a 1px opaque white ring on the antialiased arc,
// which shows up as a light outline around the bezel.
Item {
    id: root

    // Bezel corner radius in pixels. 0 (or a screen with no room for it) hides
    // the mask entirely instead of painting a degenerate wedge.
    property real radius: 16
    // Pixels each wedge paints past the screen edge, so subpixel surface scaling
    // cannot thin out the outermost pixel column into a hairline.
    property real bleed: 2
    // Bezel paint. Pure black reads as real monitor hardware in both the dark
    // and the light color scheme; must stay opaque.
    property color maskColor: "#000000"
    // Radius after clamping to the shorter screen edge, so wedges on the same
    // edge can never overlap past their shared midpoint.
    readonly property real effectiveRadius: MaskLogic.clampRadius(root.radius, root.width, root.height)
    // Side length of each wedge box: the clamped radius plus the off-screen bleed.
    readonly property real boxSize: MaskLogic.cornerBoxSize(root.effectiveRadius, root.bleed)

    // One wedge per screen corner; the mask itself stays click-through because
    // it only paints decoration.
    Repeater {
        id: cornerRepeater
        model: MaskLogic.CORNER_COUNT

        delegate: Canvas {
            id: wedge
            required property int index
            readonly property real r: root.effectiveRadius
            readonly property var origin: MaskLogic.cornerOrigin(wedge.index, root.boxSize, root.width, root.height)

            visible: r > 0
            x: origin[0]
            y: origin[1]
            width: root.boxSize
            height: root.boxSize
            // Cache the rasterized wedge in a texture instead of repainting an
            // FBO every frame; the image only changes with the geometry.
            renderTarget: Canvas.Image

            // Replay the wedge geometry; every point is relative to this box.
            onPaint: {
                var ctx = getContext("2d")
                var commands = MaskLogic.cornerPath(wedge.r, root.bleed, wedge.index)
                ctx.reset()
                ctx.fillStyle = String(root.maskColor)
                ctx.beginPath()
                for (var i = 0; i < commands.length; i++) {
                    var command = commands[i]
                    if (command[0] === MaskLogic.MOVE)
                        ctx.moveTo(command[1], command[2])
                    else if (command[0] === MaskLogic.LINE)
                        ctx.lineTo(command[1], command[2])
                    else if (command[0] === MaskLogic.CURVE)
                        ctx.bezierCurveTo(command[1], command[2], command[3], command[4], command[5], command[6])
                    else
                        ctx.closePath()
                }
                ctx.fill()
            }

            // A new radius or bleed resizes the box, which already repaints the
            // image; the paint colour needs an explicit request.
            Connections {
                target: root
                function onMaskColorChanged() { wedge.requestPaint() }
            }
        }
    }
}
