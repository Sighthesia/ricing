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
        property real bodyProgress: 0
        property real authOpacity: 0
        property bool reducedMotion: false
        property bool exitStarted: false
        property bool releaseSent: false
        signal releaseRequested()

        function allAnimations() {
            return [enterAnimation, bodyEnterAnimation, bodyExitAnimation, exitAnimation]
        }

        function startReveal() {
            exitStarted = false
            releaseSent = false
            if (reducedMotion) {
                SurfaceLogic.applyRevealImmediately(lockSurface, allAnimations())
                return
            }
            SurfaceLogic.stopAll(allAnimations())
            enterAnimation.start()
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
            authOpacity = 0
            SurfaceLogic.stopAll(allAnimations())
            bodyExitAnimation.from = bodyProgress
            bodyExitAnimation.start()
        }

        NumberAnimation {
            id: enterAnimation
            target: lockSurface
            property: "waveProgress"
            from: 0
            to: 1
            duration: 600
            easing.type: Easing.OutQuint
            onFinished: bodyEnterAnimation.start()
        }

        NumberAnimation {
            id: bodyEnterAnimation
            target: lockSurface
            property: "bodyProgress"
            from: 0
            to: 1
            duration: 400
            easing.type: Easing.OutQuint
            onFinished: lockSurface.authOpacity = 1
        }

        NumberAnimation {
            id: bodyExitAnimation
            target: lockSurface
            property: "bodyProgress"
            to: 0
            duration: 300
            easing.type: Easing.InQuad
            onFinished: {
                exitAnimation.from = lockSurface.waveProgress
                exitAnimation.start()
            }
        }

        NumberAnimation {
            id: exitAnimation
            target: lockSurface
            property: "waveProgress"
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
            lockSurface.bodyProgress = 0
            lockSurface.authOpacity = 0
            lockSurface.exitStarted = false
            lockSurface.releaseSent = false
        }

        function test_surfaceIsFullSizeAndRevealCompletes() {
            compare(lockSurface.width, harness.width)
            compare(lockSurface.height, harness.height)
            compare(lockSurface.waveProgress, 0)
            lockSurface.startReveal()
            // The curtain covers first, then the body rises, then auth shows.
            tryCompare(lockSurface, "waveProgress", 1, 1200)
            tryCompare(lockSurface, "bodyProgress", 1, 900)
            tryCompare(lockSurface, "authOpacity", 1, 100)
        }

        function test_releaseWaitsForExitAnimation() {
            lockSurface.startReveal()
            tryCompare(lockSurface, "bodyProgress", 1, 1500)
            lockSurface.startExit()
            verify(!harness.released)
            // The body must sink before the curtain retracts and release.
            tryCompare(lockSurface, "bodyProgress", 0, 700)
            tryCompare(harness, "released", true, 900)
            tryCompare(lockSurface, "waveProgress", 0, 100)
        }

        function test_reducedMotionUsesFinalValuesImmediately() {
            lockSurface.reducedMotion = true
            lockSurface.startReveal()
            compare(lockSurface.waveProgress, 1)
            compare(lockSurface.bodyProgress, 1)
            compare(lockSurface.authOpacity, 1)
            lockSurface.startExit()
            compare(lockSurface.waveProgress, 0)
            compare(lockSurface.bodyProgress, 0)
            compare(lockSurface.authOpacity, 0)
            verify(harness.released)
        }

        function test_reducedMotionStopsBothAnimationsBeforeFinalState() {
            lockSurface.reducedMotion = false
            lockSurface.startReveal()
            wait(40)
            lockSurface.reducedMotion = true
            lockSurface.startReveal()
            compare(lockSurface.waveProgress, 1)
            compare(lockSurface.bodyProgress, 1)
            compare(lockSurface.authOpacity, 1)
            lockSurface.startExit()
            compare(lockSurface.waveProgress, 0)
            compare(lockSurface.bodyProgress, 0)
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

        function test_backgroundSourcePrefersScreenshotThenWallpaper() {
            compare(SurfaceLogic.backgroundSource("screenshot", "shot.png", "wall.png"), "shot.png")
            // A missing capture falls back to the configured wallpaper.
            compare(SurfaceLogic.backgroundSource("screenshot", "", "wall.png"), "wall.png")
            compare(SurfaceLogic.backgroundSource("wallpaper", "shot.png", "wall.png"), "wall.png")
            // Nothing available: the opaque body floor covers the desktop.
            compare(SurfaceLogic.backgroundSource("screenshot", "", ""), "")
            compare(SurfaceLogic.backgroundSource("wallpaper", "", ""), "")
            // Unknown modes normalize to wallpaper.
            compare(SurfaceLogic.backgroundSource("bogus", "shot.png", "wall.png"), "wall.png")
            compare(SurfaceLogic.normalizeBackgroundMode("screenshot"), "screenshot")
            compare(SurfaceLogic.normalizeBackgroundMode("bogus"), "wallpaper")
        }
    }
}
