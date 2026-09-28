.pragma library

// Fake screen-corner bezel geometry.
//
// Each screen corner gets one wedge: a quarter-circle arc cut out of a square
// anchored on the screen corner. The wedge is described as a small list of path
// commands and as an SVG document, both of which the mask can hand to a
// rasterizer. The wedge is drawn with `Image` over an inline SVG data URL rather
// than a `Canvas`: Qt's canvas node keeps its rasterized pixels in a texture that
// is never rebuilt when the window's surface is torn down and mapped again, so a
// `Canvas` bezel silently loses its corners after a hide/show cycle (turning the
// feature off and on in the settings panel, a screen re-key, a surface remap).
// An `Image` node re-uploads its texture whenever the render target is recreated,
// so the bezel survives those cycles. Only the math lives here, which keeps the
// arc verifiable without instantiating QML.
//
// Every box is padded by `bleed` past the screen edge on purpose: a shape whose
// own bounds sit exactly on the outermost pixel column/row loses coverage to
// subpixel surface scaling, which reads as a hairline along the screen border.
// The padding puts solid paint under the screen boundary and lets the
// off-screen part be clipped away.

// Corner order used by the mask: top-left, top-right, bottom-right, bottom-left.
var CORNER_COUNT = 4

// Corner bits, so a host can paint a subset. The bezel is split across two
// surfaces (see cornerSplit): whichever corners a host covers itself, it must
// not also leave them to the shared bezel surface.
var TOP_LEFT = 1
var TOP_RIGHT = 2
var BOTTOM_RIGHT = 4
var BOTTOM_LEFT = 8
var ALL_CORNERS = TOP_LEFT | TOP_RIGHT | BOTTOM_RIGHT | BOTTOM_LEFT

// Path command verbs emitted by cornerPath.
var MOVE = "M"
var LINE = "L"
var ARC = "A"
var CLOSE = "Z"

// Bit for one corner index.
function cornerBit(corner) {
    return 1 << normalizeCorner(corner)
}

// Corner indices selected by a bit mask, in the fixed corner order.
function cornersForMask(mask) {
    var bits = Number(mask) || 0
    var selected = []
    for (var i = 0; i < CORNER_COUNT; i++) {
        if (bits & cornerBit(i))
            selected.push(i)
    }
    return selected
}

// Corners a bar surface already paints, so the shared bezel surface must skip
// them. The bar and the bezel are two separate overlay-layer surfaces, and a
// client cannot order them against each other: the compositor decides which
// wins, so a corner claimed by both flickers with whichever was mapped last.
// Handing the bar's own corners to the bar removes the race. A floating bar is
// inset by its margin and never reaches the screen corner, so it covers none.
function barCornerMask(position, floating) {
    if (floating)
        return 0
    return position === "bottom" ? (BOTTOM_LEFT | BOTTOM_RIGHT) : (TOP_LEFT | TOP_RIGHT)
}

// Corners the shared bezel surface still owns: everything the bar does not.
function barFreeCornerMask(position, floating) {
    return ALL_CORNERS & ~barCornerMask(position, floating)
}

// Keep the radius inside the shorter screen edge: two wedges on the same edge
// must never grow past their shared midpoint.
function clampRadius(radius, width, height) {
    var value = Number(radius)
    if (!isFinite(value) || value <= 0)
        return 0
    var limit = Math.min(Number(width) || 0, Number(height) || 0) / 2
    if (!isFinite(limit) || limit <= 0)
        return 0
    return Math.min(value, limit)
}

// Side length of a padded wedge box.
function cornerBoxSize(radius, bleed) {
    return Math.max(0, Number(radius) || 0) + Math.max(0, Number(bleed) || 0)
}

// Top-left position of the wedge box for one screen corner. The box hangs `bleed`
// past the screen edge on the two sides that meet at that corner, so the solid
// paint reaches the outermost pixel column and row instead of stopping on them.
function cornerOrigin(corner, boxSize, bleed, width, height) {
    var size = Math.max(0, Number(boxSize) || 0)
    var pad = Math.max(0, Number(bleed) || 0)
    var index = normalizeCorner(corner)
    var onLeft = index === 0 || index === 3
    var onTop = index === 0 || index === 1
    var right = Math.max(0, (Number(width) || 0) - size)
    var bottom = Math.max(0, (Number(height) || 0) - size)
    return [onLeft ? -pad : right, onTop ? -pad : bottom]
}

// One wedge as path commands inside its padded box: the box corner nearest the
// screen corner, the arc's tangent points where the circle meets the two screen
// edges, and the direction the arc travels between them.
function cornerPath(radius, bleed, corner) {
    var r = Math.max(0, Number(radius) || 0)
    if (r <= 0)
        return []
    var size = cornerBoxSize(r, bleed)
    var index = normalizeCorner(corner)
    var onLeft = index === 0 || index === 3
    var onTop = index === 0 || index === 1
    // Arc centre sits one radius in from the screen corner, so the arc is
    // tangent to the screen edge it meets along each of the box's inner sides.
    // The box hangs `bleed` past the screen, hence the offset by the box size.
    var centerX = onLeft ? size : size - r
    var centerY = onTop ? size : size - r
    // Tangent points: where the circle meets the screen's horizontal edge (same
    // x as the centre) and its vertical edge, in box coordinates.
    var horizontalY = onTop ? centerY - r : centerY + r
    var verticalX = onLeft ? centerX - r : centerX + r
    // The arc leaves along the horizontal screen edge and arrives along the
    // vertical one; the sweep flag is the direction that bulges towards the
    // screen corner, which alternates around the screen.
    return [
        [MOVE, onLeft ? 0 : size, onTop ? 0 : size],
        [LINE, centerX, horizontalY],
        [ARC, r, r, 0, 0, index % 2, verticalX, centerY],
        [CLOSE]
    ]
}

// One wedge as an SVG document, sized to its padded box. `Image` rasterizes it
// with QPainter at the item's device size, which antialiases the arc cleanly.
function cornerSvg(radius, bleed, corner, color) {
    var commands = cornerPath(radius, bleed, corner)
    if (commands.length === 0)
        return ""
    var size = cornerBoxSize(radius, bleed)
    var data = "M" + commands[0][1] + "," + commands[0][2]
        + "L" + commands[1][1] + "," + commands[1][2]
        + "A" + commands[2][1] + "," + commands[2][2] + " " + commands[2][3] + " "
        + commands[2][4] + " " + commands[2][5] + " " + commands[2][6] + "," + commands[2][7]
        + "Z"
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + size + '" height="' + size
        + '" viewBox="0 0 ' + size + " " + size + '"><path d="' + data
        + '" fill="' + color + '"/></svg>'
}

function normalizeCorner(corner) {
    var value = Math.round(Number(corner) || 0)
    return ((value % CORNER_COUNT) + CORNER_COUNT) % CORNER_COUNT
}
