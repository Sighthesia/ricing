import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "../lazerbar" as Lazer
import "./LockLogic.js" as LockLogic
import "./LockSurfaceLogic.js" as SurfaceLogic

// Own one compositor-enforced full-screen session-lock surface.
WlSessionLockSurface {
    id: root

    property var lockContext: null
    property var snapshot: null
    // This surface's slot in the shared per-screen snapshot data; the shared
    // snapshot never decides which screen a surface belongs to.
    readonly property int screenIndex: SurfaceLogic.screenSlot(Quickshell.screens, root.screen)
    readonly property string snapshotUrl: snapshot && screenIndex >= 0
            ? snapshot.snapshotUrlFor(screenIndex) : ""
    property string wallpaperPath: ""
    property real waveProgress: 0
    property real authOpacity: 0
    property bool reducedMotion: Lazer.MotionTokens.reducedMotion
    property bool exitStarted: false
    property bool releaseSent: false
    property int revealWaitTicks: 0

    signal releaseRequested()

    // The surface starts opaque with the pre-lock screenshot: the desktop
    // appears uninterrupted until the wave mask sweeps the wallpaper over it.
    color: "transparent"

    function startReveal(): void {
        exitStarted = false
        releaseSent = false
        if (reducedMotion) {
            SurfaceLogic.applyRevealImmediately(root, allAnimations())
            return
        }
        SurfaceLogic.stopAll(allAnimations())
        revealWaitTicks = 0
        revealStartTimer.restart()
    }

    function startExit(): void {
        if (exitStarted)
            return
        exitStarted = true
        if (reducedMotion) {
            SurfaceLogic.applyExitImmediately(root, allAnimations())
            requestRelease()
            return
        }
        authOpacity = 0
        SurfaceLogic.stopAll(allAnimations())
        exitAnimation.from = waveProgress
        exitAnimation.start()
    }

    function requestRelease(): void {
        if (releaseSent || !LockLogic.shouldReleaseLock("exiting", true))
            return
        releaseSent = true
        releaseRequested()
    }

    function allAnimations(): var {
        return [enterAnimation, exitAnimation]
    }

    onLockContextChanged: {
        if (lockContext)
            contextConnections.target = lockContext
    }

    Component.onCompleted: {
        startReveal()
        keyboardOwner.forceActiveFocus()
    }

    // Base layer, painted before anything animates: the pre-lock desktop
    // capture over an opaque floor, so the surface never exposes the desktop.
    Rectangle {
        id: baseFloor
        anchors.fill: parent
        color: Lazer.LazerTheme.bgDark
    }

    Image {
        id: baseImage
        anchors.fill: parent
        source: SurfaceLogic.baseSource(root.snapshotUrl)
        visible: status === Image.Ready && source !== ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Ready)
                revealStartTimer.restart()
        }
    }

    // Keep the screenshot visible for at least one settled frame before the
    // mask starts. If capture fails, the opaque floor still starts the reveal
    // after a bounded wait rather than exposing the wallpaper immediately.
    Timer {
        id: revealStartTimer
        interval: root.snapshotUrl !== "" && baseImage.status !== Image.Ready ? 250 : 0
        repeat: false
        onTriggered: {
            if (root.snapshotUrl !== "" && baseImage.status !== Image.Ready
                    && root.revealWaitTicks < 12) {
                root.revealWaitTicks += 1
                restart()
                return
            }
            enterAnimation.start()
        }
    }

    // Wave mask: four angled bands, rendered offscreen in white. Wherever a
    // band has swept, the mask lets the wallpaper layer through; the bands'
    // opacity ramp gives the reveal a soft leading edge.
    Item {
        id: waveMask
        anchors.fill: parent

        Lazer.WaveRevealLayers {
            anchors.fill: parent
            progress: root.waveProgress
            palette: ({
                light4: "#FFFFFFFF",
                light3: "#FFFFFFFF",
                dark4: "#FFFFFFFF",
                dark3: "#FFFFFFFF"
            })
        }
    }

    // Keep keyboard ownership independent of the animated auth card. The
    // session-lock surface must accept password input even while the card is
    // still fading in or when the background image is unavailable.
    Item {
        id: keyboardOwner
        anchors.fill: parent
        focus: true
        z: 4

        Keys.onPressed: event => {
            if (!root.lockContext)
                return
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.lockContext.submit()
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                root.lockContext.currentText = root.lockContext.currentText.slice(0, -1)
                event.accepted = true
            } else if (event.text && event.text.length === 1) {
                root.lockContext.currentText += event.text
                event.accepted = true
            }
        }
    }

    ShaderEffectSource {
        id: waveMaskTexture
        anchors.fill: parent
        sourceItem: waveMask
        hideSource: true
        live: true
    }

    // Reveal layer: the wallpaper, masked by the sweeping wave, laid over the
    // screenshot base. Without a configured wallpaper the settled bands still
    // read as the themed panel surface.
    Item {
        id: revealLayer
        z: 1
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: waveMaskTexture
        }

        Rectangle {
            anchors.fill: parent
            visible: revealImage.status !== Image.Ready || revealImage.source === ""
            color: Lazer.LazerTheme.settingsPanel
        }

        Image {
            id: revealImage
            anchors.fill: parent
            source: SurfaceLogic.revealSource(root.wallpaperPath)
            visible: status === Image.Ready && source !== ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        // Dim the wallpaper for password legibility.
        Rectangle {
            anchors.fill: parent
            visible: revealImage.visible
            color: Lazer.LazerTheme.bgDark
            opacity: 0.35
        }
    }

    // Keep authentication content rectangular and above the reveal layers.
    Rectangle {
        id: authSurface
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.82, 420)
        height: Math.min(parent.height * 0.48, 260)
        color: Lazer.LazerTheme.settingsPanel
        opacity: root.authOpacity
        z: 3

        // Mirror the shared password conversation: masked input plus an
        // outcome line, driven entirely by LockContext state.
        Column {
            id: authContent
            anchors.centerIn: parent
            spacing: 10
            width: parent.width - 48

            // Name the field so the masked line reads as a password.
            Text {
                width: parent.width
                text: "PASSWORD"
                color: Lazer.LazerTheme.textMuted
                font.pixelSize: 11
                font.letterSpacing: 2
            }

            // Hold the masked line at a fixed height so the layout never
            // jumps between empty and filled buffers.
            Item {
                id: maskSlot
                width: parent.width
                height: 30

                // Render bullets only; the password never becomes visible.
                Text {
                    id: maskText
                    anchors.verticalCenter: parent.verticalCenter
                    text: SurfaceLogic.maskedPassword(
                              root.lockContext ? root.lockContext.currentText : "")
                    visible: text.length > 0
                    color: Lazer.LazerTheme.textPrimary
                    font.pixelSize: 20
                    font.letterSpacing: 4
                }

                // Keep an empty buffer visibly alive instead of a blank slot.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: maskText.text.length === 0
                    text: "Enter password"
                    color: Lazer.LazerTheme.textMuted
                    font.pixelSize: 15
                    font.italic: true
                }
            }

            // Report verifying/failed outcomes, with a spoken default when
            // PAM returns an empty message.
            Text {
                id: statusText
                width: parent.width
                text: SurfaceLogic.authStatus(
                          root.lockContext ? root.lockContext.unlockInProgress : false,
                          root.lockContext ? root.lockContext.showFailure : false,
                          root.lockContext ? root.lockContext.errorMessage : "").message
                visible: text.length > 0
                color: SurfaceLogic.authStatus(
                           root.lockContext ? root.lockContext.unlockInProgress : false,
                           root.lockContext ? root.lockContext.showFailure : false,
                           root.lockContext ? root.lockContext.errorMessage : "").tone
                       === SurfaceLogic.authTones.failure
                       ? Lazer.LazerTheme.osuPink : Lazer.LazerTheme.textMuted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }

            // State the keys so the surface is usable without prior knowledge.
            Text {
                width: parent.width
                text: "Type the password, press Enter to unlock"
                color: Lazer.LazerTheme.textMuted
                font.pixelSize: 11
                opacity: 0.8
            }
        }
    }

    // Keep release ownership in the animation completion path.
    // The wave mask sweeps the wallpaper over the screenshot, then auth fades.
    NumberAnimation {
        id: enterAnimation
        target: root
        property: "waveProgress"
        from: 0
        to: 1
        duration: Lazer.MotionTokens.waveBackdropEnter
        easing.type: Easing.OutQuint
        onFinished: root.authOpacity = 1
    }

    // Unlock un-reveals the wallpaper back to the screenshot before release.
    NumberAnimation {
        id: exitAnimation
        target: root
        property: "waveProgress"
        to: 0
        duration: Lazer.MotionTokens.waveExit
        easing.type: Easing.InQuad
        onFinished: root.requestRelease()
    }

    Connections {
        id: contextConnections
        target: null
        function onUnlocked() {
            root.startExit()
        }

        // A failed conversation must hand keyboard focus straight back so
        // the next attempt can be typed without a pointer.
        function onShowFailureChanged() {
            if (root.lockContext && root.lockContext.showFailure)
                keyboardOwner.forceActiveFocus()
        }
    }
}
