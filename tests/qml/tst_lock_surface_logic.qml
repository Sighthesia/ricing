import QtQuick
import QtTest
import "../../modules/lock/LockSurfaceLogic.js" as SurfaceLogic

// Exercise the lock animation seam and production snapshot component without the Wayland plugin.
Item {
    id: harness
    width: 800
    height: 600

    property bool released: false

    // Stands in for the animated theme singleton: Color.qml animates every
    // palette token with `Behavior on color`, and a color read out of such a
    // property keeps re-evaluating when stored in a JS object.
    QtObject {
        id: themeSource
        property color surface: "#101010"
        property color panel: "#202020"
        property color hover: Qt.rgba(0.1, 0.1, 0.12, 0.078)

        Behavior on surface { ColorAnimation { duration: 40 } }
        Behavior on panel { ColorAnimation { duration: 40 } }
        Behavior on hover { ColorAnimation { duration: 40 } }
    }

    // Harness mirrors the production contract exactly: one reveal driver,
    // enter 800ms OutQuad, exit 500ms OutQuad, plus the single 360ms content
    // fall that every block shares; release is still owned by the wave landing.
    Item {
        id: lockSurface
        anchors.fill: parent
        property real waveProgress: 0
        property real contentFallProgress: 0
        property bool reducedMotion: false
        property bool exitStarted: false
        property bool releaseSent: false
        // Startup gate mirror: a session-start surface prepares immediately but
        // holds its entry wave until the wallpaper and chrome gates both open.
        property bool startupRequest: false
        property bool startupRevealAllowed: true
        property bool startupWaveStarted: false
        signal releaseRequested()
        signal startupWaveStartedSignal()

        function allAnimations() {
            return [enterAnimation, exitAnimation, contentFallAnimation]
        }

        function prepareReveal() {
            exitStarted = false
            releaseSent = false
            contentFallProgress = 0
            startupWaveStarted = false
            if (reducedMotion) {
                SurfaceLogic.applyRevealImmediately(lockSurface, allAnimations())
                return
            }
            SurfaceLogic.stopAll(allAnimations())
        }

        function beginEntryWave() {
            if (exitStarted || reducedMotion || startupWaveStarted)
                return
            startupWaveStarted = true
            enterAnimation.from = waveProgress
            enterAnimation.start()
            startupWaveStartedSignal()
        }

        // Manual entry: prepare and wave at once, never consulting the gates.
        function startReveal() {
            prepareReveal()
            beginEntryWave()
        }

        // Startup entry: prepare now, wave only once the gates allow it.
        function tryStartReveal() {
            prepareReveal()
            if (!startupRequest || startupRevealAllowed)
                beginEntryWave()
        }

        onStartupRevealAllowedChanged: {
            if (startupRequest && startupRevealAllowed)
                beginEntryWave()
        }

        function stopAnimation() {
            SurfaceLogic.stopAll(allAnimations())
        }

        function startExit() {
            if (exitStarted)
                return
            exitStarted = true
            if (reducedMotion) {
                contentFallProgress = 1
                SurfaceLogic.applyExitImmediately(lockSurface, allAnimations())
                if (!releaseSent) {
                    releaseSent = true
                    releaseRequested()
                }
                return
            }
            SurfaceLogic.stopAll(allAnimations())
            if (contentFallProgress <= 0) {
                contentFallAnimation.restart()
                return
            }
            startWaveExit()
        }

        function startWaveExit() {
            exitAnimation.from = waveProgress
            exitAnimation.start()
        }

        NumberAnimation {
            id: enterAnimation
            target: lockSurface
            property: "waveProgress"
            from: 0
            to: 1
            duration: 800
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: exitAnimation
            target: lockSurface
            property: "waveProgress"
            to: 0
            duration: 500
            easing.type: Easing.OutQuad
            onFinished: {
                if (!lockSurface.releaseSent) {
                    lockSurface.releaseSent = true
                    lockSurface.releaseRequested()
                }
            }
        }

        NumberAnimation {
            id: contentFallAnimation
            target: lockSurface
            property: "contentFallProgress"
            from: 0
            to: 1
            duration: 360
            easing.type: Easing.Linear
            onFinished: lockSurface.startWaveExit()
        }

        Component.onCompleted: {
            if (startupRequest)
                tryStartReveal()
            else
                startReveal()
        }
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
            lockSurface.contentFallProgress = 0
            lockSurface.exitStarted = false
            lockSurface.releaseSent = false
            lockSurface.startupRequest = false
            lockSurface.startupRevealAllowed = true
            lockSurface.startupWaveStarted = false
        }

        function test_surfaceIsFullSizeAndRevealCompletes() {
            compare(lockSurface.width, harness.width)
            compare(lockSurface.height, harness.height)
            compare(lockSurface.waveProgress, 0)
            lockSurface.startReveal()
            tryCompare(lockSurface, "waveProgress", 1, 1200)
        }

        function test_exitRetargetsFromLiveValue() {
            lockSurface.startReveal()
            wait(300)
            verify(lockSurface.waveProgress > 0 && lockSurface.waveProgress < 1)
            lockSurface.startExit()
            verify(!harness.released)
            tryCompare(harness, "released", true, 1200)
            compare(lockSurface.waveProgress, 0)
        }

        function test_releaseWaitsForExitAnimation() {
            lockSurface.startReveal()
            tryCompare(lockSurface, "waveProgress", 1, 1200)
            lockSurface.startExit()
            verify(!harness.released)
            tryCompare(harness, "released", true, 1200)
            tryCompare(lockSurface, "waveProgress", 0, 100)
        }

        // The content blocks drop away together: one curve, no stagger, and the
        // wave must not start moving until the fall has landed.
        function test_exitPlaysTheContentFallBeforeTheWave() {
            lockSurface.startReveal()
            tryCompare(lockSurface, "waveProgress", 1, 1200)
            lockSurface.startExit()
            wait(200)
            verify(lockSurface.contentFallProgress > 0, "the fall must be running")
            compare(lockSurface.waveProgress, 1, "the wave waits for the fall")
            verify(!harness.released)
            tryCompare(lockSurface, "contentFallProgress", 1, 600)
            tryCompare(harness, "released", true, 900)
            compare(lockSurface.waveProgress, 0)
        }

        function test_reducedMotionUsesFinalValuesImmediately() {
            lockSurface.reducedMotion = true
            lockSurface.startReveal()
            compare(lockSurface.waveProgress, 1)
            lockSurface.startExit()
            compare(lockSurface.waveProgress, 0)
            compare(lockSurface.contentFallProgress, 1, "reduced motion settles the fall")
            verify(harness.released)
        }

        function test_reducedMotionStopsBothAnimationsBeforeFinalState() {
            lockSurface.reducedMotion = false
            lockSurface.startReveal()
            wait(40)
            lockSurface.reducedMotion = true
            lockSurface.startReveal()
            compare(lockSurface.waveProgress, 1)
            lockSurface.startExit()
            compare(lockSurface.waveProgress, 0)
            verify(harness.released)
        }

        // A session-start surface holds its wave while either gate is closed,
        // then plays the normal 800ms enter once both open.
        function test_startupWaveWaitsForBothReadinessGates() {
            lockSurface.startupRequest = true
            lockSurface.startupRevealAllowed = false
            lockSurface.tryStartReveal()
            compare(lockSurface.waveProgress, 0)
            wait(300)
            compare(lockSurface.waveProgress, 0, "gated startup must not wave")
            verify(!lockSurface.startupWaveStarted)
            lockSurface.startupRevealAllowed = true
            tryCompare(lockSurface, "waveProgress", 1, 1200)
            verify(lockSurface.startupWaveStarted)
        }

        // A manual surface waves at once even when the startup gates are shut.
        function test_manualRevealStartsImmediatelyWhenGateIsClosed() {
            lockSurface.startupRequest = false
            lockSurface.startupRevealAllowed = false
            lockSurface.tryStartReveal()
            tryCompare(lockSurface, "waveProgress", 1, 1200)
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

        // An emptied field must not shift its insertion mark. The bullets are
        // centered between the insets, and the caret reads the same axis, so
        // the mark lands where the text was instead of drifting left.
        function test_passwordAxisCentersBetweenTheInsets() {
            compare(SurfaceLogic.passwordTextAxis(360, 56, 20), 198)
            // The control center is 180: reusing it is exactly the bug.
            verify(SurfaceLogic.passwordTextAxis(360, 56, 20) !== 180)
            compare(SurfaceLogic.passwordTextAxis(360, 0, 0), 180)
            compare(SurfaceLogic.passwordTextAxis(68, 56, 20), 52)
        }

        // A collapsed or not-yet-measured control must still yield a finite
        // axis: a NaN here would park the caret off-screen instead of hiding it.
        function test_passwordAxisToleratesMissingGeometry() {
            compare(SurfaceLogic.passwordTextAxis(undefined, 56, 20), 18)
            verify(isFinite(SurfaceLogic.passwordTextAxis(null, null, null)))
            compare(SurfaceLogic.passwordTextAxis(360, null, null), 180)
            compare(SurfaceLogic.passwordTextAxis(360, undefined, undefined), 180)
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

        function test_escapeCancelsOnlyAuthenticationPresentation() {
            compare(SurfaceLogic.inputEscapeAction(true, false), "cancel-input")
            compare(SurfaceLogic.inputEscapeAction(false, true), "cancel-input")
            compare(SurfaceLogic.inputEscapeAction(false, false), "none")
        }

        // The unlock fall borrows the notification card's free fall: the drop
        // accelerates with t² and the fade follows the same curve, so a linear
        // time base still reads as a fall rather than a slide.
        function test_contentFallAcceleratesAndFadesOnOneCurve() {
            const start = SurfaceLogic.contentFallCurve(0)
            compare(start.drop, 0)
            compare(start.fade, 0)
            const quarter = SurfaceLogic.contentFallCurve(0.25)
            compare(quarter.drop, 0.0625)
            compare(quarter.fade, 0.0625)
            compare(SurfaceLogic.contentFallCurve(0.5).drop, 0.25)
            const end = SurfaceLogic.contentFallCurve(1)
            compare(end.drop, 1)
            compare(end.fade, 1)
            compare(SurfaceLogic.contentFallCurve(2).drop, 1, "clamped past the end")
            compare(SurfaceLogic.contentFallCurve(-1).fade, 0, "clamped before the start")
        }

        // Every block reads one curve, so the clock, the lock entry and the
        // power row are always at the same point of the fall. There is no
        // per-block delay left to sample.
        function test_everyBlockFallsOnTheSameSample() {
            const half = SurfaceLogic.contentFallCurve(0.5)
            compare(half.drop, 0.25)
            compare(half.fade, 0.25)
            verify(SurfaceLogic.staggeredFallProgress === undefined,
                   "no per-block delay may survive")
        }

        function test_passwordInputKeepsMixedCaseAndDigitsOnOnePath() {
            var state = SurfaceLogic.passwordInputEdit("", false, false, "A")
            compare(state.action, "edit")
            compare(state.text, "A")
            state = SurfaceLogic.passwordInputEdit(state.text, false, false, "7")
            compare(state.text, "A7")
            state = SurfaceLogic.passwordInputEdit(state.text, false, false, "z")
            compare(state.text, "A7z")
            state = SurfaceLogic.passwordInputEdit(state.text, false, true, "")
            compare(state.text, "A7")
            state = SurfaceLogic.passwordInputEdit(state.text, true, false, "")
            compare(state.action, "submit")
            compare(state.text, "A7")
        }

        function test_passwordInputIgnoresNonPrintableEvents() {
            var state = SurfaceLogic.passwordInputEdit("A7", false, false, "\u0001")
            compare(state.action, "none")
            compare(state.text, "A7")
            state = SurfaceLogic.passwordInputEdit("A7", false, false, "\u007f")
            compare(state.action, "none")
            compare(state.text, "A7")
        }

        function test_clockThemeColorStaysOnAccentHueAndChoosesContrastTone() {
            var accent = Qt.rgba(1, 0.4, 0.67, 1)
            var lightModeText = SurfaceLogic.clockThemeColor(accent, 0.2, true)
            var darkModeText = SurfaceLogic.clockThemeColor(accent, 0.8, false)
            verify(lightModeText.hslLightness < 0.5)
            verify(darkModeText.hslLightness > 0.5)
            verify(Math.abs(lightModeText.hslHue - darkModeText.hslHue) < 0.001)
            verify(lightModeText.hslSaturation > 0.3)
        }

        function test_derivedIconToneStaysDistinctFromNeutralText() {
            var accent = Qt.rgba(0.35, 0.20, 0.65, 1)
            var iconColor = SurfaceLogic.clockThemeColor(accent, 0.5, true)
            var textColor = Qt.rgba(0.13, 0.12, 0.14, 1)
            verify(Math.abs(iconColor.r - textColor.r)
                    + Math.abs(iconColor.g - textColor.g)
                    + Math.abs(iconColor.b - textColor.b) > 0.18)
        }

        function test_readableThemeColorRejectsBlackAndTransparentIntermediateValues() {
            var invalid = Qt.rgba(0, 0, 0, 0)
            var light = SurfaceLogic.readableThemeColor(invalid, true)
            var dark = SurfaceLogic.readableThemeColor(invalid, false)
            verify(light.hslLightness < 0.5)
            verify(dark.hslLightness > 0.5)
            verify(light.hslHue > 0.85)
            verify(dark.hslHue > 0.85)
            verify(light.a > 0.9)
            verify(dark.a > 0.9)
        }

        function test_readableTextColorStaysDistinctFromIconTone() {
            var accent = Qt.rgba(0.35, 0.20, 0.65, 1)
            var icon = SurfaceLogic.readableThemeColor(accent, true)
            var text = SurfaceLogic.readableTextColor(accent, true)
            verify(text.hslLightness < icon.hslLightness)
            verify(text.a > 0.9)
        }

        // A color read from a QML property is a binding-backed value type: when
        // it is stored in a JS object it keeps re-evaluating, so a snapshot that
        // aliases it silently repaints from the live theme. That is what made
        // the session panel change color under an already-open lock.
        // lockThemeSnapshot() therefore copies every accepted color into a plain
        // Qt.rgba value. Note: qmltestrunner compares colors by value and does
        // not retain the animated binding, so this test pins the contract but
        // cannot reproduce the runtime repaint on its own.
        function test_lockThemeSnapshotIgnoresLaterThemeChanges() {
            const snapshot = SurfaceLogic.lockThemeSnapshot(false, {
                accent: Qt.rgba(1, 0.4, 0.667, 1),
                surface: themeSource.surface,
                panel: themeSource.panel,
                hover: themeSource.hover,
            })
            const panel = snapshot.panel
            const surface = snapshot.surface
            const hover = snapshot.hover

            themeSource.surface = "#010101"
            themeSource.panel = "#ffffff"
            themeSource.hover = Qt.rgba(0.9, 0.1, 0.4, 0.5)
            // Let the ColorAnimations land; the snapshot must ignore them.
            wait(200)

            compare(snapshot.panel, panel, "panel must not follow the theme")
            compare(snapshot.surface, surface, "surface must not follow the theme")
            compare(snapshot.hover, hover, "hover must not follow the theme")
            verify(snapshot.panel.a > 0.9, "detached colors keep their alpha")
        }

        function test_lockThemeSnapshotKeepsOnePaletteGeneration() {            var palette = {
                accent: Qt.rgba(1, 0.2, 0.5, 1),
                surface: Qt.rgba(0.08, 0.07, 0.10, 1),
                control: Qt.rgba(0.14, 0.12, 0.17, 1),
                muted: Qt.rgba(0.72, 0.68, 0.76, 1),
                divider: Qt.rgba(0.3, 0.28, 0.34, 1),
            }
            var snapshot = SurfaceLogic.lockThemeSnapshot(false, palette)
            compare(snapshot.lightScheme, false)
            verify(snapshot.surface.hslLightness < 0.5)
            verify(snapshot.control.hslLightness < 0.5)
            verify(snapshot.panel.a > 0.9)
            verify(snapshot.trigger.a > 0.9)
            verify(snapshot.text.hslLightness > 0.5)
            verify(snapshot.sessionText.hslHue > 0.8)

            var invalid = SurfaceLogic.lockThemeSnapshot(false, {
                accent: Qt.rgba(0, 0, 0, 0),
                surface: Qt.rgba(0, 0, 0, 0),
                control: Qt.rgba(0, 0, 0, 0),
                muted: Qt.rgba(0, 0, 0, 0),
                divider: Qt.rgba(0, 0, 0, 0),
            })
            verify(invalid.sessionText.hslHue > 0.8)
            verify(invalid.text.a > 0.9)
        }

        function test_authControlKeepsIconThroughInputAndUnlockFeedback() {
            var state = SurfaceLogic.AuthControlStates.idle
            state = SurfaceLogic.authControlTransition(state, "enter-input")
            compare(state, SurfaceLogic.AuthControlStates.input)
            state = SurfaceLogic.authControlTransition(state, "auth-success")
            compare(state, SurfaceLogic.AuthControlStates.unlocked)
            state = SurfaceLogic.authControlTransition(state, "reset")
            compare(state, SurfaceLogic.AuthControlStates.idle)
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
