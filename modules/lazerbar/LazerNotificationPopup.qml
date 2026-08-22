import QtQuick

// Present one transient notification as an osu-style toast: icon strip,
// text column, and a check close column. Closing plays the osu DragContainer
// fling — the card flies left, rotates with X, and falls under gravity.
Item {
    id: root
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string iconSource: ""
    property bool openState: false
    property bool closing: false
    readonly property bool reducedMotion: MotionTokens.reducedMotion
    signal dismissRequested

    // Component-surface corner radius under the lazer sharp language.
    readonly property int cardRadius: 6
    readonly property int iconStripWidth: 40
    readonly property int closeButtonWidth: 28
    // osu gravity: velocity gain per millisecond of fall (px/ms^2).
    readonly property real gravity: 0.005

    implicitWidth: 360
    implicitHeight: dragContainer.height
    height: implicitHeight
    opacity: openState ? 1 : 0

    Component.onCompleted: {
        Qt.callLater(function() { root.openState = true })
        if (!root.reducedMotion) {
            slideInAnim.restart()
            flashFade.restart()
        }
    }

    Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : MotionTokens.fast; easing.type: Easing.OutCubic } }

    function _easeInOutQuart(t) {
        return t < 0.5 ? 8 * t * t * t * t : 1 - Math.pow(-2 * t + 2, 4) / 2
    }

    // osu Interpolation.DampContinuously: exponential smoothing toward target.
    function _damp(current, target, lambda, dt) {
        return target + (current - target) * Math.exp(-lambda * dt)
    }

    // Play the osu fling: random leftward impulse, integrate gravity per
    // frame, fade out on the In curve, then release the model entry.
    function requestClose(runFling) {
        if (root.closing)
            return

        root.closing = true
        gesture.enabled = false
        closeButtonMouse.enabled = false

        if (runFling && !root.reducedMotion) {
            if (dragContainer.velocityX > -0.3)
                dragContainer.velocityX = -0.3 - Math.random() * 0.5
            dragContainer.velocityY = 0
            fallAnim.start()
            flingFade.restart()
        } else {
            quickFade.restart()
        }
    }

    // Integrate the free-fall physics on the render loop.
    FrameAnimation {
        id: fallAnim
        onTriggered: {
            dragContainer.velocityY += frameTime * root.gravity
            dragContainer.dragX += dragContainer.velocityX * frameTime
            dragContainer.dragY += dragContainer.velocityY * frameTime
        }
    }

    SequentialAnimation {
        id: flingFade
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 600; easing.type: Easing.In }
        ScriptAction { script: root.dismissRequested() }
    }

    SequentialAnimation {
        id: quickFade
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: root.reducedMotion ? 0 : 100 }
        ScriptAction { script: root.dismissRequested() }
    }

    // Physics, drag, and rotation owner — mirrors osu's DragContainer.
    Item {
        id: dragContainer
        width: root.width
        height: card.height
        x: dragX
        y: dragY
        // Rotation always trails horizontal offset, clamped counterclockwise.
        rotation: Math.min(0, dragX * 0.1)
        transformOrigin: Item.Center

        property real dragX: 0
        property real dragY: 0
        property real velocityX: 0
        property real velocityY: 0

        ParallelAnimation {
            id: springBack
            NumberAnimation { target: dragContainer; property: "dragX"; to: 0; duration: 800; easing.type: Easing.OutElastic }
            NumberAnimation { target: dragContainer; property: "dragY"; to: 0; duration: 800; easing.type: Easing.OutElastic }
        }

        // Pop-in slide from the screen edge, like osu LoadComplete.
        Rectangle {
            id: card
            width: parent.width
            height: Math.max(60, textColumn.height + 20)
            radius: root.cardRadius
            color: gesture.containsMouse && !root.closing ? "#F2252330" : LazerTheme.popupBackground
            border.width: 1
            border.color: LazerTheme.popupBorder

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }

            NumberAnimation {
                id: slideInAnim
                target: card
                property: "x"
                from: root.width
                to: 0
                duration: root.reducedMotion ? 0 : 500
                easing.type: Easing.OutQuint
            }

            // Source strip: app icon when available, otherwise a green check.
            Rectangle {
                id: iconStrip
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.iconStripWidth
                radius: root.cardRadius
                color: "#14131A"

                Text {
                    anchors.centerIn: parent
                    visible: root.iconSource === ""
                    text: "\u2713"
                    color: "#84DB4B"
                    font.pixelSize: 18
                    font.bold: true
                }

                Image {
                    anchors.centerIn: parent
                    visible: root.iconSource !== ""
                    source: root.iconSource
                    width: 24
                    height: 24
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }

            Column {
                id: textColumn
                anchors.left: iconStrip.right
                anchors.right: closeButton.left
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 2

                Text {
                    width: parent.width
                    visible: root.appName.length > 0
                    text: root.appName
                    color: LazerTheme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.summary.length > 0
                    text: root.summary
                    color: LazerTheme.textPrimary
                    font.pixelSize: 14
                    font.bold: true
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    visible: root.body.length > 0
                    text: root.body
                    color: LazerTheme.textMuted
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
            }

            // Rubber-band drag with velocity tracking; release thresholds
            // decide between fling dismiss, plain dismiss, and spring back.
            MouseArea {
                id: gesture
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                property real pressX: 0
                property real pressY: 0
                property real lastTime: 0

                onPressed: mouse => {
                    pressX = mouse.x
                    pressY = mouse.y
                    dragContainer.velocityX = 0
                    dragContainer.velocityY = 0
                    lastTime = Date.now()
                    springBack.stop()
                }

                onPositionChanged: mouse => {
                    if (!pressed)
                        return

                    let dx = mouse.x - pressX
                    let dy = mouse.y - pressY
                    const length = Math.hypot(dx, dy)
                    // Diminish drag distance further out for a rubber band feel.
                    const diminish = length <= 0 ? 0 : Math.pow(length, 0.8) / length
                    dx *= diminish
                    dy *= diminish
                    // Vertical slack only while dragging left, scaled in quart.
                    if (dx >= 0)
                        dy = 0
                    else
                        dy *= root._easeInOutQuart(Math.min(1, -dx / 200))

                    const now = Date.now()
                    const dt = Math.max(1, now - lastTime)
                    dragContainer.velocityX = root._damp(dragContainer.velocityX, (dx - dragContainer.dragX) / dt, 40, dt)
                    dragContainer.velocityY = root._damp(dragContainer.velocityY, (dy - dragContainer.dragY) / dt, 40, dt)
                    lastTime = now

                    dragContainer.dragX = dx
                    dragContainer.dragY = dy
                }

                onReleased: {
                    if (dragContainer.rotation < -10 || dragContainer.velocityX < -0.3)
                        root.requestClose(true)
                    else if (dragContainer.dragX > 30 || dragContainer.velocityX > 0.3)
                        root.requestClose(false)
                    else
                        springBack.restart()
                }

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        root.requestClose(true)
                }
            }

            // Explicit keyboard- and pointer-friendly dismissal column.
            Item {
                id: closeButton
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.closeButtonWidth

                Rectangle {
                    id: closeButtonBackground
                    anchors.fill: parent
                    color: "#26000000"
                    opacity: closeButtonMouse.containsMouse ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u2713"
                    color: closeButtonMouse.containsMouse ? LazerTheme.hoverForeground : LazerTheme.textMuted
                    font.pixelSize: 12

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                MouseArea {
                    id: closeButtonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.requestClose(true)
                }
            }

            // Additive-style initial flash from osu LoadComplete.
            Rectangle {
                id: flash
                anchors.fill: parent
                radius: root.cardRadius
                color: "#CCFFFFFF"
                opacity: 0

                NumberAnimation {
                    id: flashFade
                    target: flash
                    property: "opacity"
                    from: 0.8
                    to: 0
                    duration: root.reducedMotion ? 0 : 2000
                    easing.type: Easing.OutQuart
                }
            }
        }
    }
}
