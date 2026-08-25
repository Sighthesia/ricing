pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import "../../services" as Services

// One per-screen lock surface: blurred wallpaper under an osu-dark scrim,
// a centered clock and sharp password bar, and the unlock exit animation.
// The session stays locked until the exit animation finishes; only then does
// the surface hand control back to LockService.finishUnlock().
WlSessionLockSurface {
    id: root

    color: "transparent"

    readonly property string username: Quickshell.env("USER") || "user"
    property bool shakeFailed: false
    readonly property string statusText: {
        if (Services.LockService.unlockInProgress)
            return "正在验证..."
        if (Services.LockService.failureState === "maxTries")
            return "尝试次数过多，请稍后再试"
        if (Services.LockService.failureState === "failed" || Services.LockService.failureState === "error")
            return "密码错误，请重试"
        return "输入密码解锁"
    }
    readonly property color statusColor: Services.LockService.failureState === "none"
            && !Services.LockService.unlockInProgress ? LazerTheme.textMuted : LazerTheme.osuButtonActive

    // Play the exit reveal once PAM accepted the password.
    Connections {
        target: Services.LockService
        function onUnlockRequested() { exitAnimation.restart() }
        function onFailed() { failureShake.restart() }
    }

    SequentialAnimation {
        id: failureShake
        running: false
        NumberAnimation { target: shakeOffset; property: "x"; from: 0; to: -10; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeOffset; property: "x"; from: -10; to: 10; duration: 90; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeOffset; property: "x"; from: 10; to: -6; duration: 80; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeOffset; property: "x"; from: -6; to: 0; duration: 70; easing.type: Easing.OutQuad }
        ScriptAction { script: Services.LockService.clearBuffer() }
    }

    SequentialAnimation {
        id: enterAnimation
        running: !MotionTokens.reducedMotion
        ParallelAnimation {
            NumberAnimation { target: backgroundLayer; property: "opacity"; from: 0; to: 1; duration: MotionTokens.page; easing.type: Easing.OutCubic }
            NumberAnimation { target: contentColumn; property: "opacity"; from: 0; to: 1; duration: MotionTokens.page; easing.type: Easing.OutCubic }
            NumberAnimation { target: contentColumn; property: "y"; from: 24; to: 0; duration: MotionTokens.page; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft }
        }
    }

    // Fade everything away, then release the lock as the very last step so the
    // compositor never paints its fallback screen over a live surface.
    SequentialAnimation {
        id: exitAnimation
        ParallelAnimation {
            NumberAnimation { target: contentColumn; property: "opacity"; to: 0; duration: MotionTokens.slow; easing.type: Easing.InQuad }
            NumberAnimation { target: backgroundLayer; property: "opacity"; to: 0; duration: MotionTokens.settingsSlide; easing.type: Easing.InCubic }
        }
        ScriptAction { script: Services.LockService.finishUnlock() }
    }

    // Blurred wallpaper behind a dark scrim; theme floor keeps it readable
    // when no wallpaper is configured.
    Item {
        id: backgroundLayer
        anchors.fill: parent
        opacity: MotionTokens.reducedMotion ? 1 : 0

        Rectangle {
            anchors.fill: parent
            color: LazerTheme.bgDark
        }

        Image {
            id: wallpaperImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: Services.WallpaperService.currentWallpaper
            visible: status === Image.Ready
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: 48
            blurMultiplier: 0.8
            autoPaddingEnabled: false
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(LazerTheme.bgDark, MotionTokens.backdropOpacity + 0.15)
        }
    }

    // Keyboard owner: WlSessionLockSurface is not an Item, so all key routing
    // lands on this focused inner item.
    Item {
        id: keyboardScope
        focus: true
        Keys.onReturnPressed: Services.LockService.tryUnlock()
        Keys.onEnterPressed: Services.LockService.tryUnlock()
    }

    Column {
        id: contentColumn
        spacing: 28
        anchors.centerIn: parent
        opacity: MotionTokens.reducedMotion ? 1 : 0
        // Shake rides a Translate so the centering anchor stays authoritative.
        transform: Translate { id: shakeOffset }

        // Clock block above the credential bar.
        Column {
            width: parent.width
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                property date now: new Date()
                text: Qt.formatDateTime(now, "HH:mm")
                color: LazerTheme.textPrimary
                font.pixelSize: 72
                font.bold: true

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: parent.now = new Date()
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                property date now: new Date()
                text: Qt.formatDateTime(now, "yyyy年M月d日 dddd")
                color: LazerTheme.textMuted
                font.pixelSize: 16

                Timer {
                    interval: 30000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: parent.now = new Date()
                }
            }
        }

        // Sharp credential bar: right-angled osu surface with the shared
        // password buffer and a submit action on the right edge.
        Rectangle {
            id: passwordBar
            width: 360
            height: 52
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 0
            color: LazerTheme.settingsControlSurface
            border.width: 1
            border.color: Services.LockService.failureState === "none"
                    && !Services.LockService.unlockInProgress ? LazerTheme.divider : LazerTheme.osuButtonActive

            Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 6

                OsuTextField {
                    id: passwordField
                    width: parent.width - LazerTheme.targetSize - 12
                    height: parent.height
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    font.pixelSize: 18
                    color: LazerTheme.textPrimary
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    enabled: !Services.LockService.unlockInProgress
                    // Shared buffer keeps every per-screen surface in sync.
                    // Sync is imperative: typing breaks a `text` binding, so
                    // service changes are mirrored through the signal guard
                    // instead, and both directions ignore equal writes.
                    Component.onCompleted: {
                        text = Services.LockService.buffer
                        forceActiveFocus()
                    }
                    onTextChanged: if (text !== Services.LockService.buffer) Services.LockService.setBuffer(text)
                    Connections {
                        target: Services.LockService
                        function onBufferChanged() {
                            if (passwordField.text !== Services.LockService.buffer)
                                passwordField.text = Services.LockService.buffer
                        }
                    }
                    Keys.onReturnPressed: Services.LockService.tryUnlock()
                    Keys.onEnterPressed: Services.LockService.tryUnlock()
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "icons/chevron-right.svg"
                    accessibleName: "解锁"
                    enabled: !Services.LockService.unlockInProgress
                    supportsHover: false
                    onClicked: Services.LockService.tryUnlock()
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.statusText
            color: root.statusColor
            font.pixelSize: 13

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }
    }
}
