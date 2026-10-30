.pragma library

// Which ends of the bar's seam are already under a window.
//
// The seam is painted by the desktop layer, under every window, so nothing stops
// a translucent window from showing it through its own background — a window that
// reaches the bar would carry a faint wedge of the bar's fill across its top
// corner. The seam is a piece of the desktop, so wherever a window covers it the
// seam has to be absent rather than blended, and the only way to do that under a
// compositor is to not paint those pixels at all.
//
// niri reports no window rectangles for tiled windows (a tiled window's position
// depends on the scrolling layout's offset, so `tile_pos_in_workspace_view` is
// null), but tiled windows do not need one: niri gives every tiled window the
// working area's full height minus the layout gaps, so its top edge is
// `workingTop + gap`, recoverable from the tile height alone. Its horizontal span
// is not recoverable, so a tiled window that reaches into the seam's band is
// treated as covering that end of the band rather than guessing where its column
// sits. Floating windows do report a position and are tested as rectangles.
//
// Every input is a plain object/array so the decision can be read without
// instantiating QML:
//
//   windows: [{ workspaceId, isFloating, tileWidth, tileHeight, viewX, viewY }]
//   query:   { workspaceId, workingTop, workingHeight, bandTop, bandBottom,
//              leftX0, leftX1, rightX0, rightX1 }
//
// `viewX`/`viewY` are the floating window's top-left in the workspace view
// (screen logical coordinates); a negative value means "not reported".

// Vertical slack in logical pixels. A tiled window's derived top lands a fraction
// of a pixel inside the band when the layout gap and the seam radius are equal
// (both 16 by default), which is a subpixel touch, not an overlap.
var touchTolerance = 1

// Rectangles overlap on both axes, with no assumption about argument order.
function overlaps(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1) {
    return Math.min(ax1, bx1) > Math.max(ax0, bx0)
        && Math.min(ay1, by1) > Math.max(ay0, by0)
}

// Whether one window covers the given end of the seam band.
function windowCovers(w, q, x0, x1) {
    if (!w || String(w.workspaceId === undefined ? "" : w.workspaceId) !== String(q.workspaceId))
        return false

    var width = Number(w.tileWidth) || 0
    var height = Number(w.tileHeight) || 0
    if (width <= 0 || height <= 0)
        return false

    if (w.isFloating === true) {
        // A floating window's place on the output is reported, so it only covers
        // the end it actually overlaps.
        var x = Number(w.viewX)
        var y = Number(w.viewY)
        if (!isFinite(x) || !isFinite(y) || x < 0 || y < 0)
            return false
        return overlaps(x, y, x + width, y + height,
                        x0, q.bandTop, x1, q.bandBottom)
    }

    // Tiled: the working area's full height minus the layout gaps, so the gaps
    // fall out of the tile height and the top edge follows. A fullscreen or
    // edge-maximized tile is at or past the working area's full height, which
    // clamps to no gap at all and therefore starts above the band.
    var gap = Math.max(0, (Number(q.workingHeight) - height) / 2)
    var top = Number(q.workingTop) + gap
    return top < Number(q.bandBottom) - touchTolerance
}

// The ends of the seam that must not be painted, as { left, right }.
function occludedSides(windows, q) {
    var result = { left: false, right: false }
    if (!windows || !q || !q.workspaceId)
        return result
    for (var i = 0; i < windows.length; i++) {
        var w = windows[i]
        if (!result.left && windowCovers(w, q, q.leftX0, q.leftX1))
            result.left = true
        if (!result.right && windowCovers(w, q, q.rightX0, q.rightX1))
            result.right = true
        if (result.left && result.right)
            break
    }
    return result
}
