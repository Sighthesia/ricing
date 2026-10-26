.pragma library

// Geometry for afloat's reproduction of the osu!lazer loading ring.
//
// Reference: ppy/osu — osu.Game/Graphics/UserInterface/LoadingSpinner.cs.
// Upstream ships the arc as a FontAwesome `circle-notch` glyph and the layer
// behind it as a live `TrianglesV2` particle field. Afloat draws both: the arc
// is a Canvas stroke, the field is generated once. The proportions below are
// the glyph's, read off its 512-unit em, so the ring keeps its weight at any
// size instead of only at lazer's 60px.
//
// Only math lives here, which keeps the ring verifiable without a scene graph.

// Ring proportions as fractions of the component's short edge. The glyph's
// outer edge spans 0.875 and its inner edge 0.625, which puts the mid-stroke
// radius and the stroke weight where they are below.
var RING_RADIUS_RATIO = 0.375
var RING_STROKE_RATIO = 0.125

// Sweep left open at the top of the ring. The round caps close off what the arc
// does not draw, so this is the length of the "rounded rectangle" that orbits.
var RING_GAP_DEGREES = 90

// Twelve o'clock, where the missing wedge sits. The drawn arc starts half a gap
// past it and sweeps the long way round, so the wedge is centred here rather
// than trailing the leading cap.
var RING_TOP_DEGREES = -90

// Lazer paints the field at 0.4 alpha on its 60px spinner. This field is a
// fixed set of filled triangles rather than lazer's live particle layer, so
// their alphas accumulate; the ceiling is set well below 0.4 to land on the
// same read — a faint haze that sits under the arc, not a shape competing
// with it. Below a popup's ring size the triangles would stop reading as
// texture at all, so the field fades out continuously instead of switching off
// at a threshold.
var FIELD_ALPHA = 0.16
var FIELD_MIN_SIZE = 14
var FIELD_FULL_SIZE = 38

// Share of grid cells that survive into the field. Lazer spawns sparsely and
// continuously; a static field has to stay sparser still or the accumulated
// fills close up into a solid.
var FIELD_DENSITY = 0.28

// Upstream's field container is 0.8 of the spinner, which leaves a margin of
// background around it before the circular mask crops it back to a disc.
var FIELD_SCALE = 0.8

// Below this the field is not worth rasterizing at all. A triangle's own alpha
// is the field's alpha scaled by its height in the gradient and then cut again
// by the per-triangle spread, so anything under here would paint every triangle
// at an alpha the eye cannot separate from the surface — while still paying for
// a full raster. Callers gate on this rather than on opacity alone.
var FIELD_MIN_VISIBLE_ALPHA = 0.05

// Boxed spinner: lazer gives the plate's `TrianglesV2` the whole container
// (`RelativeSizeAxes = Axes.Both`, no 0.8 inset) at 0.2 alpha and lets the
// rounded-rectangle mask crop it, so the boxed field is generated across the
// full plate and culled to that silhouette instead. It reads more strongly than
// the bare 0.16 because it sits on the plate rather than over open background.
var BOX_FIELD_ALPHA = 0.20
var BOX_FIELD_MIN_SIZE = 22
var BOX_FIELD_FULL_SIZE = 46

// Deterministic generator. The field is rasterized once, so the same seed must
// always produce the same triangles — a spinner that reshuffles itself on a
// theme change reads as a glitch, not as motion.
function makeRandom(seed) {
    var state = (seed >>> 0) || 1
    return function() {
        state = (state * 1664525 + 1013904223) >>> 0
        return state / 4294967296
    }
}

// Everything the Canvas needs to stroke one arc.
function ringGeometry(size) {
    var edge = Number(size)
    if (!isFinite(edge) || edge <= 0)
        return null

    var gap = RING_GAP_DEGREES * Math.PI / 180
    // Start the drawn arc at the trailing edge of the gap and sweep the long way
    // round, so the gap lands centred on RING_TOP_DEGREES.
    var start = RING_TOP_DEGREES * Math.PI / 180 + gap / 2

    return {
        center: edge / 2,
        radius: edge * RING_RADIUS_RATIO,
        strokeWidth: edge * RING_STROKE_RATIO,
        gapStart: start,
        gapEnd: start + (2 * Math.PI - gap)
    }
}

// --- Boxed spinner (lazer's `withBox` form) ---------------------------
//
// Reference: the same loading spinner file, `withBox` branch. The plate is a
// `Container` with `CornerRadius = DrawWidth / 4` masked, filled with one flat
// colour at 0.7 alpha, carrying the triangle field at 0.2 and the same
// `circle-notch` arc at `Scale = 0.6`. This is the form lazer uses wherever the
// spinner sits over arbitrary content (`LoadingLayer`), because the plate
// guarantees contrast the bare arc cannot.

