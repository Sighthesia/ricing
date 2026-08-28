import QtQuick
import Quickshell.Wayland
import "../lazerbar" as Lazer
import "./LockLogic.js" as LockLogic

// Own one compositor-enforced full-screen session-lock surface.
WlSessionLockSurface {
    id: root

    property var lockContext: null
    property var snapshot: null
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
            waveProgress = 1
            authOpacity = 1
            return
        }
        exitAnimation.stop()
        enterAnimation.start()
    }

    function startExit(): void {
        if (exitStarted)
            return
        exitStarted = true
        authOpacity = 0
        if (reducedMotion) {
            waveProgress = 0
            requestRelease()
            return
        }
        enterAnimation.stop()
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

    // Display a provider result only when it is a usable local or remote image URL.
    Image {
        id: snapshotImage
        anchors.fill: parent
        source: root.snapshot ? root.snapshot.snapshotUrl : ""
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
    }
}
