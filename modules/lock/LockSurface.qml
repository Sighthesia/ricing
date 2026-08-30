import QtQuick
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
    property real waveProgress: 0
    property real authOpacity: 0
    property bool reducedMotion: Lazer.MotionTokens.reducedMotion
    property bool exitStarted: false
    property bool releaseSent: false

    signal releaseRequested()

    color: "transparent"

    function startReveal(): void {
        exitStarted = false
        releaseSent = false
        if (reducedMotion) {
            SurfaceLogic.applyRevealImmediately(root, enterAnimation, exitAnimation)
            return
        }
        SurfaceLogic.stopAnimations(enterAnimation, exitAnimation)
        enterAnimation.start()
    }

    function startExit(): void {
        if (exitStarted)
            return
        exitStarted = true
        if (reducedMotion) {
            SurfaceLogic.applyExitImmediately(root, enterAnimation, exitAnimation)
            requestRelease()
            return
        }
        authOpacity = 0
        enterAnimation.stop()
        exitAnimation.stop()
        exitAnimation.from = waveProgress
        exitAnimation.start()
    }

    function requestRelease(): void {
        if (releaseSent || !LockLogic.shouldReleaseLock("exiting", true))
            return
        releaseSent = true
        releaseRequested()
    }

    onLockContextChanged: {
        if (lockContext)
            contextConnections.target = lockContext
    }

    Component.onCompleted: startReveal()

    // Paint a solid fallback first so an unavailable snapshot can never expose the desktop.
    Rectangle {
        id: fallback
        anchors.fill: parent
        color: Lazer.LazerTheme.bgDark
        opacity: 1
    }

    // Display only this surface's own snapshot slot; an empty slot keeps the
    // opaque fallback rather than borrowing another screen's image.
    Image {
        id: snapshotImage
        anchors.fill: parent
        source: root.snapshot && root.screenIndex >= 0
                ? root.snapshot.snapshotUrlFor(root.screenIndex) : ""
        visible: status === Image.Ready && source !== ""
        fillMode: Image.Stretch
        asynchronous: true
    }

    // Reveal the protected surface with the shared four-layer wave renderer.
    Lazer.WaveRevealLayers {
        id: waves
        anchors.fill: parent
        progress: root.waveProgress
        palette: ({
            light4: Lazer.LazerTheme.settingsSection,
            light3: Lazer.LazerTheme.settingsCardHover,
            dark4: Lazer.LazerTheme.settingsRail,
            dark3: Lazer.LazerTheme.bgDark
        })
    }

    // Keep authentication content rectangular and above the reveal layers.
    Rectangle {
        id: authSurface
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.82, 420)
        height: Math.min(parent.height * 0.48, 260)
        color: Lazer.LazerTheme.settingsPanel
        opacity: root.authOpacity
        z: 2

        // Receive keyboard input only inside the session-lock surface.
        Item {
            id: inputOwner
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (!root.lockContext)
                    return
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.lockContext.start()
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

    NumberAnimation {
        id: exitAnimation
        target: root
        property: "waveProgress"
        to: 0
        duration: Lazer.MotionTokens.waveExit
        easing.type: Easing.OutQuint
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
                inputOwner.forceActiveFocus()
        }
    }
}
