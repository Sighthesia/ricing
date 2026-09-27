import QtQuick
import QtQuick.Shapes
import "ScreenCornerMask.js" as MaskLogic

// Fake display bezel for one screen: four corner wedges mask everything outside
// the arc so a flat panel reads as a rounded display. Each wedge is a tiny
// radius-sized shape rather than a screen-sized sheet with a punched-out
// viewport, which keeps the rasterized texture at a few kilobytes and leaves
// screen resizes from re-rasterizing a full-screen shape.
Item {
    id: root

    // Bezel corner radius in pixels. 0 (or a screen with no room for it) hides
    // the mask entirely instead of painting a degenerate wedge.
    property real radius: 16
    // Bezel paint. Pure black reads as real monitor hardware in both the dark
    // and the light color scheme.
    property color maskColor: "#000000"
    // Radius after clamping to the shorter screen edge, so wedges on the same
    // edge can never overlap past their shared midpoint.
    readonly property real effectiveRadius: MaskLogic.clampRadius(root.radius, root.width, root.height)

    // One wedge per screen corner; the mask itself stays click-through because
    // it only paints decoration.
    Repeater {
        id: cornerRepeater
        model: MaskLogic.CORNER_COUNT

        delegate: Shape {
            id: wedge
            required property int index
            readonly property real r: root.effectiveRadius
            readonly property var origin: MaskLogic.cornerOrigin(wedge.index, wedge.r, root.width, root.height)

            visible: r > 0
            x: origin[0]
            y: origin[1]
            width: r
            height: r
            // The curve renderer turns the SVG arc into a corner-sized texture
            // and only redraws it when the radius actually changes.
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.maskColor
                PathSvg { path: MaskLogic.cornerPath(wedge.r, wedge.index) }
            }
        }
    }
}
