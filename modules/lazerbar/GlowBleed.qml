import QtQuick
import "GlowBleedSvg.js" as Glow

// The light a flash throws outside its own surface.
//
// The field has to depend on one thing only: the distance to the host boundary.
// A rounded rectangle decomposes into eight pieces that share that field — four
// bands between the corner arcs, each a linear gradient along its edge normal,
// and four corner patches, each a radial gradient about an arc centre. Every
// junction evaluates the same distance from both sides, so nothing steps.
//
// The previous version spread four bands across the whole bloom box instead.
// Along an edge it was right, but a band has to end somewhere, and where it
// ended the light simply stopped: a bright plus with square corners. Measured
// against the ideal field over a 60x100 surface that version deviated by 0.93
// with a 0.97 step between neighbouring pixels; this one deviates by 0.000 and
// steps by 1/spread, which is the gradient's own slope.
//
// Bands are Rectangles with a linear gradient. Corners are not: Qt's RadialGradient
// is documented as incompatible with Rectangle ("that only supports Gradient")
// and would silently paint as a linear ramp, so each patch is an SVG rasterised
// by QPainter instead — see GlowBleedSvg.js. Flat gradient paints throughout:
// inline GLSL in ShaderEffect and MultiEffect's blur passes are both broken on
// this Qt (same finding as RippleGlowLogic.js), and a stack of fading strokes
// reads as concentric rings instead of as light leaving an edge.
Item {
    id: root

    // Halo tone; a scheme-aware token, since white light on a white card shows
    // nothing.
    property color glowColor: LazerTheme.flashGlow
    // How far the light reaches outside the host, in pixels.
    property real spread: 8
    // Alpha on the host's boundary. The host's layer opacity multiplies it
    // again, so a fading flash takes its halo down with it. Never fold a scheme
    // correction into this number: anything above 1 would clip the ramp flat at
    // its inner end, so the correction belongs on the layer's opacity.
    property real edgeAlpha: 0.6
    // The host surface's corner radius. It decides where a band hands over to a
    // corner patch, and it is also how far a patch reaches inside the host's
    // box, so the light fills the notch a rounded corner leaves instead of
    // stopping on a square edge.
    property real surfaceRadius: 0
    // Edges to light. A bar-shaped host that only wants light at its sides turns
    // the top and bottom off; a band then runs all the way to the host's own end
    // rather than stopping at an arc that is not being drawn.
    property bool bleedLeft: true
    property bool bleedRight: true
    property bool bleedTop: true
    property bool bleedBottom: true

    // Never takes input: the light sits outside the control that owns it.
    enabled: false

    // A radius cannot exceed half a side, and the bands are the host's straight
    // part, so both derive from this one clamp.
    readonly property real arc: Glow.clampArc(root.surfaceRadius, root.width, root.height)
    readonly property real bandTop: root.bleedTop ? root.arc : 0
    readonly property real bandBottom: root.bleedBottom ? root.height - root.arc : root.height
    readonly property real bandHeight: Math.max(0, root.bandBottom - root.bandTop)
    // Side length of a corner patch: the light's reach plus the arc it wraps.
    readonly property real patchSize: root.spread + root.arc

    // Straight edge: alpha depends only on the distance to that edge.
    Rectangle {
        visible: root.bleedTop && root.width - 2 * root.arc > 0
        x: root.arc
        y: -root.spread
        width: Math.max(0, root.width - 2 * root.arc)
        height: root.spread

        gradient: Gradient {
            GradientStop { position: 0; color: LazerTheme.shade(root.glowColor, 0) }
            GradientStop { position: 1; color: LazerTheme.shade(root.glowColor, root.edgeAlpha) }
        }
    }

    Rectangle {
        visible: root.bleedBottom && root.width - 2 * root.arc > 0
        x: root.arc
        y: root.height
        width: Math.max(0, root.width - 2 * root.arc)
        height: root.spread

        gradient: Gradient {
            GradientStop { position: 0; color: LazerTheme.shade(root.glowColor, root.edgeAlpha) }
            GradientStop { position: 1; color: LazerTheme.shade(root.glowColor, 0) }
        }
    }

    Rectangle {
        visible: root.bleedLeft && root.bandHeight > 0
        x: -root.spread
        y: root.bandTop
        width: root.spread
        height: root.bandHeight

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: LazerTheme.shade(root.glowColor, 0) }
            GradientStop { position: 1; color: LazerTheme.shade(root.glowColor, root.edgeAlpha) }
        }
    }

    Rectangle {
        visible: root.bleedRight && root.bandHeight > 0
        x: root.width
        y: root.bandTop
        width: root.spread
        height: root.bandHeight

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: LazerTheme.shade(root.glowColor, root.edgeAlpha) }
            GradientStop { position: 1; color: LazerTheme.shade(root.glowColor, 0) }
        }
    }

    // Corner: radial about the arc, so it meets both neighbouring bands at the
    // same value and wraps the light around the corner instead of cutting it.
    // One patch per corner; the anchor of each lives in GlowBleedSvg.js.
    Repeater {
        model: [
            { "corner": 0, "visible": root.bleedLeft && root.bleedTop },
            { "corner": 1, "visible": root.bleedRight && root.bleedTop },
            { "corner": 2, "visible": root.bleedRight && root.bleedBottom },
            { "corner": 3, "visible": root.bleedLeft && root.bleedBottom }
        ]

        delegate: Image {
            id: patch

            required property var modelData
            readonly property int corner: modelData.corner

            // A patch sits over the host's corner, so it starts one arc inside
            // the box and reaches `spread` beyond it.
            visible: modelData.visible && root.spread > 0
            x: (patch.corner === 1 || patch.corner === 2) ? root.width - root.arc : -root.spread
            y: (patch.corner === 2 || patch.corner === 3) ? root.height - root.arc : -root.spread
            width: root.patchSize
            height: root.patchSize
            // Rasterise synchronously: the halo is already on screen when a flash
            // starts, so a deferred decode would leave a frame of missing corners.
            // The source is generated, so a cache entry only ever holds a
            // superseded size or colour.
            asynchronous: false
            cache: false
            sourceSize.width: Math.max(1, Math.round(patch.width))
            sourceSize.height: Math.max(1, Math.round(patch.height))
            source: "data:image/svg+xml;utf8,"
                + encodeURIComponent(Glow.cornerSvg(patch.width, root.arc,
                                                    root.glowColor, root.edgeAlpha,
                                                    patch.corner))
        }
    }
}
