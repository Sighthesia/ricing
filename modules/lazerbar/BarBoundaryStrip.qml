import QtQuick

// Vertical boundary rule between two bar groups: a rounded indicator strip
// rather than a hairline divider. The box the rule is drawn in is part of the
// component so every caller reserves the same room around it; `hPadding` is
// that room on each side, and a caller that needs extra separation (the tray's
// boundary, which must mirror the next widget's own glyph padding) adds it to
// its layout box, not here.
Item {
    id: root

    // Rule metrics. The bar's own indicator token keeps every bar-level strip
    // on one thickness and one radius; the rule's length matches the glyphs it
    // separates.
    property real thickness: LazerTheme.barIndicatorHeight
    property real length: LazerTheme.barGlyphSize
    // Empty room on each side of the rule, inside this item's own box.
    property real hPadding: 0
    property color color: Qt.rgba(LazerTheme.barIcon.r, LazerTheme.barIcon.g,
            LazerTheme.barIcon.b, 0.22)

    implicitWidth: root.thickness + root.hPadding * 2
    implicitHeight: root.length

    Rectangle {
        anchors.centerIn: parent
        width: root.thickness
        height: root.length
        radius: root.thickness / 2
        color: root.color

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }
}
