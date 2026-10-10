import QtQuick

// Render one clipped, angled reveal layer without owning animation timing.
//
// Geometry ports osu!lazer's WaveContainer
// (osu.Game/Graphics/Containers/WaveContainer.cs, https://github.com/ppy/osu):
// the band is 1.5x the viewport, pivots on its top edge and overhangs one
// side — even layers hang left, odd layers right — so the downhill edge
// stretches further down than a centred pivot allows. Hidden state parks the
// top edge exactly on the viewport bottom; rest state uses osu's absolute
// FinalPosition values, not height fractions.
Item {
    id: root

    property real progress: 0
    property real angle: 0
    property color colour: "transparent"
    property real restOffset: 0
    // Odd layers anchor right to mirror osu's TopRight second/fourth waves.
    property bool anchorRight: false
    readonly property real hiddenOffset: height
    readonly property real effectiveOffset: MotionTokens.reducedMotion
            ? restOffset : hiddenOffset + (restOffset - hiddenOffset) * Math.max(0, Math.min(1, progress))
    property alias paintedLayer: layer

    clip: true
    // osu waves stay fully opaque through the sweep; position plus the
    // viewport clip is the reveal. Opacity tracks progress only under reduced
    // motion, where translation is removed.
    opacity: MotionTokens.reducedMotion ? Math.max(0, Math.min(1, progress)) : 1

    // The oversized band pivoting on the viewport's top edge.
    Rectangle {
        id: layer
        width: root.width * 1.5
        height: root.height * 1.5
        anchors.left: root.anchorRight ? undefined : parent.left
        anchors.right: root.anchorRight ? parent.right : undefined
        y: root.effectiveOffset
        rotation: root.angle
        transformOrigin: root.anchorRight ? Item.TopRight : Item.TopLeft
        color: root.colour
    }
}
