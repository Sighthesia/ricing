import QtQuick
import QtTest
import "../../modules/lock/LockSurfaceLogic.js" as SurfaceLogic

// Exercise the lock animation seam and production snapshot component without the Wayland plugin.
Item {
    id: harness
    width: 800
    height: 600

    property bool released: false

    // Harness mirrors the production dual-channel contract exactly: bands
    // 600ms OutQuad lead, body 800ms OutQuint follows; close is body InQuad
    // with bands InSine, both 500ms, release owned by the body landing.
    Item {
        id: lockSurface
        anchors.fill: parent
        property real bandsProgress: 0
        property real bodyProgress: 0
        property bool reducedMotion: false
        property bool exitStarted: false
        property bool releaseSent: false
        signal releaseRequested()

        function allAnimations() {
            return [enterBands, enterBody, exitBands, exitBody]
        }

        function startReveal() {
            exitStarted = false
            releaseSent = false
            if (reducedMotion) {
                SurfaceLogic.applyRevealImmediately(lockSurface, allAnimations())
                return
            }
            SurfaceLogic.stopAll(allAnimations())
            enterBands.from = bandsProgress
            enterBody.from = bodyProgress
            enterBands.start()
            enterBody.start()
        }

        function stopAnimation() {
            SurfaceLogic.stopAll(allAnimations())
        }

        function startExit() {
            if (exitStarted)
                return
            exitStarted = true
            if (reducedMotion) {
                SurfaceLogic.applyExitImmediately(lockSurface, allAnimations())
                if (!releaseSent) {
                    releaseSent = true
                    releaseRequested()
                }
                return
            }
            SurfaceLogic.stopAll(allAnimations())
            exitBody.from = bodyProgress
            exitBands.from = bandsProgress
            exitBody.start()
            exitBands.start()
        }

        NumberAnimation {
            id: enterBands
            target: lockSurface
            property: "bandsProgress"
            from: 0
            to: 1
            duration: 600
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: enterBody
            target: lockSurface
            property: "bodyProgress"
            from: 0
            to: 1
            duration: 800
            easing.type: Easing.OutQuint
        }

        NumberAnimation {
            id: exitBody
            target: lockSurface
            property: "bodyProgress"
            to: 0
            duration: 500
            easing.type: Easing.InQuad
            onFinished: {
                if (!lockSurface.releaseSent) {
                    lockSurface.releaseSent = true
                    lockSurface.releaseRequested()
                }
            }
        }

        NumberAnimation {
            id: exitBands
            target: lockSurface
            property: "bandsProgress"
            to: 0
            duration: 500
            easing.type: Easing.InSine
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
            lockSurface.bandsProgress = 0
            lockSurface.bodyProgress = 0
            lockSurface.exitStarted = false
            lockSurface.releaseSent = false
        }

        function test_surfaceIsFullSizeAndRevealCompletes() {
            compare(lockSurface.width, harness.width)
            compare(lockSurface.height, harness.height)
            compare(lockSurface.bandsProgress, 0)
            compare(lockSurface.bodyProgress, 0)
            lockSurface.startReveal()
            tryCompare(lockSurface, "bandsProgress", 1, 1000)
            tryCompare(lockSurface, "bodyProgress", 1, 1200)
        }

        function test_bandsAndBodyOverlapDuringReveal() {
            lockSurface.startReveal()
            wait(300)
            verify(lockSurface.bandsProgress > 0 && lockSurface.bandsProgress < 1)
            verify(lockSurface.bodyProgress > 0 && lockSurface.bodyProgress < 1)
            tryCompare(lockSurface, "bodyProgress", 1, 1200)
        }

        function test_exitRetargetsBothChannelsFromLiveValues() {
            lockSurface.startReveal()
            wait(300)
            var liveBands = lockSurface.bandsProgress
            var liveBody = lockSurface.bodyProgress
            verify(liveBands > 0 && liveBody > 0)
            lockSurface.startExit()
            verify(!harness.released)
            tryCompare(harness, "released", true, 900)
            compare(lockSurface.bandsProgress, 0)
            compare(lockSurface.bodyProgress, 0)
        }

        function test_releaseWaitsForExitAnimation() {
            lockSurface.startReveal()
            tryCompare(lockSurface, "bodyProgress", 1, 1200)
            lockSurface.startExit()
            verify(!harness.released)
            tryCompare(harness, "released", true, 900)
            tryCompare(lockSurface, "bodyProgress", 0, 100)
            compare(lockSurface.bandsProgress, 0)
        }

        function test_reducedMotionUsesFinalValuesImmediately() {
            lockSurface.reducedMotion = true
            lockSurface.startReveal()
            compare(lockSurface.bandsProgress, 1)
            compare(lockSurface.bodyProgress, 1)
            lockSurface.startExit()
            compare(lockSurface.bandsProgress, 0)
            compare(lockSurface.bodyProgress, 0)
            verify(harness.released)
        }

        function test_reducedMotionStopsBothAnimationsBeforeFinalState() {
            lockSurface.reducedMotion = false
            lockSurface.startReveal()
            wait(40)
            lockSurface.reducedMotion = true
            lockSurface.startReveal()
            compare(lockSurface.bandsProgress, 1)
            compare(lockSurface.bodyProgress, 1)
            lockSurface.startExit()
            compare(lockSurface.bandsProgress, 0)
            compare(lockSurface.bodyProgress, 0)
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
            compare(snapshot.snapshotUrlFor(0), "")
            compare(preparedSignals, 1)
        }

        function test_perScreenUrlsFillOnlyTheirOwnSlot() {
            var callback = null
            snapshot.snapshotProvider = function(screen, count, generation, report) {
                callback = report
                return { ready: false }
            }
            snapshot.request(2)
            callback(0, "left.png")
            compare(snapshot.snapshotUrlFor(0), "left.png")
            compare(snapshot.snapshotUrlFor(1), "")
            callback(1, "right.png")
            compare(snapshot.snapshotUrlFor(1), "right.png")
        }

        function test_synchronousResultOnlyDescribesScreenZero() {
            snapshot.snapshotProvider = function() { return { ready: true, url: "only.png" } }
            snapshot.request(2)
            verify(snapshot.ready)
            compare(snapshot.snapshotUrlFor(0), "only.png")
            compare(snapshot.snapshotUrlFor(1), "")
        }

        function test_outOfRangeIndicesResolveToEmptySlot() {
            var callback = null
            snapshot.snapshotProvider = function(screen, count, generation, report) {
                callback = report
                return { ready: false }
            }
            snapshot.request(1)
            callback(0, "solo.png")
            compare(snapshot.snapshotUrlFor(-1), "")
            compare(snapshot.snapshotUrlFor(1), "")
            compare(snapshot.snapshotUrlFor(1.5), "")
        }

        function test_staleGenerationCannotStoreScreenUrl() {
            var callbacksByGeneration = ({})
            snapshot.snapshotProvider = function(screen, count, generation, callback) {
                callbacksByGeneration[generation] = callback
                return { ready: false }
            }
            snapshot.request(1)
            var firstGeneration = snapshot.generation
            snapshot.request(1)
            callbacksByGeneration[firstGeneration](0, "stale.png")
            compare(snapshot.snapshotUrlFor(0), "")
            callbacksByGeneration[snapshot.generation](0, "fresh.png")
            compare(snapshot.snapshotUrlFor(0), "fresh.png")
        }

        function test_newRequestClearsPreviousScreenUrls() {
            snapshot.snapshotProvider = function() { return { ready: true, url: "first.png" } }
            snapshot.request(1)
            compare(snapshot.snapshotUrlFor(0), "first.png")
            snapshot.snapshotProvider = function(screen, count, generation, callback) {
                return { ready: false }
            }
            snapshot.request(1)
            compare(snapshot.snapshotUrlFor(0), "")
        }
    }

    // Pure presentation seam: mask, status copy, and screen-slot resolution.
    TestCase {
        name: "LockSurfaceLogic"
        when: windowShown

        function test_maskedPasswordRendersBulletsOnly() {
            var masked = SurfaceLogic.maskedPassword("secret")
            compare(masked.length, 6)
            verify(masked.indexOf("secret") < 0)
            compare(masked.charAt(0), "\u25CF")
            compare(masked.charAt(5), "\u25CF")
        }

        function test_maskedPasswordHandlesEmptyAndCapsLongInput() {
            compare(SurfaceLogic.maskedPassword(""), "")
            compare(SurfaceLogic.maskedPassword(null), "")
            compare(SurfaceLogic.maskedPassword(undefined), "")
            var longInput = ""
            for (var i = 0; i < 64; ++i)
                longInput += "x"
            var masked = SurfaceLogic.maskedPassword(longInput)
            compare(masked.length, SurfaceLogic.maxMaskedCharacters)
            verify(masked.indexOf("x") < 0)
        }

        function test_authStatusCoversProgressFailureAndIdle() {
            var progress = SurfaceLogic.authStatus(true, false, "")
            compare(progress.message, "Verifying...")
            compare(progress.tone, SurfaceLogic.authTones.progress)

            var failure = SurfaceLogic.authStatus(false, true, "bad password")
            compare(failure.message, "bad password")
            compare(failure.tone, SurfaceLogic.authTones.failure)

            var idle = SurfaceLogic.authStatus(false, false, "")
            compare(idle.message, "")
            compare(idle.tone, SurfaceLogic.authTones.none)
        }

        function test_authStatusFallsBackToSpokenMessageWhenErrorIsEmpty() {
            var empty = SurfaceLogic.authStatus(false, true, "")
            verify(empty.message.length > 0)
            compare(empty.message, "Authentication failed")
            compare(empty.tone, SurfaceLogic.authTones.failure)

            var nullish = SurfaceLogic.authStatus(false, true, null)
            compare(nullish.message, "Authentication failed")
        }

        function test_screenSlotMapsByIdentity() {
            // Identity comparison, so plain JS objects exercise the same seam.
            var first = { name: "DP-1" }
            var second = { name: "HDMI-1" }
            compare(SurfaceLogic.screenSlot([first, second], second), 1)
            compare(SurfaceLogic.screenSlot([first, second], first), 0)
            compare(SurfaceLogic.screenSlot([first], { name: "DP-1" }), -1)
            compare(SurfaceLogic.screenSlot(null, first), -1)
            compare(SurfaceLogic.screenSlot([first], null), -1)
        }

        function test_backgroundLayersSelectBaseAndReveal() {
            // Base: the screen's own capture, or nothing over the opaque floor.
            compare(SurfaceLogic.baseSource("shot.png"), "shot.png")
            compare(SurfaceLogic.baseSource(""), "")
            compare(SurfaceLogic.baseSource(null), "")
            // Reveal: the wallpaper is the curtain; empty falls back to panel color.
            compare(SurfaceLogic.revealSource("wall.png"), "wall.png")
            compare(SurfaceLogic.revealSource(""), "")
            compare(SurfaceLogic.revealSource(null), "")
            // Capture is the default; only an explicit wallpaper value skips it.
            compare(SurfaceLogic.normalizeBackgroundMode(""), SurfaceLogic.backgroundModes.screenshot)
            compare(SurfaceLogic.normalizeBackgroundMode("wallpaper"), SurfaceLogic.backgroundModes.wallpaper)
            compare(SurfaceLogic.normalizeBackgroundMode("bogus"), SurfaceLogic.backgroundModes.screenshot)
        }
    }
}
