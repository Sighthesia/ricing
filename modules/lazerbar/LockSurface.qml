pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import "../../services" as Services
import "WaveSurfaceLogic.js" as Waves

// One per-screen lock surface wearing the launcher's wave-panel language,
// choreographed in three readable phases: pink waves flood in and settle,
// the sharp body slides up over them, then the waves fade away underneath.
// An opaque floor stays painted underneath every frame — a session-lock
// surface must never reveal the desktop while locked. The lock releases
// only after the exit animation finishes, via LockService.finishUnlock().
WlSessionLockSurface {
    id: root

    required property WlSessionLock lock

    color: "transparent"

    // Reveal progresses drive the phased sweep: backdrop waves lead, the
    // body follows once they have settled, and waveFade retires them under
    // the covering panel.
    property real waveProgress: MotionTokens.reducedMotion ? 1 : 0
    property real bodyProgress: MotionTokens.reducedMotion ? 1 : 0
    property real waveFade: MotionTokens.reducedMotion ? 0 : 1
    property bool revealStarted: false
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

    function resetRevealState() {
        revealStarted = false
        revealDelay.stop()
        enterSequence.stop()
        exitSequence.stop()
        floorFade.stop()
        root.waveProgress = 0
        root.bodyProgress = 0
        root.waveFade = 1
        securityFloor.opacity = 1
    }

    function armReveal() {
        if (revealStarted || !Services.LockService.locked)
            return
        if (MotionTokens.reducedMotion) {
            revealStarted = true
            root.waveProgress = 1
            root.bodyProgress = 1
            root.waveFade = 0
            return
        }
        // Grace delay: niri maps the committed lock surface slightly after
        // the client-side window reports visible, so give the floor a beat
        // on screen before the sweep begins.
        revealDelay.restart()
    }

    // Play the exit reveal once PAM accepted the password.
    Connections {
        target: Services.LockService
        function onLockedChanged() {
            if (Services.LockService.locked) {
                resetRevealState()
                armReveal()
            }
        }

        function onUnlockRequested() {
            revealDelay.stop()
            revealStarted = true
            enterSequence.stop()
            exitSequence.restart()
        }
        function onFailed() { failureShake.restart() }
    }

    Component.onCompleted: armReveal()

    Timer {
        id: revealDelay
        interval: 250
        running: false
        repeat: false
        onTriggered: {
            if (root.revealStarted || !Services.LockService.locked)
                return
            root.revealStarted = true
            enterSequence.restart()
        }
    }

    // Phase 1: waves flood in and settle. Phase 2: the body slides up over
    // the settled waves while they retire underneath it. Sequenced rather
    // than parallel so each phase reads on screen — parallel timings let the
    // fast-starting body swallow the whole sweep within ~300ms.
    SequentialAnimation {
        id: enterSequence
        running: false

        NumberAnimation {
            target: root
            property: "waveProgress"
            to: 1
            duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveBackdropEnter
            easing.type: Easing.OutQuad
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "bodyProgress"
                to: 1
                duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveEnter
                easing.type: Easing.BezierSpline
                easing.bezierCurve: MotionTokens.outSoft
            }
            NumberAnimation {
                target: root
                property: "waveFade"
                to: 0
                duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.settingsSidebarFade
                easing.type: Easing.InQuad
            }
        }
    }

    // Retreat the panel first (waves re-emerge as waveFade returns), then
    // pull the waves back down, then fade the floor so the desktop reappears
    // through the transparent surface before the lock actually drops.
    SequentialAnimation {
        id: exitSequence
        running: false

        ParallelAnimation {
            NumberAnimation { target: root; property: "bodyProgress"; to: 0; duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveEnter; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "waveFade"; to: 1; duration: MotionTokens.fast }
        }
        NumberAnimation { target: root; property: "waveProgress"; to: 0; duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveExit; easing.type: Easing.InSine }
        ScriptAction { script: floorFade.restart() }
    }
    NumberAnimation {
        id: floorFade
        target: securityFloor
        property: "opacity"
        to: 0
        duration: MotionTokens.slow
        easing.type: Easing.InCubic
        onFinished: {
            Services.LockService.finishUnlock()
            root.lock.locked = false
        }
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

    // Security floor: opaque from the first committed frame so no desktop
    // pixels ever leak while the session is locked.
    Rectangle {
        id: securityFloor
        anchors.fill: parent
        // Keep the protocol-safe floor behind the animated lock content.
        z: -1
        // Keep the protocol-safe first frame in the same visual family as the sweep.
        color: root.lockPalette.light4
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
        anchors.fill: parent
        clip: true

        // Four fixed wave layers, statically declared: Repeater delegates do
        // not render reliably inside a WlSessionLockSurface. Each rides above
        // the body (z:10); waveFade retires them once the body covers them.
        RepeaterlessWaveHost {}
    }

    // Static four-layer backdrop + sliding body, grouped so the wave
    // fade-out multiplier applies to the whole backdrop set.
    component RepeaterlessWaveHost: Item {
        anchors.fill: parent

        FullscreenWave {
            anchors.fill: parent
            z: 10
            opacity: root.waveFade
            progress: root.waveProgress
            angle: Waves.waveAngle(0)
            colour: root.lockPalette.light4
            restOffset: -parent.height * 0.72
        }
        FullscreenWave {
            anchors.fill: parent
            z: 10
            opacity: root.waveFade
            progress: root.waveProgress
            angle: Waves.waveAngle(1)
            colour: root.lockPalette.light3
            restOffset: -parent.height * 0.5
        }
        FullscreenWave {
            anchors.fill: parent
            z: 10
            opacity: root.waveFade
            progress: root.waveProgress
            angle: Waves.waveAngle(2)
            colour: root.lockPalette.dark4
            restOffset: -parent.height * 0.32
        }
        FullscreenWave {
            anchors.fill: parent
            z: 10
            opacity: root.waveFade
            progress: root.waveProgress
            angle: Waves.waveAngle(3)
            colour: root.lockPalette.dark3
            restOffset: -parent.height * 0.16
        }

        // Sharp body carrying the credential UI; slides up over the waves.
        Rectangle {
            id: body
            z: 5
            anchors.top: parent.top
            x: 0
            y: MotionTokens.reducedMotion ? 0 : parent.height * (1 - root.bodyProgress)
            width: parent.width
            height: parent.height
            radius: 0
            color: LazerTheme.settingsPanel

            Column {
                id: contentColumn
                spacing: 28
                anchors.centerIn: parent
                // Shake rides a Translate so the centering anchor stays authoritative.
                transform: Translate { id: shakeOffset }

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
                            passwordCharacter: "\u25CF"
                            font.pixelSize: 18
                            color: LazerTheme.textPrimary
                            verticalAlignment: TextInput.AlignVCenter
                            focus: true
                            enabled: !Services.LockService.unlockInProgress
                            // Shared buffer keeps every per-screen surface in sync.
                            // Sync is imperative: typing breaks a `text` binding, so
                            // service changes are mirrored through the signal guard.
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
