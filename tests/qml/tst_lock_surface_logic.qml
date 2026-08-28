import QtQuick
import QtTest

// Exercise the LockSurface animation contract without requiring the optional Wayland plugin.
Item {
    id: harness
    width: 800
    height: 600

    property bool released: false

    // Mirror the public state machine used by the real WlSessionLockSurface.
    Item {
        id: lockSurface
        anchors.fill: parent
        property real waveProgress: 0
        property real authOpacity: 0
        property bool reducedMotion: false
        property bool exitStarted: false
        property bool releaseSent: false
        signal releaseRequested()

        function startReveal() {
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

        function stopAnimation() {
            enterAnimation.stop()
            exitAnimation.stop()
        }

        function startExit() {
            if (exitStarted)
                return
            exitStarted = true
            authOpacity = 0
            if (reducedMotion) {
                waveProgress = 0
                if (!releaseSent) {
                    releaseSent = true
                    releaseRequested()
                }
                return
            }
            enterAnimation.stop()
            exitAnimation.from = waveProgress
            exitAnimation.start()
        }

        NumberAnimation {
            id: enterAnimation
            target: lockSurface
            property: "waveProgress"
            from: 0
            to: 1
            duration: 600
            easing.type: Easing.OutQuint
            onFinished: lockSurface.authOpacity = 1
        }

        NumberAnimation {
            id: exitAnimation
            target: lockSurface
            property: "waveProgress"
            to: 0
            duration: 500
            easing.type: Easing.OutQuint
            onFinished: {
                if (!lockSurface.releaseSent) {
                    lockSurface.releaseSent = true
                    lockSurface.releaseRequested()
                }
            }
        }

        Component.onCompleted: startReveal()
    }

    Connections {
        target: lockSurface
        function onReleaseRequested() { harness.released = true }
    }

    TestCase {
        name: "LockSurface"
        when: windowShown

        function init() {
            harness.released = false
            lockSurface.stopAnimation()
            lockSurface.reducedMotion = false
            lockSurface.waveProgress = 0
            lockSurface.authOpacity = 0
            lockSurface.exitStarted = false
            lockSurface.releaseSent = false
        }

        function test_surfaceIsFullSizeAndRevealCompletes() {
            compare(lockSurface.width, harness.width)
            compare(lockSurface.height, harness.height)
            compare(lockSurface.waveProgress, 0)
            lockSurface.startReveal()
            tryCompare(lockSurface, "waveProgress", 1, 1200)
            tryCompare(lockSurface, "authOpacity", 1, 100)
        }

        function test_releaseWaitsForExitAnimation() {
            lockSurface.startReveal()
            tryCompare(lockSurface, "waveProgress", 1, 1200)
            lockSurface.startExit()
            verify(!harness.released)
            tryCompare(harness, "released", true, 900)
            tryCompare(lockSurface, "waveProgress", 0, 100)
        }

        function test_reducedMotionUsesFinalValuesImmediately() {
            lockSurface.reducedMotion = true
            lockSurface.startReveal()
            compare(lockSurface.waveProgress, 1)
            compare(lockSurface.authOpacity, 1)
            lockSurface.startExit()
            compare(lockSurface.waveProgress, 0)
            verify(harness.released)
        }
    }
}
