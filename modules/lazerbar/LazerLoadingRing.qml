pragma ComponentBehavior: Bound

import QtQuick
import "LazerLoadingRingLogic.js" as RingLogic

// osu!lazer's loading ring, reproduced for afloat: a round-capped arc segment
// turning over a faint field of triangles.
//
// Reference: ppy/osu — osu.Game/Graphics/UserInterface/LoadingSpinner.cs,
// without its surrounding box. Upstream draws the arc from the FontAwesome
// `circle-notch` glyph and puts a live `TrianglesV2` layer behind it. Here the
// arc is a Canvas stroke and the field is generated once, so the component
// holds no per-frame work beyond two transforms. The proportions come from the
// glyph's 512-unit em (see LazerLoadingRingLogic.js), which is what keeps the
// ring's weight right at 16px as well as at 60px.
//
// Two rotations run here and they are deliberately out of step. The arc turns
// smoothly and continuously; the field turns in four eased quarters. Upstream
// spends 3150ms of arc on 4x900ms of field — a 3.5:1 ratio — and the mismatch is
// what stops the pair from reading as one rigid object. Locking them together
// is the one change that would break the reproduction.
//
// Nothing here resizes its own surface: both layers animate `rotation` and this
// item animates `scale`, all of which are transform-only, so no commit lands on
// the compositor mid-animation.
Item {
    id: root

    // Whether the ring is in a loading state at all. Drives the entrance and
    // exit; the spin follows `running` independently so a ring can sit still
    // (reduced motion, or a first paint before anything is known) without
    // being torn down.
    property bool active: true
    // Whether the ring is currently waiting on something. Separated from
    // `active` so a caller can keep a finished ring on screen, or freeze it.
    property bool running: true
    // Arc paint. Lazer draws white on the dark player background; textPrimary
    // is the afloat token that flips with the colour scheme.
    property color ringColor: LazerTheme.textPrimary
    // Field paint, same reasoning one step dimmer than the arc.
    property color fieldColor: LazerTheme.textPrimary
    // Fixed seed: the field is rasterized once, so the same seed has to keep
    // producing the same triangles across a theme or size change.
    property int seed: 1

    // Lazer pops in from nothing over 500ms OutQuint and shrinks to 0.6 on the
    // way out, fading at half that rate. Driven by Behavior rather than
    // explicit animations so an interrupted transition reverses from wherever
    // it currently sits, which is the contract every other lazer surface here
    // follows.
    readonly property real shownScale: active ? 1 : 0.6

    scale: root.shownScale
    opacity: active ? 1 : 0

    Behavior on scale {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.settingsEnter; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.settingsEnter / 2; easing.type: Easing.OutQuint }
    }

    // Short edge drives every measurement: the ring is a square mark and both
    // of its layers are sized off it, so a non-square box must not stretch them.
    readonly property real edge: Math.max(0, Math.min(width, height))

    // Background field. Sits behind the arc at lazer's 0.8 size, and is the
    // only part that turns in quarters rather than smoothly.
    Item {
        id: fieldLayer

        width: RingLogic.fieldSize(root.edge); height: RingLogic.fieldSize(root.edge)
        anchors.centerIn: parent
        visible: width > 0 && RingLogic.fieldVisible(root.edge)
        // The field is what makes the ring read as lazer's rather than a generic
        // arc, so its own entrance trails the arc slightly instead of matching
        // it frame for frame.
        opacity: root.opacity
        scale: root.scale

        Canvas {
            id: fieldCanvas

            anchors.fill: parent
            // Mirror the colour so a theme change repaints: a Canvas only
            // repaints itself on geometry, not on whatever its onPaint reads.
            property color fillColor: root.fieldColor
            onFillColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            // Rasterized once and then only transformed, so the field costs
            // nothing per frame.
            renderTarget: Canvas.Image

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                if (!ctx)
                    return

                var colour = Qt.rgba(fieldCanvas.fillColor.r,
                                     fieldCanvas.fillColor.g,
                                     fieldCanvas.fillColor.b,
                                     fieldCanvas.fillColor.a)
                // The geometry is generated against the component's own edge,
                // not this canvas's width, so the two agree even mid-resize.
                var field = RingLogic.triangleField(root.edge, root.seed)
                for (var i = 0; i + 6 < field.length; i += 7) {
                    ctx.fillStyle = Qt.rgba(colour.r, colour.g, colour.b, colour.a * field[i + 6])
                    ctx.beginPath()
                    ctx.moveTo(field[i], field[i + 1])
                    ctx.lineTo(field[i + 2], field[i + 3])
                    ctx.lineTo(field[i + 4], field[i + 5])
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }

        // Lazer runs the field as four InOutQuart quarters in a loop, which
        // reads as a ratchet: it hesitates at each quadrant boundary rather
        // than sweeping. Never synced to the arc's duration.
        SequentialAnimation on rotation {
            running: root.running && !MotionTokens.reducedMotion
            loops: Animation.Infinite
            NumberAnimation { to: 90; duration: fieldLayer.quarter; easing.type: Easing.InOutQuart }
            NumberAnimation { to: 180; duration: fieldLayer.quarter; easing.type: Easing.InOutQuart }
            NumberAnimation { to: 270; duration: fieldLayer.quarter; easing.type: Easing.InOutQuart }
            NumberAnimation { to: 360; duration: fieldLayer.quarter; easing.type: Easing.InOutQuart }
        }

        // Lazer's `spin_duration`, split into the four quarters above.
        readonly property int quarter: 900
    }

    // The arc itself, on top.
    Canvas {
        id: arcCanvas

        anchors.fill: parent
        property color strokeColor: root.ringColor
        onStrokeColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
        renderTarget: Canvas.Image

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (!ctx)
                return

            var geometry = RingLogic.ringGeometry(root.edge)
            if (!geometry)
                return

            var colour = arcCanvas.strokeColor
            ctx.beginPath()
            // Qt measures arc angles anticlockwise from three o'clock, so the
            // geometry hands over absolute start/end angles rather than a sweep.
            ctx.arc(geometry.center, geometry.center, geometry.radius,
                    geometry.gapStart, geometry.gapEnd)
            ctx.lineWidth = geometry.strokeWidth
            // Round caps are what make the drawn end of the ring read as a
            // rounded rectangle corner instead of a cut-off band.
            ctx.lineCap = "round"
            ctx.strokeStyle = Qt.rgba(colour.r, colour.g, colour.b, colour.a)
            ctx.stroke()
        }
    }

    // Uniform turn, no easing, looping. The asymmetry against the field's
    // quartered motion is the whole point of the reproduction.
    RotationAnimator on rotation {
        running: root.running && !MotionTokens.reducedMotion
        loops: Animation.Infinite
        from: 0
        to: 360
        // 3.5 turns per field revolution, matching upstream exactly.
        duration: 3150
    }
}
