pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import "../../services" as Services
import "WaveSurfaceLogic.js" as Waves

// One per-screen lock surface wearing the launcher's wave-panel language:
// four angled FullscreenWave layers sweep in ahead of a full-width sharp
// body that covers everything below the bar, mirroring WaveSurfaceHost's
// timing contracts. An opaque floor stays painted underneath every frame —
// a session-lock surface must never reveal the desktop while locked. The
// lock releases only after the exit animation finishes, via
// LockService.finishUnlock().
WlSessionLockSurface {
    id: root

    color: "transparent"

    // Reveal progresses drive the same dual-track sweep as the launcher:
    // backdrop waves lead, the body slides over them.
    property real waveProgress: MotionTokens.reducedMotion ? 1 : 0
    property real bodyProgress: MotionTokens.reducedMotion ? 1 : 0
    // Leave the bar's strip uncovered so the lock reads as a full-width
    // panel docked against it, matching the launcher window geometry.
    readonly property bool barOnTop: Services.SettingsService.bar.position !== "bottom"
    readonly property int barEdgeInset:
        (Services.SettingsService.bar.floating
            ? Math.max(0, Math.min(24, Number(Services.SettingsService.bar.floatingMargin) || 0)) : 0)
        + Math.max(40, Math.min(64, Number(Services.SettingsService.bar.height) || 48))
    readonly property var lockPalette: ({
        light4: "#F492B8",
        light3: "#E56E97",
        dark4: "#AC3F63",
        dark3: "#75293F"
    })
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
        function onUnlockRequested() {
            revealDelay.stop()
            revealStarted = true
            openBody.stop()
            openWaves.stop()
            exitAnimation.restart()
        }
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

    // Same contracts as the launcher surface: waves lead the body so they
    // stay visible while content slides over them. They must not start at
    // object creation: session-lock mapping lags instantiation, so the
    // timeline would burn down before the first frame is ever shown.
    NumberAnimation {
        id: openBody
        target: root
        property: "bodyProgress"
        to: 1
        duration: MotionTokens.waveEnter
        easing.type: Easing.OutQuint
    }
    NumberAnimation {
        id: openWaves
        target: root
        property: "waveProgress"
        to: 1
        duration: MotionTokens.waveBackdropEnter
        easing.type: Easing.OutQuad
    }

    // Start the reveal after a short grace delay. Client-side signals cannot
    // tell us what the compositor has shown: frames swap into buffers before
    // the session-lock commit is displayed, so both object creation and
    // frameSwapped fire while the screen still shows nothing. Niri maps lock
    // surfaces well under this delay, guaranteeing the floor is on screen
    // before the sweep begins.
    property bool revealStarted: false
    Timer {
        id: revealDelay
        interval: 250
        running: false
        repeat: false
        onTriggered: {
            if (root.revealStarted)
                return
            root.revealStarted = true
            openWaves.restart()
            openBody.restart()
        }
    }
    Component.onCompleted: {
        if (MotionTokens.reducedMotion) {
            root.waveProgress = 1
            root.bodyProgress = 1
        } else {
            revealDelay.restart()
        }
    }

    // Retreat the panel first, then fade the floor so the desktop reappears
    // through the transparent surface before the lock actually drops.
    SequentialAnimation {
        id: exitAnimation
        ParallelAnimation {
            NumberAnimation { target: root; property: "bodyProgress"; to: 0; duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveExit; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "waveProgress"; to: 0; duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveExit; easing.type: Easing.InSine }
        }
        ScriptAction { script: floorFade.restart() }
    }
    NumberAnimation {
        id: floorFade
        target: securityFloor
        property: "opacity"
        to: 0
        duration: MotionTokens.slow
        easing.type: Easing.InCubic
        onFinished: Services.LockService.finishUnlock()
    }

    // Security floor: opaque from the first committed frame so no desktop
    // pixels ever leak while the session is locked.
    Rectangle {
        id: securityFloor
        anchors.fill: parent
        color: LazerTheme.bgDark
    }

    // Keyboard owner: WlSessionLockSurface is not an Item, so all key routing
    // lands on this focused inner item.
    Item {
        id: keyboardScope
        focus: true
        Keys.onReturnPressed: Services.LockService.tryUnlock()
        Keys.onEnterPressed: Services.LockService.tryUnlock()
    }

    // Full-width wave-panel viewport docked against the bar edge.
    Item {
        id: clippedViewport
        x: 0
        width: root.width
        y: root.barOnTop ? root.barEdgeInset : 0
        height: Math.max(0, root.height - root.barEdgeInset)
        clip: true

        Repeater {
            model: 4
            delegate: FullscreenWave {
                required property int index
                anchors.fill: parent
                progress: root.waveProgress
                angle: Waves.waveAngle(index)
                colour: index === 0 ? root.lockPalette.light4
                        : index === 1 ? root.lockPalette.light3
                        : index === 2 ? root.lockPalette.dark4
                        : root.lockPalette.dark3
                restOffset: -parent.height * [0.72, 0.5, 0.32, 0.16][index]
            }
        }

        // Sharp body carrying the credential UI; slides up over the waves.
        Rectangle {
            id: body
            z: 5
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: 0
            y: MotionTokens.reducedMotion ? 0 : parent.height * (1 - root.bodyProgress)
            width: parent.width
            radius: 0
            color: LazerTheme.settingsPanel

            Column {
                id: contentColumn
                spacing: 28
                anchors.centerIn: parent
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
    }
}
