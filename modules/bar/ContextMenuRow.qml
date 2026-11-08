import QtQuick
import "../lazerbar"
import "../lazerbar" as Lazer

// One command row in the bar's right-click menu: leading glyph, label, and one
// trailing readout (a disclosure chevron or a state word).
//
// The row exists as its own component because the menu draws the same shape on
// four pages, and a delegate defined once keeps the icon rail, the label inset
// and the chevron slot from drifting between them.
Item {
    id: root

    property string labelText: ""
    // Resolved URL, or "" for a row without a glyph.
    property string glyphSource: ""
    // "" | "chevron" | "inline": a plain disclosure arrow, or caller-supplied
    // text painted in the trailing slot.
    property string trailing: ""
    property string trailingText: ""
    property bool enabled: true

    signal activated()

    readonly property bool hovered: rowHover.hovered && root.enabled
    readonly property real glyphSlot: 16
    readonly property real glyphInset: 10
    readonly property real labelInset: 36

    width: parent ? parent.width : 0
    height: 32
    opacity: root.enabled ? 1 : LazerTheme.settingsDisabledAlpha

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Tinted from the shared white-stroke set so a row glyph reads as the same
    // ink as its label instead of as a second, brighter element.
    BarIcon {
        id: glyph

        x: root.glyphInset
        anchors.verticalCenter: parent.verticalCenter
        width: root.glyphSlot
        height: root.glyphSlot
        visible: root.glyphSource !== ""
        source: root.glyphSource
        tint: LazerTheme.textMuted
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.labelInset
        anchors.right: trailingSlot.left
        // A row without a glyph still starts on the rail: the menu reads as a
        // column, not as rows that each found their own left edge.
        anchors.verticalCenter: parent.verticalCenter
        text: root.labelText
        color: LazerTheme.textPrimary
        font.pixelSize: 13
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    // Trailing slot: the disclosure chevron or a short state word. Exactly one
    // of the two ever occupies it, so the label's right edge never moves.
    Item {
        id: trailingSlot

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(root.trailing === "chevron" ? 16 : 0, trailingTextItem.implicitWidth)
        height: parent.height

        BarIcon {
            anchors.centerIn: parent
            width: 14
            height: 14
            visible: root.trailing === "chevron"
            source: Qt.resolvedUrl("../lazerbar/icons/chevron-right.svg")
            tint: LazerTheme.textMuted
        }

        Text {
            id: trailingTextItem

            anchors.centerIn: parent
            visible: root.trailing === "inline"
            text: root.trailingText
            color: LazerTheme.textMuted
            font.pixelSize: 11
        }
    }

    // Confirm an accepted command. Above the row's own label and glyph so the
    // whole row answers the click, but inert so it never takes the tap.
    ClickFlash {
        id: flash
        z: 2
        anchors.fill: parent
        radius: 6
    }

    HoverHandler {
        id: rowHover
        enabled: root.enabled
        blocking: false
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        enabled: root.enabled
        onTapped: {
            flash.restart()
            root.activated()
        }
    }
}
