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
    // D-Bus icon entries may be theme names rather than paths; unresolved
    // names fall back to the generic executable icon like WindowHintService.
    readonly property string resolvedIcon: {
        const src = root.iconSource
        if (src === "" || src.indexOf("/") === 0 || src.indexOf(":") >= 0)
            return src
        return Quickshell.iconPath(src, "application-x-executable")
    }
    property bool openState: false
    property bool closing: false
    readonly property bool reducedMotion: MotionTokens.reducedMotion
    // The shell's single glow pulse, injected by the host. The card is not a
    // separate glow: a notification arriving is simply this pulse triggered,
    // and the card reveals the slice of that one ring which crosses it.
    property var glowPulse: null
    // Master switch for the pulse on this surface.
    property bool glowEnabled: true
    // The output the ring is defined against, so the card masks the same ring
    // the bar shows rather than fitting one to its own box, and where the stack
    // this card sits in stands on it.
    property real glowScreenWidth: 0
    property real glowScreenHeight: 0
    // A card is never asked to map itself. `mapToGlobal` is a call rather than a
    // dependency, so a binding over it in a freshly created delegate keeps
    // whatever it first computed — and answering 0 threw the shared ring a whole
    // card's width away from the card, which is how a later notification could
    // sit inside the ring's path and still show nothing. The stack states where
    // it stands and the card adds its own position to it.
    property real glowStackScreenX: 0
    property real glowStackScreenY: 0
    readonly property real glowSelfScreenX: glowStackScreenX + x
    readonly property real glowSelfScreenY: glowStackScreenY + y
    // True while the card is actually showing the pulse — `visible`, not just
    // the shared clock, so a card that filtered itself out cannot report a
    // glow it never painted.
    readonly property bool glowPlaying: entryGlow.visible
    // Where the ring starts inside this card, and how big it is against the
    // screen. Diagnostics for the glow host: the ring's own item is internal, so
    // these are the only way a harness can assert the ring actually lands on
    // the card instead of a screen's width away from it.
    readonly property real glowOriginX: entryGlow.originX
    readonly property real glowOriginY: entryGlow.originY
    readonly property real glowCover: entryGlow.cover
    // The ring's current radius inside this card. Diagnostics for the glow
    // host: a card is only lit while the ring is small enough to still be
    // inside it, and how long that is decides whether the pass reads at all.
    readonly property real glowRadius: entryGlow.radius
    signal dismissRequested
    signal actionRequested(string identifier)

    // Speech-bubble placeholder: rounded body plus an angled tail, tinted by
    // bubbleColor so the top-band clip can reuse it with the darker green.
    Component {
        id: bubbleIcon

        Item {
            property color bubbleColor: "#B3D944"
            width: 22
            height: 20

            Rectangle {
                id: bubbleBody
                width: parent.width
                height: 15
                radius: 4
                color: bubbleColor
            }

            Canvas {
                anchors.top: bubbleBody.bottom
                x: 4
                width: 8
                height: 5
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = String(bubbleColor)
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.lineTo(width, 0)
                    ctx.lineTo(1.5, height)
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }
    }

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
        // Deferred one turn: the delegate's width/height come from ListView
        // bindings that only resolve during the first layout pass, and the glow
        // pulse needs real geometry to size its ring.
        Qt.callLater(function() {
            root.openState = true
            // A notification arriving *is* the glow pulse being triggered, and
            // it is untagged: the popup model is shared, so every output shows
            // this card and every bar is meant to answer the same event. The
            // origin is this card's entry edge in screen coordinates, so the
            // ring starts where the card flew in from and every surface shows
            // that one ring.
            if (root.glowPulse) {
                const origin = root.entryOriginOnScreen()
                root.glowPulse.trigger("", origin.x, origin.y)
            }
        })
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

    // Where the card's entry edge sits on the output, in screen coordinates.
    // The card slides in from its own right edge, so that is the point the ring
    // starts from. Derived from `glowSelfScreenX` rather than a second
    // `mapToGlobal`, so the published origin and the card's own position can
    // never come from two disagreeing reads.
    function entryOriginOnScreen() {
        return { x: root.glowSelfScreenX + root.width,
                 y: root.glowSelfScreenY + root.height / 2 }
    }

    // Play the osu fling: random leftward impulse, integrate gravity per
    // frame, fade out on the In curve, then release the model entry.
    function requestClose(runFling) {
        if (root.closing)
            return

        root.closing = true
        gesture.enabled = false
        closeButtonMouse.enabled = false
        // A plain click releases into springBack before onClicked fires; stop
        // it so the fling integrates from rest exactly like the close button.
        springBack.stop()

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
                    id: placeholderItem
                    anchors.centerIn: parent
                    visible: root.resolvedIcon === ""
                    // Matches bubbleIcon so centering and the top-band clip
                    // have real geometry to work with.
                    width: 22
                    height: 20

                    // Message-bubble placeholder drawn from primitives so it
                    // renders regardless of the installed icon theme.
                    Loader {
                        anchors.fill: parent
                        sourceComponent: bubbleIcon
                    }

                    // Top band carries the gradient's darker green.
                    Item {
                        width: parent.width
                        height: Math.ceil(parent.height / 2)
                        clip: true

                        Loader {
                            anchors.fill: parent
                            sourceComponent: bubbleIcon
                            onLoaded: item.bubbleColor = "#668800"
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

                // Body click triggers the parabolic fling exit effect.
                onClicked: _ => {
                    root.requestClose(true)
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
                                    root.requestClose(true)
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
                    text: "\u2715"
                    color: closeButtonMouse.containsMouse ? LazerTheme.textPrimary : LazerTheme.textMuted
                    font.pixelSize: 14

                    Behavior on color { ColorAnimation { duration: root.reducedMotion ? 0 : MotionTokens.fast } }
                }

                MouseArea {
                    id: closeButtonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.requestClose(true)
                }
            }

            // Entry flash from osu LoadComplete: the whole card (icon and
            // text included) takes the luminous primary tint for a beat
            // while it slides in, then releases.
            Rectangle {
                id: flash
                anchors.fill: parent
                radius: root.cardRadius
                color: LazerTheme.notificationFlash
                opacity: 0

                NumberAnimation {
                    id: flashFade
                    target: flash
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: root.reducedMotion ? 0 : 2000
                    easing.type: Easing.OutQuart
                }
            }

            // The shell's glow pulse, hosted on the card: the same heavy ring
            // and its two soft bands the bar plays, clipped to the card instead
            // of the display. Inset by the corner radius so the rectangular
            // clip cannot spill past the rounded corners onto the desktop.
            //
            // Painted above the entry flash on purpose: the flash is an opaque
            // wash for its first beat, and a ring underneath it spends the
            // whole sweep hidden under the very glow it belongs to.
            RippleGlow {
                id: entryGlow
                anchors.fill: parent
                anchors.margins: root.cardRadius
                pulse: root.glowPulse
                glowEnabled: root.glowEnabled
                screenWidth: root.glowScreenWidth
                screenHeight: root.glowScreenHeight
                // The glow is inset by the card radius on every side, so it
                // starts that far inside the card's own place on the output.
                hostScreenX: root.glowSelfScreenX + root.cardRadius
                hostScreenY: root.glowSelfScreenY + root.cardRadius
            }
        }
    }
}
