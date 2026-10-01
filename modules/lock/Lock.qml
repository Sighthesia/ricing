pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../lazerbar" as Lazer
import "../../services" as Services
import "./LockLogic.js" as LockLogic
import "./LockController.js" as Controller
import "./LockSurfaceLogic.js" as SurfaceLogic
import "./StartupLockLogic.js" as StartupLockLogic

// Own the single compositor session lock: trigger, snapshot commit, release.
Scope {
    id: root

    readonly property bool locked: sessionLock.locked
    readonly property bool preparing: _state === LockLogic.States.preparing
    property string _state: LockLogic.States.idle
    property int _requestGeneration: -1
    property bool _exitFailsafeArmed: false
    property bool _startupLockArmed: true
    // The startup auto-lock is a per-compositor-session event, not a per-shell
    // event: a Quickshell reload must never re-lock a desktop that was already
    // unlocked. The marker file records the session key that consumed it.
    readonly property string _startupSessionKey: StartupLockLogic.sessionKey(
        Quickshell.env("NIRI_SOCKET"), Quickshell.env("XDG_SESSION_ID"))
    property bool _startupGateResolved: false

    // Opt-in startup self-test: arm the lock on boot and force-release it on a
    // timer so the wave surface can be verified (and torn down) unattended.
    // The release bypasses PAM only while this test flag is armed; the normal
    // unlock() path is untouched.
    readonly property bool selfTestEnabled: (Quickshell.env("AFLOAT_LOCK_SELFTEST") || "").trim() === "1"
    property string wallpaperPath: selfTestEnabled
            ? Quickshell.env("AFLOAT_LOCK_WALLPAPER") || ""
            : String(Services.SettingsService.appearance.wallpaperPath || "")
    property int selfTestDelayMs: 5000
    property bool _selfTestArmed: false
    signal selfTestFinished()

    // Lock background order: a pre-lock desktop screenshot (grim) is painted
    // as the base, then the wave mask sweeps the wallpaper over it. Setting
    // AFLOAT_LOCK_BACKGROUND=wallpaper skips the capture and reveals the
    // wallpaper over the opaque floor instead.
    //
    // `configuredBackgroundMode` is that environment default. `backgroundMode` is
    // what the request being prepared actually uses: the session-start lock
    // overrides it, because at that point there is no finished desktop to
    // capture (see StartupLockLogic.backgroundModeFor).
    readonly property string configuredBackgroundMode: SurfaceLogic.normalizeBackgroundMode(
        (Quickshell.env("AFLOAT_LOCK_BACKGROUND") || "").trim())
    property string backgroundMode: root.configuredBackgroundMode
    readonly property int _screenshotTimeoutMs: 2000
    property Component _grimCapture: LockGrimCapture {}
    property var _snapshotImages: []
    property Component _snapshotImage: Image {
        visible: false
        asynchronous: false
        cache: true
    }

    function _prepareCapturedImage(generation, report, index, url): void {
        if (generation !== snapshot.generation || snapshot.ready || !root.preparing)
            return
        if (!url) {
            report(index, "")
            return
        }
        const image = _snapshotImage.createObject(root, { source: url }) as Image
        if (!image) {
            report(index, "")
            return
        }
        root._snapshotImages.push(image)
        report(index, image.status === Image.Ready ? url : "")
    }

    // Begin a lock. `startup` marks the session-start auto-lock, which reveals
    // the wallpaper instead of capturing a desktop that has not finished
    // assembling; every other request keeps the configured capture.
    function lock(startup: bool): bool {
        if (!Controller.canLock(_state))
            return false
        backgroundMode = StartupLockLogic.backgroundModeFor(
            configuredBackgroundMode, startup === true)
        lockContext.reset()
        for (const image of root._snapshotImages)
            image.destroy()
        root._snapshotImages = []
        _state = LockLogic.States.preparing
        snapshot.request(Quickshell.screens.length)
        _requestGeneration = snapshot.generation
        _prepareFailsafe.restart()
        if (snapshot.ready)
            _commitLock()
        return true
    }

    // Request the compositor lock once per niri session, after the shell has
    // discovered a screen. The marker gate resolves first so a shell reload
    // inside an already-used session never locks again.
    //
    // This is the session's first screen: the shell runs it from the bootstrap
    // layer, before the wallpaper reveal has settled and before any chrome
    // exists, so there is no finished desktop to capture. The lock surface
    // unveils the wallpaper itself instead.
    function startupLock(): bool {
        if (_startupSessionKey.length > 0 && !_startupGateResolved) {
            startupLockTimer.restart()
            return false
        }
        if (!StartupLockLogic.canAttempt(_state, _startupLockArmed,
                                         Quickshell.screens.length > 0)) {
            if (_startupLockArmed && Quickshell.screens.length <= 0)
                startupLockTimer.restart()
            else if (_startupLockArmed && _state !== LockLogic.States.idle)
                _startupLockArmed = false
            return false
        }
        const accepted = root.lock(true)
        const result = StartupLockLogic.nextAttempt(
            _startupLockArmed, Quickshell.screens.length > 0, _state, accepted)
        _startupLockArmed = result.armed
        if (result.retry)
            startupLockTimer.restart()
        if (accepted)
            _consumeStartupSession()
        return accepted
    }

    // Adopt the persisted marker: a matching key means this session already
    // spent its one automatic lock, so disarm before any request is made.
    function _resolveStartupGate(markerText: string): void {
        _startupGateResolved = true
        if (_startupSessionKey.length === 0)
            return
        if (StartupLockLogic.markerMatches(markerText, _startupSessionKey))
            _startupLockArmed = false
    }

    // Record the session key only after a request was accepted, so a rejected
    // startup attempt stays retryable within the same shell lifetime.
    function _consumeStartupSession(): void {
        if (_startupSessionKey.length === 0)
            return
        _startupMarker.setText(_startupSessionKey)
    }

    // Return to the lock prompt without disturbing an active PAM conversation.
    function requestSessionLock(): bool {
        if (Controller.canLock(_state))
            return root.lock()
        if (_state !== LockLogic.States.locked || lockContext.unlockInProgress)
            return false
        lockContext.reset()
        return true
    }

    function unlock(): bool {
        // The external unlock entry never releases the session lock: it may
        // only present a clean authentication prompt or cancel a pending
        // preparation. PAM success on the lock surface is the sole release path.
        const action = Controller.unlockAction(_state, lockContext.unlockInProgress)
        if (action === Controller.UnlockActions.resetAuth) {
            lockContext.reset()
            return true
        }
        if (action === Controller.UnlockActions.cancelPreparation) {
            _cancelPreparation()
            return true
        }
        return false
    }

    function isLocked(): bool {
        return locked
    }

    function _commitLock(): void {
        const next = Controller.commitState(_state)
        if (next === null)
            return
        _prepareFailsafe.stop()
        _state = next
        sessionLock.locked = true
    }

    // Screenshot provider seam: one grim capture per screen index; the shared
    // snapshot ignores late or stale reports and falls back to the wallpaper.
    function _grimProvider(_screen, screenCount, generation, report): var {
        const runtimeRoot = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp").replace(/\/+$/, "")
        const directory = runtimeRoot + "/afloat-lock"
        for (let index = 0; index < screenCount; ++index) {
            const target = Quickshell.screens[index]
            if (!target)
                continue
            const capture = _grimCapture.createObject(root, {
                screenIndex: index,
                screenName: String(target.name || ""),
                directory: directory,
                outputPath: directory + "/afloat-lock-" + generation + "-" + index + ".jpg"
            }) as LockGrimCapture
            capture.captured.connect(function(screenIndex, url) {
                root._prepareCapturedImage(generation, report, screenIndex, url)
            })
        }
        return { ready: false }
    }

    function _cancelPreparation(): void {
        _prepareFailsafe.stop()
        _state = LockLogic.States.idle
        _requestGeneration = -1
    }

    function _finishRelease(): void {
        const next = Controller.releaseState(_state)
        if (next === null)
            return
        _state = next
        sessionLock.locked = false
        _requestGeneration = -1
        _exitFailsafe.stop()
        _exitFailsafeArmed = false
    }

    // Self-test release: bypasses PAM strictly while the startup test is
    // armed; arming happens only in Component.onCompleted below.
    function _selfTestRelease(): void {
        if (!root.selfTestEnabled || !root._selfTestArmed)
            return
        startupSelfTestTimer.stop()
        _selfTestTimer.stop()
        if (_state === LockLogic.States.preparing)
            _cancelPreparation()
        else if (_state === LockLogic.States.exiting)
            _finishRelease()
        else {
            const next = Controller.testReleaseState(_state, true)
            if (next !== null) {
                _state = next
                sessionLock.locked = false
            }
        }
        if (sessionLock.locked)
            return
        root._selfTestArmed = false
        _prepareFailsafe.stop()
        _exitFailsafe.stop()
        _exitFailsafeArmed = false
        _requestGeneration = -1
        lockContext.reset()
        console.log("[afloat:lock] self-test lock released")
        root.selfTestFinished()
    }

    Component.onCompleted: {
        if (!root.selfTestEnabled)
            return
        root._selfTestArmed = true
        startupSelfTestTimer.start()
    }

    // Wait for the compositor's screen list instead of submitting an empty lock.
    property Timer startupLockTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: root.startupLock()
    }

    // Persisted record of which compositor session already auto-locked once.
    // A missing file is the normal first-run state and arms the lock.
    property FileView _startupMarker: FileView {
        path: Quickshell.cacheDir + "/startup-lock-session"
        blockLoading: true
        watchChanges: false
        onLoaded: root._resolveStartupGate(_startupMarker.text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("Lock: failed to read startup-lock-session:", error)
            root._resolveStartupGate("")
        }
    }

    // One compositor-owned lock; Quickshell creates one surface per screen.
    WlSessionLock {
        id: sessionLock

        surface: LockSurface {
            lockContext: lockContext
            snapshot: snapshot
            wallpaperPath: root.wallpaperPath
            captureExpected: root.backgroundMode === SurfaceLogic.backgroundModes.screenshot
            onReleaseRequested: root._finishRelease()
        }
    }

    // Password conversation shared by every lock surface.
    LockContext {
        id: lockContext
    }

    // Desktop snapshot prepared before the session lock commits.
    LockSnapshot {
        id: snapshot
        fallbackIntervalMs: root.backgroundMode === SurfaceLogic.backgroundModes.screenshot
                ? root._screenshotTimeoutMs : Lazer.MotionTokens.medium
        snapshotProvider: root.backgroundMode === SurfaceLogic.backgroundModes.screenshot
                ? root._grimProvider : null
    }

    // PAM success only arms the exit; release waits for the surfaces.
    Connections {
        target: lockContext
        function onUnlocked(): void {
            const previous = root._state
            const next = Controller.authSuccessState(root._state)
            if (next === null)
                return
            root._state = next
            // A stalled exit animation must never hold the compositor lock
            // forever, so successful authentication bounds it with a timer.
            if (Controller.armExitFailsafe(previous, next)) {
                root._exitFailsafeArmed = true
                root._exitFailsafe.restart()
            }
        }
    }

    // Session-menu Lock requests share the normal manual lock state machine.
    Connections {
        target: Services.SessionService
        function onLockRequested(): void {
            root.requestSessionLock()
        }
    }

    // Commit the pending request when its snapshot generation reports ready.
    Connections {
        target: snapshot
        function onPrepared(generation): void {
            if (Controller.shouldCommit(root._requestGeneration, generation))
                root._commitLock()
        }
    }

    // Bounded fallback so a silent snapshot provider can never block locking.
    property Timer _prepareFailsafe: Timer {
        interval: Controller.prepareFailsafeInterval(
                      root.backgroundMode, SurfaceLogic.backgroundModes,
                      root._screenshotTimeoutMs,
                      Lazer.MotionTokens.medium + Lazer.MotionTokens.slow)
        repeat: false
        onTriggered: root._commitLock()
    }

    // Bounded fallback so a stalled exit can never hold the lock after a
    // successful authentication; it stays armed only in the exiting state. The
    // budget covers the whole unlock choreography — unlock feedback, the
    // control collapse, the content fall, then the wave sweep — plus a margin.
    property Timer _exitFailsafe: Timer {
        interval: Lazer.MotionTokens.medium + Lazer.MotionTokens.instant
                  + Lazer.MotionTokens.lockContentFall
                  + Lazer.MotionTokens.waveExit
                  + Lazer.MotionTokens.slow
        repeat: false
        onTriggered: {
            if (!Controller.exitFailsafeShouldRelease(root._state, root._exitFailsafeArmed))
                return
            root._exitFailsafeArmed = false
            root._finishRelease()
        }
    }

    // Self-test teardown: releases and kills the lock instance after the
    // configured delay so unattended runs never stay locked.
    property Timer _selfTestTimer: Timer {
        interval: root.selfTestDelayMs
        repeat: false
        running: root.selfTestEnabled && root._selfTestArmed
        onTriggered: root._selfTestRelease()
    }

    // Screen objects may not be populated during Component.onCompleted. Wait
    // for them before requesting captures, otherwise generation zero would
    // lock without a screenshot and the user would only see the wallpaper.
    property Timer startupSelfTestTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: {
            if (Quickshell.screens.length <= 0) {
                restart()
                return
            }
            if (root.lock()) {
                console.log("[afloat:lock] self-test lock engaged at startup")
            } else if (root._selfTestArmed) {
                restart()
            }
        }
    }

    // Compositor keybinds and the launcher's lock item reach the session
    // through this target.
    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock()
        }

        function unlock(): void {
            root.unlock()
        }

        function isLocked(): bool {
            return root.isLocked()
        }
    }
}
