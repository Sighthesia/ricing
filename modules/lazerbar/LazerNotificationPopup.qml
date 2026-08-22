import QtQuick
import Quickshell

// Present one transient notification as a lazer-style toast. The surface is a
// component-level 6px card over theme tokens: app-name header, summary title,
// muted body, and D-Bus action buttons, with a 40px icon rail and 28px close
// column. Motion and colors follow the settings-panel authority (MotionTokens,
// hover swap, click flash); the exit keeps the osu DragContainer fling — fly
// left, rotate with X, fall under gravity.
Item {
    id: root
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string iconSource: ""
    property string actionsText: ""
    // Actions arrive as JSON because ListModel list roles read back as null.
    readonly property var actionList: {
        try {
            const parsed = JSON.parse(root.actionsText)
            return Array.isArray(parsed) ? parsed : []
        } catch (err) {
            return []
        }
    }
    // D-Bus icon entries may be theme names rather than paths.
    readonly property string resolvedIcon: {
        const src = root.iconSource
        if (src === "" || src.indexOf("/") === 0 || src.indexOf(":") >= 0)
            return src
        return Quickshell.iconPath(src, "")
    }
    property bool openState: false
    property bool closing: false
    readonly property bool reducedMotion: MotionTokens.reducedMotion
    signal dismissRequested
    signal actionRequested(string identifier)

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

    // Integrate the free-fall physics on the render loop. frameTime is in
    // seconds; convert to ms to match the osu px/ms velocity/gravity units.
    FrameAnimation {
        id: fallAnim
        onTriggered: {
            const dt = frameTime * 1000
            dragContainer.velocityY += dt * root.gravity
            dragContainer.dragX += dragContainer.velocityX * dt
            dragContainer.dragY += dragContainer.velocityY * dt
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
            // Structured rows need more than osu's 60px minimum; padding is
            // 12px top/bottom around the content column.
            height: Math.max(72, contentColumn.height + 24)
            radius: root.cardRadius
            color: cardHover.hovered && !root.closing ? LazerTheme.settingsCardHover : LazerTheme.settingsCard

            Behavior on color { ColorAnimation { duration: root.reducedMotion ? 0 : MotionTokens.fast; easing.type: Easing.OutQuint } }

            // Non-blocking tint observer so buttons keep their own hover.
            HoverHandler {
                id: cardHover
            }

            NumberAnimation {
                id: slideInAnim
                target: card
                property: "x"
                from: root.width
                to: 0
                duration: root.reducedMotion ? 0 : 500
                easing.type: Easing.OutQuint
            }

            // Icon rail: app icon when available, otherwise the completion
            // check with ProgressCompletionNotification's GreenDark→GreenLight
            // vertical gradient (approximated in two clipped bands).
            Rectangle {
                id: iconStrip
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.iconStripWidth
                radius: root.cardRadius
                color: LazerTheme.settingsRail

                Item {
                    anchors.centerIn: parent
                    visible: root.resolvedIcon === ""
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
                    visible: root.resolvedIcon !== ""
                    source: root.resolvedIcon
                    width: 22
                    height: 22
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }

            // Rubber-band drag with velocity tracking; release thresholds
            // decide between fling dismiss, plain dismiss, and spring back.
            // Declared under the interactive children so they receive input
            // first; hover observation lives in cardHover instead.
            MouseArea {
                id: gesture
                anchors.fill: parent
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

                // osu Notification.OnClick parity: body left click activates
                // then Close(false) — quick fade; right click runs the fling.
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        root.requestClose(true)
                    else if (mouse.button === Qt.LeftButton)
                        root.requestClose(false)
                }
            }

            // Content stack above the gesture catcher: header row, summary
            // title, muted body, then the action button row when present.
            Column {
                id: contentColumn
                anchors.left: iconStrip.right
                anchors.right: closeButton.left
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 4

                // App identity line above the payload.
                Text {
                    visible: root.appName.length > 0
                    width: parent.width
                    text: root.appName
                    color: LazerTheme.textMuted
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                // Summary as the card title.
                Text {
                    visible: root.summary.length > 0
                    width: parent.width
                    text: root.summary
                    color: LazerTheme.textPrimary
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                // Body copy stays one step quieter than the title.
                Text {
                    visible: root.body.length > 0
                    width: parent.width
                    text: root.body
                    color: LazerTheme.textMuted
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                }

                // D-Bus action buttons as sharp detail-level chips.
                Row {
                    visible: root.actionList.length > 0
                    spacing: 6
                    topPadding: 4

                    Repeater {
                        model: root.actionList

                        Rectangle {
                            id: actionButton
                            required property var modelData
                            readonly property bool hovered: actionMouse.containsMouse

                            height: 26
                            // Size to the label plus symmetric chip padding.
                            width: actionLabel.implicitWidth + 20
                            radius: 4
                            color: hovered ? LazerTheme.hoverFill : LazerTheme.pressedFill
                            scale: actionMouse.pressed && !root.reducedMotion ? MotionTokens.pressScale : 1

                            Behavior on scale { NumberAnimation { duration: root.reducedMotion ? 0 : MotionTokens.fast; easing.type: Easing.OutQuint } }

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: actionButton.modelData.text
                                color: actionButton.hovered ? LazerTheme.textPrimary : LazerTheme.textMuted
                                font.pixelSize: 12
                                font.weight: Font.Medium

                                Behavior on color { ColorAnimation { duration: root.reducedMotion ? 0 : MotionTokens.fast } }
                            }

                            // Shared click-flash recipe from the settings authority.
                            Rectangle {
                                id: actionFlash
                                anchors.fill: parent
                                radius: parent.radius
                                color: LazerTheme.textPrimary
                                opacity: 0
                            }

                            NumberAnimation {
                                id: actionFlashAnim
                                target: actionFlash
                                property: "opacity"
                                from: MotionTokens.clickFlashOpacity
                                to: 0
                                duration: MotionTokens.clickFlashDuration
                                easing.type: MotionTokens.clickFlashEasing
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (!root.reducedMotion)
                                        actionFlashAnim.restart()
                                    root.actionRequested(actionButton.modelData.identifier)
                                    root.requestClose(false)
                                }
                            }
                        }
                    }
                }
            }

            // Close button: 28px column, black@0.15 hover background,
            // muted check turning white on hover.
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

                    Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : MotionTokens.fast; easing.type: Easing.OutQuint } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u2713"
                    color: closeButtonMouse.containsMouse ? LazerTheme.textPrimary : LazerTheme.textMuted
                    font.pixelSize: 12

                    Behavior on color { ColorAnimation { duration: root.reducedMotion ? 0 : MotionTokens.fast } }
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
