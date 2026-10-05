import QtQuick
import QtQuick.Effects

// Band 1 of the overlay's three-block stack: the identity masthead.
//
// osu! wiki leads with a near-black full-bleed row carrying a square glyph and
// the site name at display size, and it is the darkest plane on the page — the
// wiki's own Background6-ish tone, not a raised chrome bar. So this is a
// straight full-bleed rectangle with a sharp-cornered glyph tile, the title at
// lazer Heading weight, and the close affordance at the far right. Its tone
// comes from the overlay ladder (overlayHeaderSurface), which the host and the
// two bands below it share — that shared ladder is what makes the stack read as
// three blocks rather than as a chrome bar sitting on a panel.
Rectangle {
    id: root
    property string title: ""
    property string description: ""
    // Identity glyph. A route with none simply drops the tile and the title
    // takes its left margin, so the band never reserves an empty square.
    property string iconSource: ""
    signal closeRequested()

    implicitHeight: 56
    color: LazerTheme.overlayHeaderSurface

    // Sharp-cornered identity tile: the glyph is the only content, and the tile
    // itself only appears on hover so the band stays flat at rest.
    Rectangle {
        id: iconTile
        visible: root.iconSource.length > 0
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        radius: 0
        color: iconHover.hovered ? LazerTheme.hoverFill : "transparent"
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

        Image {
            id: iconImage
            anchors.centerIn: parent
            width: 22
            height: 22
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
        }

        MultiEffect {
            anchors.fill: iconImage
            source: iconImage
            visible: iconImage.visible
            colorization: 1
            colorizationColor: LazerTheme.osuPink
        }

        HoverHandler { id: iconHover }
    }

    // Site name at display size, with the route's own line riding beside it on
    // the shared baseline so a two-tier title never drifts by a pixel.
    Text {
        id: titleText
        anchors.left: iconTile.visible ? iconTile.right : parent.left
        anchors.leftMargin: iconTile.visible ? 12 : 20
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: LazerTheme.textPrimary
        font.pixelSize: 20
        font.bold: true
    }

    Text {
        anchors.left: titleText.right
        anchors.leftMargin: 12
        anchors.baseline: titleText.baseline
        visible: text !== ""
        text: root.description
        color: LazerTheme.settingsNavInactive
        font.pixelSize: 12
    }

    Rectangle {
        id: closeButton
        width: 32; height: 32
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        radius: 0
        color: closeHover.hovered ? LazerTheme.hoverFill : "transparent"
        scale: closePress.pressed ? MotionTokens.pressScale : 1
        Behavior on scale {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
        Text { anchors.centerIn: parent; text: "x"; color: LazerTheme.textMuted; font.pixelSize: 14 }
        HoverHandler { id: closeHover }
        TapHandler { id: closePress; onTapped: root.closeRequested() }
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }
}