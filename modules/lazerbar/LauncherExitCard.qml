import QtQuick

// Standalone continuation of a clicked launcher card: replays the
// notification parabolic fling (random leftward impulse, gravity fall,
// rotation trail, InQuad fade) in a layer above the closing panel, then
// destroys itself.
Rectangle {
    id: root

    property string title: ""
    property string description: ""
    property string iconSource: ""
    property bool accent: false
    readonly property bool reducedMotion: MotionTokens.reducedMotion
    readonly property real gravity: 0.005

    width: 480
    height: 64
    radius: 6
    color: root.accent ? LazerTheme.settingsSelected : LazerTheme.settingsCard
    border.width: root.accent ? 1.5 : 0
    border.color: root.accent ? LazerTheme.settingsAccent : "transparent"

    // Icon rail background like the notification icon column.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 40
        radius: 6
        color: LazerTheme.settingsRail
    }

    Image {
        visible: root.iconSource.length > 0
        anchors.left: parent.left
        anchors.leftMargin: (40 - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    Text {
        id: titleText
        x: 52
        width: Math.max(0, parent.width - x - 12)
        anchors.top: parent.top
        anchors.topMargin: root.description.length > 0 ? 12 : 0
        anchors.verticalCenter: root.description.length > 0 ? undefined : parent.verticalCenter
        text: root.title
        color: LazerTheme.textPrimary
        font.pixelSize: 14
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        x: titleText.x
        width: titleText.width
        anchors.top: titleText.bottom
        anchors.topMargin: 2
        visible: root.description.length > 0
        text: root.description
        color: LazerTheme.textMuted
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    FrameAnimation {
        id: fallAnim
        onTriggered: {
            const dt = frameTime * 1000
            root.velocityY += dt * root.gravity
            root.x += root.velocityX * dt
            root.y += root.velocityY * dt
        }
    }

    SequentialAnimation {
        id: exitFade
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: root.reducedMotion ? 100 : 600; easing.type: Easing.InQuad }
        ScriptAction { script: root.destroy() }
    }

    property real velocityX: 0
    property real velocityY: 0
    property real _startX: 0
    rotation: Math.min(0, (x - _startX) * 0.1)
    transformOrigin: Item.Center

    Component.onCompleted: {
        _startX = x
        if (!reducedMotion) {
            velocityX = -0.3 - Math.random() * 0.5
            fallAnim.start()
        }
        exitFade.restart()
    }
}
