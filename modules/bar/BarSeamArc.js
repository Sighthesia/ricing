.pragma library

// Concave seam fillets for the bar's free edge.
//
// A fillet is the inverse rounded corner: a quarter-circle arc tangent to the
// bar's free edge and to the bar's side, with the surface filled on the corner
// side. Thickest at the corner and tapering to a point along each edge, it reads
// as the bar's fill spilling off its edge and closing onto the corner instead of
// stopping at a hard right angle. The old shell used the same shape to join a
// wide pill to the narrower panel attached under it (branch `20260509`,
// modules/bar/superisland/SuperIslandSeamArcLayer.qml); this is that contour
// with the join pointed outward at the bar's own corners.
//
// Only the math lives here. The fillet is rasterized from an inline SVG data URL
// rather than painted on a `Canvas`: a canvas node keeps its raster in a texture
// that is not rebuilt when a layer-shell surface is torn down and mapped again,
// so a canvas fillet silently goes blank after a remap. That fault is why the
// screen bezel here is an `Image` too (modules/lazerbar/ScreenCornerMask.js), and
// the old branch's canvas seam predates the finding.

// One fillet as an SVG document, sized to its square box.
//
// Canonical orientation: the bar's surface sits ABOVE the box and the bar's
// corner is the box's top-left corner. The surface then descends from the free
// edge (the box's top side) along the arc and arrives tangent to the bar's side
// (the box's left side). Every other corner is this document rotated by a
// multiple of 90 degrees; see `rotationFor`.
function seamSvg(radius, color) {
    var r = Math.max(0, Number(radius) || 0)
    if (r <= 0)
        return ""
    // From the tangent point on the free edge, sweep to the tangent point on the
    // side edge. A centre of (r,r) keeps the arc tangent to both edges, and
    // sweep 0 is the one that bulges towards the corner rather than away from it.
    var data = "M0,0H" + r + "A" + r + "," + r + " 0 0 0 0," + r + "Z"
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + r + '" height="' + r
        + '" viewBox="0 0 ' + r + " " + r + '"><path d="' + data
        + '" fill="' + color + '"/></svg>'
}

// Clockwise rotation (degrees) that puts the canonical top-left fillet on the
// corner this bar actually has: `atTop` is where the bar sits on the output,
// `onLeft` which of its two ends this is.
function rotationFor(atTop, onLeft) {
    if (atTop)
        return onLeft ? 0 : 90
    return onLeft ? 270 : 180
}
