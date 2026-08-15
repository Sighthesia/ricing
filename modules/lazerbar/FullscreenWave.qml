import QtQuick

// Render one clipped, angled reveal layer without owning animation timing.
Item {
    id: root

    property real progress: 0
    property real angle: 0
    property color colour: "transparent"
    property real restOffset: 0
    readonly property real hiddenOffset: height + Math.abs(Math.sin(angle * Math.PI / 180) * width)
    readonly property real effectiveOffset: MotionTokens.reducedMotion
            ? restOffset : hiddenOffset + (restOffset - hiddenOffset) * Math.max(0, Math.min(1, progress))
    property alias paintedLayer: layer

    clip: true
    opacity: Math.max(0, Math.min(1, progress))

    Rectangle {
        id: layer
        width: root.width * 1.5
        height: root.height * 1.5
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.effectiveOffset
        rotation: root.angle
        transformOrigin: Item.Center
        color: root.colour
    }
}
