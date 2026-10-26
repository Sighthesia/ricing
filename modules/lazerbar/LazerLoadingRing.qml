pragma ComponentBehavior: Bound

import QtQuick
import "LazerLoadingRingLogic.js" as RingLogic

// osu!lazer's loading ring, reproduced for afloat, in both forms upstream ships:
//
//  - bare (default) — a round-capped arc segment turning over a faint field of
//    triangles, for a spinner sitting on a surface it can read against;
//  - boxed (`withBox: true`) — the same arc at 0.6 scale inside a masked rounded
//    plate filled at 0.7 alpha, where the PLATE is what turns.
//
// Reference: ppy/osu — osu.Game/Graphics/UserInterface/LoadingSpinner.cs. Its
// `withBox` branch is what `LoadingLayer` uses by default, i.e. the form every
// full-surface wait in lazer wears: the plate guarantees the contrast a bare arc
// cannot once it is over arbitrary content.
//
// Upstream draws the arc from the FontAwesome `circle-notch` glyph and the field
// from a live `TrianglesV2` layer, so neither is liftable as-is. Here the arc is
// a Canvas stroke and the field is generated once, so the component holds no
// per-frame work beyond transforms. The proportions come from the glyph's
// 512-unit em (see LazerLoadingRingLogic.js), which is what keeps the ring's
// weight right at 16px as well as at lazer's 60px.
//
// The two rotations stay out of step on purpose, and the boxed form adds a
// third. Bare: the arc turns smoothly and continuously while the field turns in
// four eased quarters. Boxed: the plate takes those quarters itself, the arc
// keeps its own continuous turn, and the field is pinned to the world by
// upstream's `triangles.Rotation = -MainContents.Rotation` — so inside a plate
// the field does not visibly move at all. Locking any of these together is the
// one change that would break the reproduction.
//
// Nothing here resizes its own surface: every layer animates `rotation`, and
// this item animates `scale`, all of which are transform-only, so no commit
// lands on the compositor mid-animation.
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
    // Lazer's `withBox`: paint the rounded plate and turn THAT, instead of
    // turning a bare arc over open background.
    property bool withBox: false
    // Lazer's `inverted`, and only meaningful with `withBox`: fill the plate
    // light and draw the arc dark, for a host surface that is itself dark. This
    // is not a colour preference — on a dark surface the default plate is
    // invisible by construction, since lazer fills it with the OPPOSITE of the
    // arc's colour. Upstream hits the same wall and solves it the same way: its
    // startup `Loader` sits on a dark screen and builds `LoadingSpinner(true,
    // true)`, box plus inverted.
    property bool inverted: false
    // Arc paint. The bare form sits on a surface it can read against, so it
    // takes the theme ink (`textPrimary` flips with the scheme), which is what
    // every existing call site was tuned on. The boxed form has to read against
    // its own plate instead, and the plate is always the opposite side of the
    // arc — so there the arc is lazer's fixed white, inverted to black.
    property color ringColor: root.withBox
        ? (root.inverted ? "#000000" : "#FFFFFF")
        : LazerTheme.textPrimary
    // Field paint, same reasoning one step dimmer than the arc.
    property color fieldColor: LazerTheme.textPrimary
    // Plate paint, used only by the boxed form: lazer's flat opposite-of-arc
    // fill, so the plate always guarantees contrast with whatever it covers.
    property color plateColor: root.inverted ? "#FFFFFF" : "#000000"
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

    // Lazer's `spin_duration`, the length of one quarter of the plate/field turn.
    readonly property int quarter: 900

    // The plate: lazer's masked `MainContents` container. In the bare form it
    // carries no fill and never turns, so it costs one identity transform; in
    // the boxed form it is the rounded rectangle whose quarter-turns are the
    // whole point of the shape.
    //
    // Declared first so its fill paints under the field and the arc.
    Item {
        id: plate

        width: root.edge; height: root.edge
        anchors.centerIn: parent

        // Lazer's plate: one flat colour at 0.7 alpha under a rounded mask. A
        // plain Rectangle rather than a masked pass — the arc and field inside
        // are already cropped to the silhouette by construction, so nothing
        // needs clipping and no extra texture is committed per frame.
        Rectangle {
            id: plateFill

            anchors.fill: parent
            visible: root.withBox
            radius: RingLogic.boxedRadius(root.edge)
            color: Qt.rgba(root.plateColor.r, root.plateColor.g, root.plateColor.b,
                           RingLogic.BOX_PLATE_ALPHA)
            antialiasing: true
        }

        // Boxed: the plate is what turns, in lazer's four InOutQuart quarters.
        // Bare: this animation never runs and the plate stays at its initial
        // rotation, which is what leaves the arc free to ride the root instead.
        SequentialAnimation on rotation {
            running: root.withBox && root.running && !MotionTokens.reducedMotion
            loops: Animation.Infinite
            NumberAnimation { to: 90; duration: root.quarter; easing.type: Easing.InOutQuart }
            NumberAnimation { to: 180; duration: root.quarter; easing.type: Easing.InOutQuart }
            NumberAnimation { to: 270; duration: root.quarter; easing.type: Easing.InOutQuart }
            NumberAnimation { to: 360; duration: root.quarter; easing.type: Easing.InOutQuart }
        }

        // Background field. Bare: 0.8 of the spinner, cropped to a disc, and
        // turning in quarters. Boxed: the whole plate, cropped to the plate's
        // own rounded rectangle.
        Item {
            id: fieldLayer

            width: root.withBox ? root.edge : RingLogic.fieldSize(root.edge)
            height: width
            anchors.centerIn: parent
            visible: width > 0 && (root.withBox
                                   ? RingLogic.boxFieldVisible(root.edge)
                                   : RingLogic.fieldVisible(root.edge))
            // The field is what makes the ring read as lazer's rather than a
            // generic arc, so its own entrance trails the arc slightly instead
            // of matching it frame for frame.
            opacity: root.opacity
            scale: root.scale
            // Upstream counter-rotates the field against its plate, which pins
            // the field to the world: inside a box the texture does not spin,
            // only the plate around it does. This layer holds that cancellation,
            // so the bare drift below has to live one level in — a property
            // cannot carry a binding and an animation at the same time.
            rotation: root.withBox ? -plate.rotation : 0

            // Bare-only drift. Lazer runs the bare spinner's field as four
            // InOutQuart quarters in a loop, which reads as a ratchet — it
            // hesitates at each quadrant boundary rather than sweeping. Never
            // synced to the arc's duration. A boxed field is pinned to the
            // world instead and must not also drift.
            Item {
                id: fieldDrift

                width: parent.width; height: parent.height

                SequentialAnimation on rotation {
                    running: !root.withBox && root.running && !MotionTokens.reducedMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 90; duration: root.quarter; easing.type: Easing.InOutQuart }
                    NumberAnimation { to: 180; duration: root.quarter; easing.type: Easing.InOutQuart }
                    NumberAnimation { to: 270; duration: root.quarter; easing.type: Easing.InOutQuart }
                    NumberAnimation { to: 360; duration: root.quarter; easing.type: Easing.InOutQuart }
                }

                Canvas {
                    id: fieldCanvas

                    anchors.fill: parent
                    // Boxed, lazer paints the field in the SAME colour as the
                    // plate (`Colour = inverted ? White : Black` in both the
                    // `Box` and the `TrianglesV2`), so the triangles darken the
                    // plate rather than sitting on it in a contrasting haze.
                    // Bare keeps the established afloat haze, which is what makes
                    // the boxless ring read at all.
                    property color paintColor: root.withBox ? root.plateColor : root.fieldColor
                    property bool boxed: root.withBox
                    onPaintColorChanged: requestPaint()
                    onBoxedChanged: requestPaint()
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

                        var colour = Qt.rgba(fieldCanvas.paintColor.r,
                                             fieldCanvas.paintColor.g,
                                             fieldCanvas.paintColor.b,
                                             fieldCanvas.paintColor.a)
                        // The geometry is generated against the component's own
                        // edge, not this canvas's width, so the two agree even
                        // mid-resize.
                        var field = fieldCanvas.boxed
                                ? RingLogic.boxedTriangleField(root.edge, root.seed)
                                : RingLogic.triangleField(root.edge, root.seed)
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
            }
        }

        // The arc itself, on top. Boxed it is inset to lazer's 0.6 scale; bare
        // it fills the component, because there is no plate to sit inside.
        Canvas {
            id: arcCanvas

            width: root.withBox ? RingLogic.boxedArcSize(root.edge) : root.edge
            height: width
            anchors.centerIn: parent
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

                // Proportions are the glyph's own, read off whichever edge this
                // canvas ended up with, so the inset ring keeps its weight.
                var geometry = RingLogic.ringGeometry(arcCanvas.width)
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

            // Boxed: the arc turns inside the plate, continuously — the plate's
            // quartered motion is what it is deliberately out of step with.
            RotationAnimator on rotation {
                running: root.withBox && root.running && !MotionTokens.reducedMotion
                loops: Animation.Infinite
                from: 0
                to: 360
                // 3.5 turns per plate revolution, matching upstream exactly.
                duration: 3150
            }
        }
    }

    // Bare form: the arc's continuous turn rides the whole component, exactly as
    // the boxed form's rides its inset canvas instead. Uniform, no easing,
    // looping; the asymmetry against the field's quartered motion is the whole
    // point of the reproduction.
    RotationAnimator on rotation {
        running: !root.withBox && root.running && !MotionTokens.reducedMotion
        loops: Animation.Infinite
        from: 0
        to: 360
        // 3.5 turns per field revolution, matching upstream exactly.
        duration: 3150
    }
}
