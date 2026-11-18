import QtQuick

// The light a flash throws outside its own surface.
//
// One flat gradient per edge: it dies to nothing by `spread`, so what leaves the
// host reads as spill rather than as a second surface with its own boundary.
// Each panel spans the whole bloom box across its other axis, so every corner is
// covered by two of them and reads brighter than the middle of an edge. That
// overlap is deliberate — a lit corner is what the eye expects, and ending the
// light at the square box would leave a notch of darkness beside a rounded one.
//
// Flat gradients rather than a blur or a stack of fading bands. Inline GLSL in
// ShaderEffect and MultiEffect's blur passes are both broken on this Qt (same
// finding as RippleGlowLogic.js), and bands with visible stops read as
// concentric rings instead of as light leaving an edge. A gradient is a plain
// per-pixel paint: soft by construction, and nothing is uploaded per frame.
Item {
    id: root

    // Halo tone; a scheme-aware token, since white light on a white card shows
    // nothing.
    property color glowColor: LazerTheme.flashGlow
    // How far the light reaches outside the host, in pixels.
    property real spread: 8
    // Alpha on the host's boundary. The host's own opacity multiplies it again,
    // so a fading flash takes its halo down with it.
    property real edgeAlpha: 0.6
    // The host surface's corner radius. The inner edge reaches this far inside,
    // so the light wraps a rounded corner instead of stopping on the square box
    // the panels are built from.
    property real surfaceRadius: 0
    // Edges to light. A bar-shaped host that only wants light at its sides turns
    // the top and bottom off.
    property bool bleedLeft: true
    property bool bleedRight: true
    property bool bleedTop: true
    property bool bleedBottom: true

    // Never takes input: the light sits outside the control that owns it.
    enabled: false

    // How far a panel reaches inside the host, and where the host boundary then
    // falls along it. Past the boundary the light holds `edgeAlpha` for the
    // overlap instead of ramping on into the host's middle.
    readonly property real inward: Math.max(0, root.surfaceRadius)
    readonly property real boundary: root.spread / Math.max(0.001, root.spread + root.inward)

    // Left edge: brightest against the host, gone at the outside of the bloom.
    Rectangle {
        visible: root.bleedLeft
        x: -root.spread
        y: -root.spread
        width: root.spread + root.inward
        height: root.height + 2 * root.spread

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: LazerTheme.shade(root.glowColor, 0) }
            GradientStop { position: root.boundary; color: LazerTheme.shade(root.glowColor, root.edgeAlpha) }
        }
    }

    // Right edge, mirrored so the host boundary sits at the panel's inner end.
    Rectangle {
        visible: root.bleedRight
        x: root.width - root.inward
        y: -root.spread
        width: root.spread + root.inward
        height: root.height + 2 * root.spread

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 1 - root.boundary; color: LazerTheme.shade(root.glowColor, root.edgeAlpha) }
            GradientStop { position: 1; color: LazerTheme.shade(root.glowColor, 0) }
        }
    }

    // Top edge.
    Rectangle {
        visible: root.bleedTop
        x: -root.spread
        y: -root.spread
        width: root.width + 2 * root.spread
        height: root.spread + root.inward

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: LazerTheme.shade(root.glowColor, 0) }
            GradientStop { position: root.boundary; color: LazerTheme.shade(root.glowColor, root.edgeAlpha) }
        }
    }

    // Bottom edge.
    Rectangle {
        visible: root.bleedBottom
        x: -root.spread
        y: root.height - root.inward
        width: root.width + 2 * root.spread
        height: root.spread + root.inward

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 1 - root.boundary; color: LazerTheme.shade(root.glowColor, root.edgeAlpha) }
            GradientStop { position: 1; color: LazerTheme.shade(root.glowColor, 0) }
        }
    }
}