// CornerRadius = DrawWidth / 4, read as a ratio of the plate's short edge.
var BOX_RADIUS_RATIO = 0.25

// The arc is sized at 0.6 of the plate (`Scale = new Vector2(0.6f)`).
var BOX_ARC_SCALE = 0.6

// Plate fill alpha, straight from the `Box` in the same branch.
var BOX_PLATE_ALPHA = 0.7

// Alpha the field is painted at for a given component size.
function fieldOpacity(size) {
    var edge = Number(size)
    if (!isFinite(edge) || edge <= FIELD_MIN_SIZE)
        return 0
    if (edge >= FIELD_FULL_SIZE)
        return FIELD_ALPHA
    return FIELD_ALPHA * (edge - FIELD_MIN_SIZE) / (FIELD_FULL_SIZE - FIELD_MIN_SIZE)
}

// Side length of the field's square box, the disc the mask crops it to.
function fieldSize(size) {
    var edge = Number(size)
    if (!isFinite(edge) || edge <= 0)
        return 0
    return edge * FIELD_SCALE
}

// Whether the field is worth rasterizing at this size.
function fieldVisible(size) {
    return fieldOpacity(size) >= FIELD_MIN_VISIBLE_ALPHA
}

// --- Boxed geometry ----------------------------------------------------

// Corner radius of the plate, clamped so a tiny spinner cannot round itself
// out of existence.
function boxedRadius(size) {
    var edge = Number(size)
    if (!isFinite(edge) || edge <= 0)
        return 0
    return Math.min(edge / 2, edge * BOX_RADIUS_RATIO)
}

// Side of the arc inside the plate. The arc keeps the glyph's own proportions
// at this smaller edge, so the plate reads as a frame around a ring rather
// than as a ring with padding.
function boxedArcSize(size) {
    var edge = Number(size)
    if (!isFinite(edge) || edge <= 0)
        return 0
    return edge * BOX_ARC_SCALE
}

// Alpha the boxed field is painted at. The plate's field covers the whole
// plate (no 0.8 inset) and is cropped to the rounded rectangle, so it reaches
// its full strength a little later than the bare one.
function boxFieldOpacity(size) {
    var edge = Number(size)
    if (!isFinite(edge) || edge <= BOX_FIELD_MIN_SIZE)
        return 0
    if (edge >= BOX_FIELD_FULL_SIZE)
        return BOX_FIELD_ALPHA
    return BOX_FIELD_ALPHA * (edge - BOX_FIELD_MIN_SIZE) / (BOX_FIELD_FULL_SIZE - BOX_FIELD_MIN_SIZE)
}

function boxFieldVisible(size) {
    return boxFieldOpacity(size) >= FIELD_MIN_VISIBLE_ALPHA
}

// Squared distance from a point to the centre of an edge-sized box.
function _offsetFromCentre(edge, x, y) {
    var dx = x - edge / 2
    var dy = y - edge / 2
    return dx * dx + dy * dy
}

// Whether a point falls inside the disc lazer's bare spinner crops its field
// to.
function _insideDisc(edge, x, y) {
    var limit = (edge / 2) * (edge / 2)
    return _offsetFromCentre(edge, x, y) <= limit
}

// Whether a point falls inside the plate of the boxed spinner: a square with
// `radius` corners. Clamping the point into the corner-radius inset rectangle
// and measuring from there is the standard signed-distance form — it reduces to
// the square's own bounds away from the corners and to a quarter-circle test
// inside them.
function _insideRoundedRect(edge, radius, x, y) {
    if (x < 0 || y < 0 || x > edge || y > edge)
        return false
    var innerLeft = radius
    var innerRight = edge - radius
    var nearestX = Math.min(Math.max(x, innerLeft), innerRight)
    var nearestY = Math.min(Math.max(y, innerLeft), innerRight)
    var dx = x - nearestX
    var dy = y - nearestY
    return dx * dx + dy * dy <= radius * radius
}

