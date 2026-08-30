pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../lazerbar" as Lazer
import "./LockLogic.js" as LockLogic
import "./LockController.js" as Controller

// Own the single compositor session lock: trigger, snapshot commit, release.
Scope {
    id: root

    readonly property bool locked: sessionLock.locked
    readonly property bool preparing: _state === LockLogic.States.preparing
    property string _state: LockLogic.States.idle
    property int _requestGeneration: -1

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
    }

    // One compositor-owned lock; Quickshell creates one surface per screen.
    WlSessionLock {
        id: sessionLock

        surface: LockSurface {
            lockContext: lockContext
            snapshot: snapshot
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
    }

    // PAM success only arms the exit; release waits for the surfaces.
    Connections {
        target: lockContext
        function onUnlocked(): void {
            const next = Controller.authSuccessState(root._state)
            if (next !== null)
                root._state = next
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
