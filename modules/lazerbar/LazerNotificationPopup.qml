import QtQuick

// Present one transient notification as an osu-style toast. Layout, colors,
// and motion follow osu!lazer's Notification.cs: Purple overlay palette
// (hue 255), 6px radius, 40px icon strip, 28px close column, and the
// DragContainer fling — fly left, rotate with X, fall under gravity.
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

    // osu Notification.CORNER_RADIUS.
    readonly property int cardRadius: 6
    // osu icon column Width = 40; CloseButton width = 28.
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

    // osu LoadComplete FadeInFromZero(200).
    Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 200 } }

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
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 600; easing.type: Easing.InQuad }
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

        // Pop-in slide from the screen edge, like osu LoadComplete MoveToX(500 OutQuint).
        Rectangle {
            id: card
            width: parent.width
            // osu grid row Dimension minSize 60 plus text padding 10 per side.
            height: Math.max(60, textColumn.height + 20)
            radius: root.cardRadius
            // OverlayColourProvider.Purple Background3 / Background2 on hover.
            color: gesture.containsMouse && !root.closing ? "#494554" : "#3D3946"

            Behavior on color { ColorAnimation { duration: root.reducedMotion ? 0 : 200; easing.type: Easing.OutQuint } }

            NumberAnimation {
                id: slideInAnim
                target: card
                property: "x"
                from: root.width
                to: 0
                duration: root.reducedMotion ? 0 : 500
                easing.type: Easing.OutQuint
            }

            // Icon column: app icon when available, otherwise the completion
            // check with ProgressCompletionNotification's GreenDark→GreenLight
            // vertical gradient (approximated in two clipped bands).
            Rectangle {
                id: iconStrip
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.iconStripWidth
                radius: root.cardRadius
                color: "#24222A"

                Item {
                    anchors.centerIn: parent
                    visible: root.iconSource === ""
                    width: checkBottom.implicitWidth
                    height: checkBottom.implicitHeight

                    Text {
                        id: checkBottom
                        anchors.centerIn: parent
                        text: "\u2713"
                        color: "#B3D944"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    // Top band carries the gradient's darker green.
                    Item {
                        width: parent.width
                        height: Math.ceil(parent.height / 2)
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            text: "\u2713"
                            color: "#668800"
                            font.pixelSize: 17
                            font.bold: true
                        }
                    }
                }

                Image {
                    anchors.centerIn: parent
                    visible: root.iconSource !== ""
                    source: root.iconSource
                    width: 20
                    height: 20
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }

            // osu renders summary + body as one flowing 14px Medium paragraph.
            Text {
                id: textColumn
                anchors.left: iconStrip.right
                anchors.right: closeButton.left
                anchors.top: parent.top
                anchors.margins: 10
                width: implicitWidth
                text: root.summary + (root.body.length > 0 ? (root.summary.length > 0 ? "\u00A0" : "") + root.body : "")
                color: "#FFFFFF"
                font.pixelSize: 14
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                maximumLineCount: 5
                elide: Text.ElideRight
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

            // osu CloseButton: 28px column, Gray(0)@0.15 hover background,
            // Foreground1 icon turning Content1 white on hover.
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

                    Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 200; easing.type: Easing.OutQuint } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u2713"
                    color: closeButtonMouse.containsMouse ? "#FFFFFF" : "#948FA3"
                    font.pixelSize: 12

                    Behavior on color { ColorAnimation { duration: root.reducedMotion ? 0 : 200; easing.type: Easing.OutQuint } }
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
