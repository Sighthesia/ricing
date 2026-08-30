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

// Own the single compositor session lock: trigger, snapshot commit, release.
Scope {
    id: root

    readonly property bool locked: sessionLock.locked
    readonly property bool preparing: _state === LockLogic.States.preparing
    property string _state: LockLogic.States.idle
    property int _requestGeneration: -1
    property bool _exitFailsafeArmed: false

    // Opt-in startup self-test: arm the lock on boot and force-release it on a
    // timer so the wave surface can be verified (and torn down) unattended.
    // The release bypasses PAM only while this test flag is armed; the normal
    // unlock() path is untouched.
    readonly property bool selfTestEnabled: (Quickshell.env("AFLOAT_LOCK_SELFTEST") || "").trim() === "1"
    property int selfTestDelayMs: 5000
    property bool _selfTestArmed: false

    // Lock background: the configured wallpaper by default, or a pre-lock
    // desktop screenshot via grim (AFLOAT_LOCK_BACKGROUND=screenshot). A failed
    // or missing capture falls back to the wallpaper, then to the opaque floor.
    readonly property string backgroundMode: SurfaceLogic.normalizeBackgroundMode(
        (Quickshell.env("AFLOAT_LOCK_BACKGROUND") || "").trim())
    readonly property int _screenshotTimeoutMs: 2000
    property Component _grimCapture: LockGrimCapture {}

    function lock(): bool {
        if (!Controller.canLock(_state))
            return false
        lockContext.reset()
        _state = LockLogic.States.preparing
        snapshot.request(Quickshell.screens.length)
        _requestGeneration = snapshot.generation
        _prepareFailsafe.restart()
        if (snapshot.ready)
            _commitLock()
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
            _grimCapture.createObject(root, {
                screenIndex: index,
                screenName: String(target.name || ""),
                directory: directory,
                outputPath: directory + "/afloat-lock-" + generation + "-" + index + ".png"
            }).captured.connect(report)
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
        if (!root._selfTestArmed)
            return
        root._selfTestArmed = false
        const next = Controller.testReleaseState(_state, true)
        if (next === null)
            return
        _prepareFailsafe.stop()
        _exitFailsafe.stop()
        _exitFailsafeArmed = false
        _state = next
        sessionLock.locked = false
        _requestGeneration = -1
        lockContext.reset()
        console.log("[afloat:lock] self-test lock released")
    }

    Component.onCompleted: {
        if (!root.selfTestEnabled)
            return
        root._selfTestArmed = true
        console.log("[afloat:lock] self-test lock engaged at startup")
        root.lock()
    }

    // One compositor-owned lock; Quickshell creates one surface per screen.
    WlSessionLock {
        id: sessionLock

        surface: LockSurface {
            lockContext: lockContext
            snapshot: snapshot
            backgroundMode: root.backgroundMode
            wallpaperPath: Services.SettingsService.appearance.wallpaperPath
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
            if (Controller.armExitFailsafe(previous, next))
                root._exitFailsafe.restart()
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
        interval: Lazer.MotionTokens.medium + Lazer.MotionTokens.slow
        repeat: false
        onTriggered: root._commitLock()
    }

    // Bounded fallback so a stalled exit can never hold the lock after a
    // successful authentication; it stays armed only in the exiting state.
    property Timer _exitFailsafe: Timer {
        interval: Lazer.MotionTokens.waveExit + Lazer.MotionTokens.slow
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
    property Timer _selfTestRelease: Timer {
        interval: root.selfTestDelayMs
        repeat: false
        running: root.selfTestEnabled && root._selfTestArmed
        onTriggered: root._selfTestRelease()
    }

    // Compositor keybinds reach the lock through this target.
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
