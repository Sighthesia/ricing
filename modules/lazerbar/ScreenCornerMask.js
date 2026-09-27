.pragma library

// Fake screen-corner bezel geometry.
//
// Each screen corner gets one wedge: a quarter-circle arc cut out of a square
// anchored on the screen corner. The wedge is described as a small list of path
// commands that the mask replays on a Canvas, so the arc is rasterized by
// QPainter. (QtQuick.Shapes is not used here: its curve renderer leaves a 1px
// opaque white ring on the antialiased arc, which reads as a light outline
// around the bezel.) Only the math lives here, which keeps the arc verifiable
// without instantiating QML.
//
// Every box is padded by `bleed` past the screen edge on purpose: a shape whose
// own bounds sit exactly on the outermost pixel column/row loses coverage to
// subpixel surface scaling, which reads as a hairline along the screen border.
// The padding puts solid paint under the screen boundary and lets the
// off-screen part be clipped away.

// Corner order used by the mask: top-left, top-right, bottom-right, bottom-left.
var CORNER_COUNT = 4

// Path command verbs emitted by cornerPath.
var MOVE = "M"
var LINE = "L"
var CURVE = "C"
var CLOSE = "Z"

// Quarter-circle control offset measured from the arc's tangent points.
// (1 - PI/6) * radius is the exact Bézier handle for a 90 degree arc, so the
// curve rides the true circle instead of bulging past it.
function controlOffset(radius) {
    var r = Number(radius)
    if (!isFinite(r) || r <= 0)
        return 0
    return r * (1 - Math.PI / 6)
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

// Top-left position of the wedge box for one screen corner. The box is anchored
// so it overhangs the screen by `bleed` on both screen-facing sides.
function cornerOrigin(corner, boxSize, width, height) {
    var size = Math.max(0, Number(boxSize) || 0)
    var index = normalizeCorner(corner)
    var onLeft = index === 0 || index === 3
    var onTop = index === 0 || index === 1
    var right = Math.max(0, (Number(width) || 0) - size)
    var bottom = Math.max(0, (Number(height) || 0) - size)
    return [onLeft ? 0 : right, onTop ? 0 : bottom]
}

// One wedge as path commands inside its padded box: the box corner the screen
// corner is nearest, the arc's tangent points on the two box edges it hugs, and
// the travel direction at each end of the curve.
function cornerPath(radius, bleed, corner) {
    var r = Math.max(0, Number(radius) || 0)
    if (r <= 0)
        return []
    var size = cornerBoxSize(r, bleed)
    var index = normalizeCorner(corner)
    var onLeft = index === 0 || index === 3
    var onTop = index === 0 || index === 1
    // Arc centre sits `radius` in from both screen edges, so the arc is tangent
    // to the box edge that runs along each screen border.
    var centerX = onLeft ? r : size - r
    var centerY = onTop ? r : size - r
    var tangentHorizontalX = centerX
    var tangentHorizontalY = onTop ? 0 : size
    var tangentVerticalX = onLeft ? 0 : size
    var tangentVerticalY = centerY
    // The curve leaves along the horizontal edge (toward the screen corner) and
    // arrives along the vertical edge (away from it).
    var leaveX = onLeft ? -1 : 1
    var arriveY = onTop ? 1 : -1
    var handle = r - controlOffset(r)
    return [
        [MOVE, onLeft ? 0 : size, onTop ? 0 : size],
        [LINE, tangentHorizontalX, tangentHorizontalY],
        [CURVE, tangentHorizontalX + leaveX * handle, tangentHorizontalY,
            tangentVerticalX, tangentVerticalY - arriveY * handle,
            tangentVerticalX, tangentVerticalY],
        [CLOSE]
    ]
}

function normalizeCorner(corner) {
    var value = Math.round(Number(corner) || 0)
    return ((value % CORNER_COUNT) + CORNER_COUNT) % CORNER_COUNT
}
