.pragma library

// Corner patch maths for GlowBleed: one SVG document per corner, rasterised by
// QPainter through an Image.
//
// Why not a `Rectangle` with a Shapes RadialGradient, which is the obvious
// choice: Qt's own documentation says "RadialGradient is only supported in
// combination with Shape items. It is not compatible with Rectangle, as that
// only supports Gradient." The assignment is accepted and silently renders as a
// linear ramp, so the corners would break the halo back into bright squares.
// A Shape would rasterise correctly but leaves a 1px opaque ring on its
// antialiased edges on this Qt; an SVG patch has no ring and its own alpha
// reaches zero on every side.
//
// Each patch is square, sized spread + arc, and its gradient is anchored on the
// corner's arc centre — the point the distance field is measured from, and the
// same point the neighbouring bands measure against, so the two agree along
// their shared edge.

// A radius can never exceed half of either side, and both the bands and the
// patches derive their hand-over from this one number.
function clampArc(radius, width, height) {
    const r = Number(radius) || 0
    const half = Math.min(Number(width) || 0, Number(height) || 0) / 2
    return Math.max(0, Math.min(r, half))
}

function clamp01(value) {
    const v = Number(value)
    if (!isFinite(v))
        return 0
    return v < 0 ? 0 : v > 1 ? 1 : v
}

// `color` arrives as a QML colour, whose channels read as 0..1.
function rgbString(color) {
    const r = Math.round(clamp01(color.r) * 255)
    const g = Math.round(clamp01(color.g) * 255)
    const b = Math.round(clamp01(color.b) * 255)
    return "rgb(" + r + "," + g + "," + b + ")"
}

// Which box corner the arc centre sits on, per corner of the host.
//   0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left
var ARC_CORNER = [[1, 1], [0, 1], [0, 0], [1, 0]]

// One corner patch, `side` pixels square, with `arc` of that square eaten by the
// host's own corner radius.
//
// The host's rounded corner is punched out of the patch with a mask. Without it
// the radial's flat top paints over the corner the card itself occupies, and the
// light shows there as a bright square — invisible when the halo belongs to a
// wash of the same colour, obvious when it does not (a notification card taking
// a tinted entry flash). The disc being punched is centred on the arc and has
// radius `arc`, which keeps it entirely inside the patch square, so cutting the
// whole circle is the same as cutting the corner it stands for.
function cornerSvg(side, arc, color, edgeAlpha, corner, overlap) {
    const size = Math.max(1, Number(side) || 0)
    const radius = Math.max(0, Math.min(Number(arc) || 0, size))
    // The corner it cuts is pulled in by the host's own edge overlap, so the
    // light continues under that edge instead of stopping on the geometric
    // boundary and leaving a dark hairline there.
    const cut = Math.max(0, radius - (Number(overlap) || 0))
    // Where the host boundary falls along the gradient: full strength up to the
    // arc, then a straight ramp out to nothing at the patch's far corner.
    const boundary = clamp01(radius / size)
    const alpha = clamp01(edgeAlpha)
    const fill = rgbString(color)
    const anchor = ARC_CORNER[corner] || ARC_CORNER[0]
    const cx = anchor[0] * size
    const cy = anchor[1] * size
    const stops = '<stop offset="0" stop-color="' + fill + '" stop-opacity="' + alpha + '"/>'
        + '<stop offset="' + boundary + '" stop-color="' + fill + '" stop-opacity="' + alpha + '"/>'
        + '<stop offset="1" stop-color="' + fill + '" stop-opacity="0"/>'
    const mask = cut > 0
        ? '<mask id="c" maskUnits="userSpaceOnUse" maskContentUnits="userSpaceOnUse"'
            + ' x="0" y="0" width="' + size + '" height="' + size + '">'
            + '<rect x="0" y="0" width="' + size + '" height="' + size + '" fill="white"/>'
            + '<circle cx="' + cx + '" cy="' + cy + '" r="' + cut + '" fill="black"/>'
            + '</mask>'
        : ''
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + size + '" height="' + size
        + '" viewBox="0 0 ' + size + ' ' + size + '">'
        + '<defs><radialGradient id="g" gradientUnits="userSpaceOnUse"'
        + ' cx="' + cx + '" cy="' + cy + '" r="' + size + '">' + stops + '</radialGradient>'
        + mask + '</defs>'
        + '<rect x="0" y="0" width="' + size + '" height="' + size + '" fill="url(#g)"'
        + (cut > 0 ? ' mask="url(#c)"' : '') + '/>'
        + '</svg>'
}
