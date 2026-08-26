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

    // Reveal arming: Quickshell keeps session-lock surfaces alive across
    // unlock/lock cycles, so the choreography must re-arm on every show and
    // reset on every hide instead of running once at object creation.
    property bool revealStarted: false

    function armReveal() {
        if (revealStarted)
            return
        if (MotionTokens.reducedMotion) {
            revealStarted = true
            root.waveProgress = 1
            root.bodyProgress = 1
            return
        }
        // Grace delay: niri maps the committed lock surface slightly after
        // the client-side window reports visible, so give the floor a beat
        // on screen before the sweep begins.
        revealDelay.restart()
    }

    // Belt-and-braces arming: visibleChanged covers reuse across locks;
    // completion covers creations where visible is already true up front.
    Component.onCompleted: armReveal()

    onVisibleChanged: {
        if (!visible) {
            revealStarted = false
            revealDelay.stop()
            openBody.stop()
            openWaves.stop()
            root.waveProgress = 0
            root.bodyProgress = 0
            return
        }
        armReveal()
    }

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




    // [DBG-grab] temporary frame captures of the rendered surface
    function dbgGrab(ms) {
        clippedViewport.grabToImage(function(r) {
            r.image.save("/tmp/opencode/lockframes/f" + ms + "ms.png")
            console.warn("[DBG-grab] saved f" + ms + "ms wave=" + root.waveProgress.toFixed(2) + " body=" + root.bodyProgress.toFixed(2))
        })
    }
    Timer { interval: 100;  running: root.visible; onTriggered: root.dbgGrab(100) }
    Timer { interval: 400;  running: root.visible; onTriggered: root.dbgGrab(400) }
    Timer { interval: 800;  running: root.visible; onTriggered: root.dbgGrab(800) }
    Timer { interval: 1500; running: root.visible; onTriggered: root.dbgGrab(1500) }
    Timer { interval: 3000; running: root.visible; onTriggered: root.dbgGrab(3000) }

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

    // [MINIMAL] bisect build: plain nodes only
    Rectangle {
        id: securityFloor
        anchors.fill: parent
        color: "#2244FF"

        Text {
            anchors.centerIn: parent
            text: "MINIMAL " + Math.round(root.waveProgress * 100) + "/" + Math.round(root.bodyProgress * 100)
            color: "white"
            font.pixelSize: 40
        }

        FullscreenWave {
            anchors.fill: parent
            progress: root.waveProgress
            angle: Waves.waveAngle(0)
            colour: "#FF00FF"
            restOffset: -parent.height * 0.72
        }
        FullscreenWave {
            anchors.fill: parent
            progress: root.waveProgress
            angle: Waves.waveAngle(1)
            colour: "#00FFAA"
            restOffset: -parent.height * 0.5
        }

        // [BISECT-R1] credential bar under test
        Item {
            id: keyboardScope
            focus: true
            Keys.onReturnPressed: Services.LockService.tryUnlock()
            Keys.onEnterPressed: Services.LockService.tryUnlock()
        }

        Rectangle {
            width: 360
            height: 52
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 80
            radius: 0
            color: LazerTheme.settingsControlSurface

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
                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: if (text !== Services.LockService.buffer) Services.LockService.setBuffer(text)
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "icons/chevron-right.svg"
                    accessibleName: "解锁"
                    supportsHover: false
                    onClicked: Services.LockService.tryUnlock()
                }
            }
        }

        Timer { interval: 100; running: true; repeat: true; property int n: 0
            onTriggered: { n++; if (n <= 12) console.warn("[DBG-min] wp=" + root.waveProgress.toFixed(2) + " bp=" + root.bodyProgress.toFixed(2)) }
        }
    }
}
