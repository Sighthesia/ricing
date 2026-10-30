import QtQuick
import "BarSeamArc.js" as SeamLogic

// The two concave fillets on the bar's free edge: the bar's fill spills off its
// edge and closes onto each of its own corners, so the straight bottom of the
// bar reads as joining the desktop under it instead of stopping at a hard right
// angle. Painted in the bar's own colour and opacity, so it continues that
// surface rather than becoming a second shape.
//
// Painted by the desktop layer, not by the bar: the fillet hangs past the bar's
// rectangle and must sit UNDER tiled windows, so a window that reaches the bar
// covers it instead of the seam painting over the window. The wallpaper surface
// is the shell's only background-layer owner, and two surfaces in the same layer
// cannot be ordered against each other, so that surface has to be the painter
// (see modules/lazerbar/WallpaperBackground.qml). The host places this item on
// the bar's free edge, in its own surface coordinates.
Item {
    id: root

    // Fillet radius in pixels; 0 draws nothing.
    property real radius: 16
    // Where the bar sits on the output. Up-facing fillets drop below the bar,
    // down-facing ones rise above it.
    property bool atTop: true
    // Bar surface colour. Must match the bar fill exactly, or the join shows a
    // seam where the two shapes meet.
    property color fillColor: "#000000"
    // Bar fill opacity. Applied to each fillet as a whole rather than folded in
    // as alpha, so a fillet and the fill it continues blend with the desktop the
    // same way.
    property real fillOpacity: 1

    readonly property real size: Math.max(0, Number(root.radius) || 0)

    visible: root.size > 0
    height: root.size
    // Decoration only: never between the pointer and the desktop below.
    enabled: false

    // Leading fillet. Rotation turns the canonical top-left contour onto the
    // corner this bar actually has; the box itself stays anchored on that corner.
    Image {
        x: 0
        y: 0
        width: root.size
        height: root.size
        rotation: SeamLogic.rotationFor(root.atTop, true)
        fillMode: Image.PreserveAspectFit
        // Rasterize synchronously so a radius or colour change never leaves a
        // frame of the old fillet, and keep the generated document out of the
        // shared image cache: an entry could only ever hold a superseded radius.
        asynchronous: false
        cache: false
        opacity: root.fillOpacity
        source: root.size > 0
            ? "data:image/svg+xml;utf8,"
                + encodeURIComponent(SeamLogic.seamSvg(root.size, String(root.fillColor)))
            : ""

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }

    // Trailing fillet: the same contour mirrored onto the other end.
    Image {
        x: root.width - root.size
        y: 0
        width: root.size
        height: root.size
        rotation: SeamLogic.rotationFor(root.atTop, false)
        fillMode: Image.PreserveAspectFit
        asynchronous: false
        cache: false
        opacity: root.fillOpacity
        source: root.size > 0
            ? "data:image/svg+xml;utf8,"
                + encodeURIComponent(SeamLogic.seamSvg(root.size, String(root.fillColor)))
            : ""

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }
}
