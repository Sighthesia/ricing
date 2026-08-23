import QtQuick

// Present page identity as a slim settings-panel title strip instead of an
// osu hero header: rail surface, compact title, muted description, and a
// sharp token-driven close affordance.
Rectangle {
    id: root
    property string title: ""
    property string description: ""
    signal closeRequested()

    implicitHeight: 48
    color: LazerTheme.settingsRail

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 64
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text {
            anchors.baseline: parent.children[1].baseline
            text: root.title
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            font.bold: true
        }

        Text {
            visible: text !== ""
            text: root.description
            color: LazerTheme.settingsNavInactive
            font.pixelSize: 12
        }
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
