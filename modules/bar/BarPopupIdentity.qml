import QtQuick
import QtQuick.Effects
import "../lazerbar"

// Straight header identity layer with settings rail, optional icon, title and summary.
Rectangle {
    id: root

    property string title
    property string iconSource
    // Monochrome module glyphs opt in to the scheme-aware barIcon tint;
    // colored intents (tray icons) leave this off.
    property bool tintIcon: false
    property string summary
    property real hostWidth: 260
    property bool showClose: false
    // Foreground fade for replacement slides: icon, texts and close fade
    // while the rail background stays opaque.
    property real foregroundOpacity: 1
    signal closeRequested()

    implicitWidth: hostWidth
    implicitHeight: 48
    width: hostWidth
    height: 48
    color: LazerTheme.settingsRail
    clip: true
    radius: 0

    // Left-aligned row: optional 16px icon plus title/summary column.
    Row {
        id: layoutRow
        opacity: root.foregroundOpacity
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: root.showClose ? 52 : 12
        spacing: 8

        // Icon slot: 16px glyph plus its optional scheme-aware tint. The
        // wrapper keeps anchored effect children out of the Row — one
        // anchored child makes the whole positioner refuse to lay out,
        // which piled the texts on top of the icon.
        Item {
            id: iconSlot

            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconSource !== ""

            Image {
                id: iconImage
                objectName: "identityIcon"
                anchors.fill: parent
                source: root.iconSource
                asynchronous: true
                fillMode: Image.PreserveAspectFit
            }

            MultiEffect {
                anchors.fill: parent
                source: iconImage
                visible: iconSlot.visible && root.tintIcon
                colorization: 1
                colorizationColor: LazerTheme.barIcon

                Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
            }
        }

        Column {
            id: textColumn
            width: parent.width - (iconSlot.visible ? iconSlot.width + layoutRow.spacing : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                id: titleText
                objectName: "identityTitle"
                width: parent.width
                text: root.title
                color: LazerTheme.textPrimary
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                maximumLineCount: 1
            }

            Text {
                id: summaryText
                objectName: "identitySummary"
                width: parent.width
                text: root.summary
                color: LazerTheme.textMuted
                font.pixelSize: 10
                elide: Text.ElideRight
                visible: root.summary !== ""
                verticalAlignment: Text.AlignVCenter
                maximumLineCount: 1
                opacity: visible ? 0.92 : 0
            }
        }
    }

    // Persistent-menu close affordance pinned to the header's right edge.
    Rectangle {
        id: closeButton
        objectName: "identityCloseButton"
        width: 32
        height: 32
        opacity: root.foregroundOpacity
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        radius: 0
        visible: root.showClose
        enabled: root.showClose
        color: closeHover.hovered ? LazerTheme.hoverFill : "transparent"
        scale: closePress.pressed ? MotionTokens.pressScale : 1
        Behavior on scale {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: closeHover.hovered ? LazerTheme.textPrimary : LazerTheme.textMuted
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        HoverHandler { id: closeHover; blocking: false }
        TapHandler { id: closePress; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.closeRequested() }
    }
}
