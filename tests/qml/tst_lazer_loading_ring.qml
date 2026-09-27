import QtQuick
import QtTest
import "../../modules/lazerbar/LazerLoadingRingLogic.js" as RingLogic

// Geometry contract for the lazer loading ring. The QML side is a Canvas that
// replays these numbers, so anything checked here is what actually reaches the
// screen: the ring's weight at small sizes, the gap the round caps close off,
// and the disc the field is cropped to.
TestCase {
    id: testCase
    name: "LazerLoadingRingLogic"
    when: windowShown
    visible: true
    width: 200
    height: 200

    // --- ringGeometry -------------------------------------------------------

    function test_ring_geometry_is_null_for_degenerate_sizes() {
        compare(RingLogic.ringGeometry(0), null)
        compare(RingLogic.ringGeometry(-8), null)
        compare(RingLogic.ringGeometry(NaN), null)
    }

    function test_ring_geometry_keeps_glyph_proportions() {
        // Lazer's glyph spans 0.875 of the component edge outer-to-inner across
        // both walls: outer 0.4375, inner 0.3125, stroke 0.125, mid 0.375.
        var g = RingLogic.ringGeometry(60)
        verify(Math.abs(g.radius / 60 - 0.375) < 1e-9, "mid radius off: " + g.radius)
        verify(Math.abs(g.strokeWidth / 60 - 0.125) < 1e-9, "stroke off: " + g.strokeWidth)
        verify(Math.abs(g.center - 30) < 1e-9, "centre off: " + g.center)

        var outer = (g.radius + g.strokeWidth / 2) / 60
        var inner = (g.radius - g.strokeWidth / 2) / 60
        verify(Math.abs(outer - 0.4375) < 1e-9, "outer edge off: " + outer)
        verify(Math.abs(inner - 0.3125) < 1e-9, "inner edge off: " + inner)
    }

    function test_ring_geometry_scales_with_size() {
        // The stroke has to scale with the ring or it reads as a hairline at
        // 16px and a slab at 60px.
        var small = RingLogic.ringGeometry(16)
        var large = RingLogic.ringGeometry(60)
        verify(Math.abs(small.strokeWidth / 16 - large.strokeWidth / 60) < 1e-9,
               "stroke does not scale with the ring")
        verify(Math.abs(small.radius / 16 - large.radius / 60) < 1e-9,
               "radius does not scale with the ring")
    }

    function test_ring_geometry_gap_is_90_degrees_at_the_top() {
        var g = RingLogic.ringGeometry(60)

        // The arc draws everything except the gap.
        var drawn = g.gapEnd - g.gapStart
        verify(Math.abs(drawn - (2 * Math.PI - Math.PI / 2)) < 1e-9,
               "drawn sweep is not 270 degrees: " + drawn)

        // The missing wedge runs from gapEnd up to gapStart a full turn later;
        // its midpoint has to land on twelve o'clock, which is 3PI/2 with Qt's
        // anticlockwise-from-three-o'clock convention.
        var gapMid = (g.gapEnd + (g.gapStart + 2 * Math.PI)) / 2
        verify(Math.abs(gapMid - 3 * Math.PI / 2) < 1e-9,
               "gap is not centred at the top: " + gapMid)
    }

    function test_ring_geometry_gap_stays_open_at_small_sizes() {
        // A sub-pixel stroke would close the gap and turn the ring into a disc.
        var g = RingLogic.ringGeometry(12)
        verify(g.strokeWidth >= 1, "stroke thinned to " + g.strokeWidth + " at 12px")
    }

    // --- fieldOpacity -------------------------------------------------------

    function test_field_opacity_is_bounded() {
        verify(Math.abs(RingLogic.fieldOpacity(0)) < 1e-9, "zero size should paint nothing")
        verify(RingLogic.fieldOpacity(14) < 1e-9, "below the minimum it should paint nothing")
        verify(RingLogic.fieldOpacity(14) >= 0, "opacity must not go negative")
        verify(RingLogic.fieldOpacity(38) <= 0.4 + 1e-9, "opacity must not exceed lazer's 0.4")
        verify(RingLogic.fieldOpacity(400) <= 0.4 + 1e-9, "opacity must not exceed lazer's 0.4")
    }

    function test_field_opacity_ramps_monotonically() {
        // A non-monotonic fade would read as the texture popping in and out as
        // a surface is resized.
        var previous = -1
        for (var size = 4; size <= 60; size += 1) {
            var value = RingLogic.fieldOpacity(size)
            verify(value >= previous - 1e-9, "opacity dipped at size " + size)
            previous = value
        }
    }

    function test_field_opacity_fades_out_at_popup_sizes() {
        // The network panel draws the ring at 16px, where a triangle field would
        // read as speckle rather than as texture.
        verify(RingLogic.fieldOpacity(16) < RingLogic.fieldOpacity(28),
               "16px should be dimmer than 28px")
        verify(RingLogic.fieldOpacity(16) < 0.1, "16px field should be nearly invisible")
    }

    // --- fieldSize ----------------------------------------------------------

    function test_field_size_is_lazers_zero_point_eight() {
        verify(Math.abs(RingLogic.fieldSize(60) - 48) < 1e-9, "60px field: " + RingLogic.fieldSize(60))
        verify(RingLogic.fieldSize(0) === 0, "zero size should give no field")
        verify(RingLogic.fieldSize(NaN) === 0, "invalid size should give no field")
    }

    // --- triangleField ------------------------------------------------------

    function test_triangle_field_is_empty_when_it_cannot_be_seen() {
        verify(RingLogic.triangleField(0, 1).length === 0, "zero size should emit nothing")
        verify(RingLogic.triangleField(NaN, 1).length === 0, "invalid size should emit nothing")
        // Below the minimum size the field is painted at zero alpha, so every
        // triangle is dropped and there is nothing to raster.
        verify(RingLogic.triangleField(8, 1).length === 0, "8px field should emit nothing")
    }

    function test_triangle_field_emits_whole_triangles() {
        var field = RingLogic.triangleField(60, 7)
        verify(field.length > 0, "a 60px field should emit triangles")
        // Every triangle is x0,y0,x1,y1,x2,y2,alpha — seven numbers.
        compare(field.length % 7, 0)
        for (var i = 6; i < field.length; i += 7)
            verify(field[i] >= 0 && field[i] <= 0.4 + 1e-9,
                   "alpha out of range: " + field[i])
    }

    function test_triangle_field_is_cropped_to_the_disc() {
        // Lazer masks the field to a circle. Every emitted corner has to fall
        // inside that disc or the texture would show square corners.
        var size = 60
        var edge = RingLogic.fieldSize(size)
        var limit = (edge / 2) * (edge / 2)
        var field = RingLogic.triangleField(size, 7)
        for (var i = 0; i + 6 < field.length; i += 7) {
            for (var corner = 0; corner < 3; ++corner) {
                var dx = field[i + corner * 2] - edge / 2
                var dy = field[i + corner * 2 + 1] - edge / 2
                verify(dx * dx + dy * dy <= limit + 1e-6,
                       "corner escaped the disc: " + dx + "," + dy)
            }
        }
    }

    function test_triangle_field_is_deterministic_per_seed() {
        // The raster is cached, so a theme change must not reshuffle it.
        var a = RingLogic.triangleField(60, 42)
        var b = RingLogic.triangleField(60, 42)
        compare(a.length, b.length)
        for (var i = 0; i < a.length; ++i)
            verify(a[i] === b[i], "field differed at index " + i)
    }

    function test_triangle_field_differs_between_seeds() {
        var a = RingLogic.triangleField(60, 1)
        var b = RingLogic.triangleField(60, 2)
        var identical = a.length === b.length
        if (identical) {
            for (var i = 0; i < a.length && identical; ++i)
                identical = a[i] === b[i]
        }
        verify(!identical, "two seeds produced the same field")
    }

    function test_triangle_field_grain_scales_with_size() {
        // A fixed cell count would make the launcher ring look chunky next to a
        // 20px one; the count follows the box.
        var small = RingLogic.triangleField(20, 3)
        var large = RingLogic.triangleField(60, 3)
        verify(small.length < large.length,
               "20px field should emit fewer triangles than a 60px one")

        verify(RingLogic.triangleField(600, 3).length > 0, "huge field should still emit")
    }

    // --- fieldVisible -------------------------------------------------------

    function test_field_visible_gates_the_popup_sizes() {
        // The network panel draws its ring at 16px. Rasterizing a triangle
        // field there buys nothing visible, so the layer has to be skipped.
        verify(!RingLogic.fieldVisible(16), "16px should not rasterize a field")
        verify(!RingLogic.fieldVisible(0), "zero size should not rasterize a field")
        verify(RingLogic.fieldVisible(28), "28px should rasterize a field")
        verify(RingLogic.fieldVisible(60), "60px should rasterize a field")
    }

    function test_field_visible_never_exceeds_what_is_painted() {
        // Anything fieldVisible accepts must actually emit geometry, otherwise
        // the gate lets a blank canvas through.
        for (var size = 14; size <= 60; size += 1) {
            if (RingLogic.fieldVisible(size))
                verify(RingLogic.triangleField(size, 3).length > 0,
                       "field marked visible at " + size + " but emitted nothing")
        }
    }
}