// One cell of the field: a square optionally split along a diagonal, with every
// corner nudged so the field does not read as a wire grid. Triangles are pushed
// flat — [x0, y0, x1, y1, x2, y2, alpha, …] — because the Canvas replays these
// verbatim and object churn is not free on a repaint. `inside` is the silhouette
// this field is cropped to: a disc for the bare spinner, the plate's rounded
// rectangle for the boxed one.
function _emitCell(out, random, edge, cell, originX, originY, density, jitter, alpha, inside) {
    // Lazer fades the field from transparent at the top to solid at the bottom.
    // Deliberately stops short of full strength: a static grid keeps the
    // bottom row's cells on screen together, which a moving one never does.
    var centreY = (originY + cell / 2) / edge
    var base = alpha * (0.2 + 0.6 * centreY)
    if (base <= 0.01)
        return

    var corners = [
        originX + (random() - 0.5) * jitter,
        originY + (random() - 0.5) * jitter,
        originX + cell + (random() - 0.5) * jitter,
        originY + (random() - 0.5) * jitter,
        originX + cell + (random() - 0.5) * jitter,
        originY + cell + (random() - 0.5) * jitter,
        originX + (random() - 0.5) * jitter,
        originY + cell + (random() - 0.5) * jitter
    ]

    // The diagonal picks which way this cell is cut, so the field does not tile
    // into a repeating pattern.
    var tris = random() < 0.5
        ? [[0, 1, 2], [0, 2, 3]]
        : [[0, 1, 3], [1, 2, 3]]

    for (var t = 0; t < tris.length; ++t) {
        // Each half decides for itself. Keeping them independent is what leaves
        // half-drawn cells in the field, and that is what makes it read as
        // scattered facets instead of a grid of squares.
        if (random() > density)
            continue

        // Per-triangle spread keeps neighbouring cells from flattening into a
        // ramp, downwards only: nothing may reach past the field's own alpha.
        var shade = Math.min(alpha, base * (0.75 + random() * 0.25))

        var tri = tris[t]
        var ax = corners[tri[0] * 2], ay = corners[tri[0] * 2 + 1]
        var bx = corners[tri[1] * 2], by = corners[tri[1] * 2 + 1]
        var cx = corners[tri[2] * 2], cy = corners[tri[2] * 2 + 1]

        // Lazer crops the field with a mask. Emitting only the triangles whose
        // corners already fall inside the silhouette gives the same outline
        // without a mask pass — and Shapes is not an option here anyway, its
        // antialiased edge leaves a 1px opaque white ring.
        if (!inside(ax, ay) || !inside(bx, by) || !inside(cx, cy))
            continue

        out.push(ax, ay, bx, by, cx, cy, shade)
    }
}

// The triangle field for a component of the given size, as flat
// [x, y, x, y, x, y, alpha, …] runs in the field's own coordinate space.
// `density` is how much of the grid survives, and `cells` how fine it is; the
// count follows the box so the texture keeps a constant grain across sizes.
function triangleField(size, seed, density, cells) {
    var edge = fieldSize(size)
    if (!isFinite(edge) || edge <= 0)
        return []

    return _gridField(edge, edge, fieldOpacity(size), seed, density, cells,
                      function (x, y) { return _insideDisc(edge, x, y) })
}

// The boxed spinner's field: lazer gives the plate's triangle layer the whole
// plate rather than an inset disc, and masks it with the plate's rounded
// rectangle. Upstream can afford that because its field is counter-rotated only
// in its direction of travel (a live particle layer under a masked container);
// this one is a static texture pinned to the world, so the plate turns *under*
// it and the two silhouettes disagree by up to a quarter turn.
//
// The crop is therefore the largest world-aligned shape guaranteed to stay
// inside the plate at every rotation: the disc inscribed in the plate's square.
// A rotating square (rounded or not) always contains its inscribed circle, so
// this needs no mask pass and no scissor, and it cannot bleed past the plate at
// any of the four quadrant angles or in between.
function boxedTriangleField(size, seed, density, cells) {
    var edge = Number(size)
    if (!isFinite(edge) || edge <= 0)
        return []

    return _gridField(edge, edge, boxFieldOpacity(edge), seed, density, cells,
                      function (x, y) { return _insideDisc(edge, x, y) })
}

// Shared grid walk behind both fields. Keeping it in one place is what makes
// the boxed and bare spinners hold the same grain and the same vertical ramp;
// only the silhouette and the alpha curve differ.
function _gridField(edge, paintEdge, alpha, seed, density, cells, inside) {
    // Lazer spawns TrianglesV2 at roughly a third of the texture height per
    // cell. Coarser than that and the field reads as blocks rather than as the
    // faceted texture it is meant to be; the floor keeps it fine at popup sizes,
    // where scaling the cell down with the ring would leave a handful of
    // multi-pixel facets instead of a texture.
    var columns = Math.max(7, Math.min(18, Math.round(cells || edge / 4.5)))
    var cell = paintEdge / columns
    var fill = density === undefined || density === null ? FIELD_DENSITY : density
    var random = makeRandom(seed === undefined || seed === null ? 1 : seed)
    // Just enough corner drift that the grid does not show through; enough to
    // read as scattered facets, not enough to turn cells into blobs.
    var jitter = cell * 0.22

    var out = []
    for (var row = 0; row < columns; ++row) {
        for (var col = 0; col < columns; ++col) {
            _emitCell(out, random, paintEdge, cell,
                      col * cell, row * cell, fill, jitter, alpha, inside)
        }
    }
    return out
}
