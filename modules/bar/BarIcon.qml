import QtQuick
import Qt5Compat.GraphicalEffects
import "../lazerbar"

// Scheme-aware bar glyph: the shared white-stroke SVG set recolored through
// LazerTheme.barIcon so it stays legible on the dark bar and the light
// (#F2F0F5) bar alike. Drop-in for a plain centered Image: keeps the same
// geometry/source/opacity contract, tint cross-fades on scheme flips like
// the bar background itself.
Item {
    id: root

    property alias source: glyph.source
    property alias tint: overlay.color
    property alias asynchronous: glyph.asynchronous
    property alias fillMode: glyph.fillMode

    Image {
        id: glyph

        anchors.fill: parent
        visible: false
        smooth: true
    }

    ColorOverlay {
        id: overlay

        anchors.fill: parent
        source: glyph
        color: LazerTheme.barIcon

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }
}
