.pragma library

// Geometry for the shell's glow pulse.
//
// One ring, defined once, in *screen* coordinates: it is the pre-lazer
// `main`-branch ripple (a heavy leading edge with two soft bands bleeding off
// it) with nothing re-fitted per surface. Hosts do not scale it, do not give it
// their own travel and do not give it their own stroke — they hand it the
// screen extent, project its origin into their own coordinates, and clip
// whatever part of the ring happens to cross them. That is the whole trick: a
// card shows a 360px slice of the same ring the bar shows, at the same instant,
// and the swept region is the mask.
//
// Pure functions so the curves stay testable without QML.

var HALO_OPACITY = 0.25
var TRAIL_OPACITY = 0.5
var RING_OPACITY = 1

function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value))
}

// Radius from the origin to the farthest corner of the screen. Past this the
// ring is off the display entirely.
function coverRadius(originX, originY, width, height) {
    var w = Math.max(0, Number(width) || 0)
    var h = Math.max(0, Number(height) || 0)
    if (w <= 0 || h <= 0)
        return 0
    var x = clamp(Number(originX) || 0, 0, w)
    var y = clamp(Number(originY) || 0, 0, h)
    var farX = Math.max(x, w - x)
    var farY = Math.max(y, h - y)
    return Math.sqrt(farX * farX + farY * farY)
}

// The widest stroke the ring ever wears.
var MAX_RING_STROKE = 26

// Radius the ring travels to. A stroke straddles its path, so the ring is only
// clear of the screen once its inner edge has passed the cover radius — which
// is the last frame of the sweep, not before it. Aiming further made the ring
// finish crossing a surface around the middle of the clock and left the rest
// of the animation drawing nothing: the band stalled, then vanished early.
function travelRadius(cover, stroke) {
    return cover + Math.max(0, Number(stroke) || 0) / 2
}

// Where the sweep's time is spent.
//
// The ring is screen-scale by contract, so its travel is a screen's worth of
// radius — around 2100px. A linear radius therefore leaves a 360px notification
// card inside the ring for only the first 17% of the clock: about 150ms, seven
// frames, which reads as a flicker at best and as nothing at all. Measured, it
// was 120ms.
//
// The ring does not need to be a different size to fix that. It only needs the
// clock to stop being spread evenly over a screen's worth of distance and
// start spending itself where the hosts actually are. A curve above 1 grows the
// radius slowly at first and quickly at the end: every small surface is inside
// the ring for a much larger share of the sweep, while the ring still starts at
// the seed, still reaches the display edge exactly as the clock runs out, and
// still leaves without lingering. The far end of the sweep is spent at speed,
// which is where the light is anyway — off the display, drawing nothing.
var RADIUS_CURVE = 1.5

// Ring diameter over the sweep: a small seed that grows past the display.
function ringDiameter(progress, travelRadiusValue, seedDiameter) {
    var seed = Math.max(0, Number(seedDiameter) || 0)
    var max = Math.max(seed, 2 * (Number(travelRadiusValue) || 0))
    var t = clamp(Number(progress) || 0, 0, 1)
    return seed + (max - seed) * Math.pow(t, RADIUS_CURVE)
}

// Ring stroke, 14px at the seed thickening to 26px: the weight the old
// full-screen ring had, kept in screen pixels so every host shows the same one.
function ringWidth(diameter) {
    return clamp(14 + (Number(diameter) || 0) * 0.004, 14, MAX_RING_STROKE)
}

// The two soft bands behind the leading edge. The old build made its single
// afterglow 16x the ring stroke, which on a display-sized ring would be a
// wall of light; these still follow the stroke but stay bounded, so they read
// as a glow bleeding off a moving edge.
function trailWidth(ringStroke, hostWidth, hostHeight) {
    var shortEdge = Math.min(Math.abs(Number(hostWidth) || 0), Math.abs(Number(hostHeight) || 0))
    return clamp(Math.min((Number(ringStroke) || 0) * 6, shortEdge * 0.6), 16, 120)
}

function haloWidth(ringStroke) {
    return clamp((Number(ringStroke) || 0) * 3, 12, 72)
}

// Both bands lag the ring along the timeline, the halo further back, so the
// three layers read as one edge with motion blur behind it.
function trailDiameter(progress, travelRadiusValue, seedDiameter) {
    return ringDiameter(Math.max(0, (Number(progress) || 0) - 0.02), travelRadiusValue, seedDiameter)
}

function haloDiameter(progress, travelRadiusValue, seedDiameter) {
    return ringDiameter(Math.max(0, (Number(progress) || 0) - 0.05), travelRadiusValue, seedDiameter)
}
