import QtQuick
import QtTest
import "../../modules/lock/LockSurfaceLogic.js" as SurfaceLogic

// Exercise the lock animation seam and production snapshot component without the Wayland plugin.
Item {
    id: harness
    width: 800
    height: 600

    property bool released: false

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
                SurfaceLogic.applyRevealImmediately(lockSurface, enterAnimation, exitAnimation)
                return
            }
            SurfaceLogic.stopAnimations(enterAnimation, exitAnimation)
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
            if (reducedMotion) {
                SurfaceLogic.applyExitImmediately(lockSurface, enterAnimation, exitAnimation)
                if (!releaseSent) {
                    releaseSent = true
                    releaseRequested()
                }
                return
            }
            enterAnimation.stop()
            exitAnimation.stop()
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

        function test_reducedMotionStopsBothAnimationsBeforeFinalState() {
            lockSurface.reducedMotion = false
            lockSurface.startReveal()
            wait(40)
            lockSurface.reducedMotion = true
            lockSurface.startReveal()
            compare(lockSurface.waveProgress, 1)
            compare(lockSurface.authOpacity, 1)
            lockSurface.startExit()
            compare(lockSurface.waveProgress, 0)
            compare(lockSurface.authOpacity, 0)
            verify(harness.released)
        }
    }

    TestCase {
        name: "LockSnapshot"
        when: windowShown

        property var snapshot: null
        property int preparedSignals: 0

        function init() {
            var component = Qt.createComponent(Qt.resolvedUrl("../../modules/lock/LockSnapshot.qml"))
            verify(component.status === Component.Ready, component.errorString())
            snapshot = component.createObject(harness)
            verify(snapshot !== null)
            preparedSignals = 0
            snapshot.prepared.connect(function() { preparedSignals += 1 })
        }

        function cleanup() {
            if (snapshot)
                snapshot.destroy()
            snapshot = null
        }

        function test_generationIsCapturedPerProviderCallback() {
            var firstCallback = null
            var generations = []
            snapshot.snapshotProvider = function(screen, count, generation, callback) {
                generations.push(generation)
                if (!firstCallback)
                    firstCallback = callback
                return { ready: false }
            }
            snapshot.request(1)
            snapshot.request(1)
            compare(generations.length, 2)
            verify(generations[0] < generations[1])
            firstCallback(0, "old.png")
            verify(!snapshot.ready)
            compare(snapshot.preparedScreenCount, 0)
        }

        function test_rejectsInvalidAndDuplicateIndices() {
            var callback = null
            snapshot.snapshotProvider = function(screen, count, generation, report) {
                callback = report
                return { ready: false }
            }
            snapshot.request(2)
            callback(-1, "invalid.png")
            callback(2, "invalid.png")
            callback(0, "one.png")
            callback(0, "duplicate.png")
            compare(snapshot.preparedScreenCount, 1)
            verify(!snapshot.ready)
            callback(1, "two.png")
            verify(snapshot.ready)
            compare(preparedSignals, 1)
        }

        function test_staleCallbackCannotCompleteCurrentRequest() {
            var callbacksByGeneration = ({})
            snapshot.snapshotProvider = function(screen, count, generation, callback) {
                callbacksByGeneration[generation] = callback
                return { ready: false }
            }
            snapshot.request(1)
            var firstGeneration = snapshot.generation
            snapshot.request(2)
            callbacksByGeneration[firstGeneration](0, "stale.png")
            compare(snapshot.preparedScreenCount, 0)
            verify(!snapshot.ready)
            callbacksByGeneration[snapshot.generation](0, "current-one.png")
            callbacksByGeneration[snapshot.generation](1, "current-two.png")
            verify(snapshot.ready)
        }

        function test_timeoutFallbackResolvesWithoutImage() {
            snapshot.snapshotProvider = function() { return { ready: false } }
            snapshot.request(1)
            tryCompare(snapshot, "ready", true, 500)
            compare(snapshot.snapshotUrl, "")
            compare(preparedSignals, 1)
        }
    }
}
