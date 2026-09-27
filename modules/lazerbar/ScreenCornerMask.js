.pragma library

// Fake screen-corner bezel geometry.
//
// Each screen corner gets one wedge: a radius-sized square anchored on the
// screen corner, with a quarter-circle arc cut out of it. The wedge is emitted
// as SVG path data for QtQuick.Shapes' PathSvg so the arc stays smooth without
// per-corner hand-written geometry. Only the math lives here, which keeps the
// arc verifiable without instantiating QML.

// Corner order used by the mask: top-left, top-right, bottom-right, bottom-left.
var CORNER_COUNT = 4

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

// The screen-facing corner of the wedge box, in local wedge coordinates.
function cornerPoint(corner, radius) {
    var r = Math.max(0, Number(radius) || 0)
    var index = normalizeCorner(corner)
    if (index === 0)
        return [0, 0]
    if (index === 1)
        return [r, 0]
    if (index === 2)
        return [r, r]
    return [0, r]
}

// Top-left position of the wedge box for one screen corner.
function cornerOrigin(corner, radius, width, height) {
    var r = Math.max(0, Number(radius) || 0)
    var point = cornerPoint(corner, r)
    var right = Math.max(0, (Number(width) || 0) - r)
    var bottom = Math.max(0, (Number(height) || 0) - r)
    return [point[0] === 0 ? 0 : right, point[1] === 0 ? 0 : bottom]
}

// One wedge as SVG path data inside its own r x r box: straight edges along the
// two screen borders, closed by the bezel's quarter-circle arc.
function cornerPath(radius, corner) {
    var r = Math.max(0, Number(radius) || 0)
    if (r <= 0)
        return ""
    var cornerX = cornerPoint(corner, r)[0]
    var cornerY = cornerPoint(corner, r)[1]
    // Arc centre sits diagonally opposite the screen corner inside the box; the
    // travel directions point away from that corner along both screen edges.
    var centerX = r - cornerX
    var centerY = r - cornerY
    var handle = r - controlOffset(r)
    var travelX = cornerX === 0 ? -1 : 1
    var travelY = cornerY === 0 ? 1 : -1
    var tangentOnHorizontal = centerX
    var tangentOnVertical = centerY
    var controlA = tangentOnHorizontal + travelX * handle
    var controlB = tangentOnVertical - travelY * handle
    return "M" + cornerX + "," + cornerY
        + " L" + tangentOnHorizontal + "," + cornerY
        + " C" + controlA + "," + cornerY
        + " " + cornerX + "," + controlB
        + " " + cornerX + "," + tangentOnVertical
        + " Z"
}

function normalizeCorner(corner) {
    var value = Math.round(Number(corner) || 0)
    return ((value % CORNER_COUNT) + CORNER_COUNT) % CORNER_COUNT
}
