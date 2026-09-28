pragma ComponentBehavior: Bound

import QtQuick
import "ScreenCornerMask.js" as MaskLogic

// Fake display bezel for one screen: four corner wedges mask everything outside
// the arc so a flat panel reads as a rounded display. Each wedge is a tiny
// radius-sized box rather than a screen-sized sheet with a punched-out viewport,
// which keeps the geometry cheap and leaves screen resizes from re-rasterizing a
// full-screen surface.
//
// The wedges are rasterized from an inline SVG data URL (QPainter antialiases it
// cleanly) instead of a `QtQuick.Shapes` path, which every renderer leaves a 1px
// opaque white ring on, and instead of a `Canvas`, whose node keeps its cached
// raster in a texture that is not rebuilt when the surface is torn down and
// mapped again: a Canvas bezel silently loses its corners after the surface
// remaps (turning the feature off and on remaps it), which is how the bezel
// turns into whatever shows through instead of black. An `Image` node re-uploads
// its texture whenever the render target is recreated, so the bezel survives.
Item {
    id: root

    // Bezel corner radius in pixels. 0 (or a screen with no room for it) hides
    // the mask entirely instead of drawing a degenerate wedge.
    property real radius: 16
    // Pixels each wedge paints past the screen edge, so subpixel surface scaling
    // cannot thin out the outermost pixel column into a hairline.
    property real bleed: 2
    // Bezel paint. Pure black reads as real monitor hardware in both the dark
    // and the light color scheme; must stay opaque.
    property color maskColor: "#000000"
    // Which of the four corners this instance paints. Defaults to all of them;
    // the bar passes only the corners its own surface covers, because two
    // overlay-layer surfaces cannot be ordered against each other by the client.
    property int corners: MaskLogic.ALL_CORNERS
    // Screen extent the radius is clamped against. Defaults to this item's own
    // size, but a host that paints only some corners passes the real screen so
    // the clamp does not shrink the radius to half the host's height (the bar's
    // window is one short strip, and would otherwise cap the radius at 24).
    property real screenWidth: width
    property real screenHeight: height
    // Radius after clamping to the shorter screen edge, so wedges on the same
    // edge can never overlap past their shared midpoint.
    readonly property real effectiveRadius: MaskLogic.clampRadius(root.radius, root.screenWidth, root.screenHeight)
    // Side length of each wedge box: the clamped radius plus the off-screen bleed.
    readonly property real boxSize: MaskLogic.cornerBoxSize(root.effectiveRadius, root.bleed)

    // One wedge per selected corner; the mask itself stays click-through
    // because it only paints decoration. The model is the selected corner ids,
    // so `index` is a position in that list rather than a corner id: the corner
    // itself arrives as `modelData`.
    Repeater {
        id: cornerRepeater
        model: MaskLogic.cornersForMask(root.corners)

        delegate: Image {
            id: wedge
            required property int modelData
            readonly property int corner: modelData
            readonly property real r: root.effectiveRadius
            readonly property var origin: MaskLogic.cornerOrigin(wedge.corner, root.boxSize, root.bleed, root.width, root.height)

            visible: r > 0
            x: origin[0]
            y: origin[1]
            width: root.boxSize
            height: root.boxSize
            // Rasterize synchronously at the item's device size so a radius
            // change never leaves a frame of unpainted corner, and keep the
            // decoded wedge out of the shared image cache: the source is a
            // generated data URL, so a cache entry only ever holds a superseded
            // radius.
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            cache: false
            // A radius of 0 has no wedge to describe, so the source is cleared
            // rather than handed an empty document the image loader would reject.
            source: r > 0
                ? "data:image/svg+xml;utf8,"
                    + encodeURIComponent(MaskLogic.cornerSvg(wedge.r, root.bleed, wedge.corner, String(root.maskColor)))
                : ""
        }
    }
}
