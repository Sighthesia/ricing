import QtQuick
import QtTest
import "../../modules/lock/LockLogic.js" as LockLogic
import "../../modules/lock/LockController.js" as Controller
import "../../modules/lazerbar" as Lazer

// Exercise the lock controller contract through the production decision seam
// and the production snapshot component, without the Quickshell/Wayland plugins.
Item {
    id: harness

    // Stub for the single WlSessionLock owned by the production controller.
    property bool sessionLockLocked: false

    readonly property bool locked: sessionLockLocked
    readonly property bool preparing: _state === LockLogic.States.preparing
    property string _state: LockLogic.States.idle
    property int _requestGeneration: -1
    property bool _authInProgress: false
    property bool _exitFailsafeArmed: false
    property int authResets: 0
    property var snapshot: null

    function lock(): bool {
        if (!Controller.canLock(_state))
            return false
        authResets = 0
        _state = LockLogic.States.preparing
        snapshot.request(1)
        _requestGeneration = snapshot.generation
        _prepareFailsafe.restart()
        if (snapshot.ready)
            _commitLock()
        return true
    }

    function unlock(): bool {
        const action = Controller.unlockAction(_state, _authInProgress)
        if (action === Controller.UnlockActions.resetAuth) {
            authResets += 1
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
        sessionLockLocked = true
    }

    function _cancelPreparation(): void {
        _prepareFailsafe.stop()
        _state = LockLogic.States.idle
        _requestGeneration = -1
    }

    function _authSuccess(): void {
        const previous = _state
        const next = Controller.authSuccessState(_state)
        if (next === null)
            return
        _state = next
        if (Controller.armExitFailsafe(previous, next)) {
            _exitFailsafeArmed = true
            harness._exitFailsafe.restart()
        }
    }

    function _finishRelease(): void {
        const next = Controller.releaseState(_state)
        if (next === null)
            return
        _state = next
        sessionLockLocked = false
        _requestGeneration = -1
        _exitFailsafeArmed = false
        _exitFailsafe.stop()
    }

    // Commit the pending request when its snapshot generation reports ready.
    Connections {
        id: snapshotConnections
        target: harness.snapshot
        function onPrepared(generation) {
            if (Controller.shouldCommit(harness._requestGeneration, generation))
                harness._commitLock()
        }
    }

    // Bounded fallback so a silent snapshot provider can never block locking.
    property Timer _prepareFailsafe: Timer {
        interval: Lazer.MotionTokens.medium + Lazer.MotionTokens.slow
        repeat: false
        onTriggered: harness._commitLock()
    }

    // Bounded fallback so a stalled exit can never hold the lock after a
    // successful authentication; it stays armed only in the exiting state.
    property Timer _exitFailsafe: Timer {
        interval: Lazer.MotionTokens.waveExit + Lazer.MotionTokens.slow
        repeat: false
        onTriggered: {
            if (!Controller.exitFailsafeShouldRelease(harness._state, harness._exitFailsafeArmed))
                return
            harness._exitFailsafeArmed = false
            harness._finishRelease()
        }
    }

    TestCase {
        name: "LockController"
        when: windowShown

        property var snapshot: null
        property int preparedSignals: 0
        property var lastCallback: null

        function init() {
            var component = Qt.createComponent(Qt.resolvedUrl("../../modules/lock/LockSnapshot.qml"))
            verify(component.status === Component.Ready, component.errorString())
            snapshot = component.createObject(harness)
            verify(snapshot !== null)
            preparedSignals = 0
            lastCallback = null
            snapshot.prepared.connect(function(generation) { preparedSignals += 1 })
            snapshotConnections.target = snapshot
            harness.snapshot = snapshot
            harness.sessionLockLocked = false
            harness._state = LockLogic.States.idle
            harness._requestGeneration = -1
            harness._authInProgress = false
            harness.authResets = 0
            harness._exitFailsafeArmed = false
        }

        function cleanup() {
            snapshotConnections.target = null
            snapshotConnections.enabled = true
            harness.snapshot = null
            if (snapshot)
                snapshot.destroy()
            snapshot = null
        }

        function test_seamUnlockActionsNeverReleaseTheLock() {
            compare(Controller.unlockAction(LockLogic.States.locked, false),
                    Controller.UnlockActions.resetAuth)
            compare(Controller.unlockAction(LockLogic.States.locked, true),
                    Controller.UnlockActions.none)
            compare(Controller.unlockAction(LockLogic.States.preparing, false),
                    Controller.UnlockActions.cancelPreparation)
            compare(Controller.unlockAction(LockLogic.States.exiting, false),
                    Controller.UnlockActions.none)
            compare(Controller.unlockAction(LockLogic.States.idle, false),
                    Controller.UnlockActions.none)
        }

        function test_seamGenerationGate() {
            verify(Controller.shouldCommit(3, 3))
            verify(!Controller.shouldCommit(3, 4))
            verify(!Controller.shouldCommit(-1, -1))
            verify(!Controller.canLock(LockLogic.States.locked))
            verify(!Controller.canLock(LockLogic.States.preparing))
            verify(!Controller.canLock(LockLogic.States.exiting))
            verify(Controller.canLock(LockLogic.States.idle))
        }

        function test_duplicateLockRejectedWhilePreparingAndLocked() {
            snapshot.snapshotProvider = function(screen, count, generation, report) {
                lastCallback = report
                return { ready: false }
            }
            verify(harness.lock())
            verify(harness.preparing)
            verify(!harness.lock())
            harness.unlock()
            verify(!harness.preparing)
            verify(!harness.locked)

            snapshot.snapshotProvider = function() { return { ready: true } }
            verify(harness.lock())
            tryCompare(harness, "locked", true)
            verify(!harness.lock())
            compare(harness.preparing, false)
        }

        function test_preparedSnapshotCommitsSessionLock() {
            snapshot.snapshotProvider = function() { return { ready: true } }
            verify(harness.lock())
            compare(harness.locked, true)
            compare(harness.isLocked(), true)
            compare(harness.sessionLockLocked, true)
            compare(harness.preparing, false)
            compare(preparedSignals, 1)
        }

        function test_asyncSnapshotReportCommitsThroughSignal() {
            snapshot.snapshotProvider = function(screen, count, generation, report) {
                lastCallback = report
                return { ready: false }
            }
            verify(harness.lock())
            verify(!harness.locked)
            verify(harness.preparing)
            lastCallback(0, "desk.png")
            tryCompare(harness, "locked", true)
            compare(harness.sessionLockLocked, true)
            compare(preparedSignals, 1)
        }

        function test_staleGenerationCannotCommitAfterCancel() {
            snapshot.snapshotProvider = function(screen, count, generation, report) {
                lastCallback = report
                return { ready: false }
            }
            verify(harness.lock())
            verify(harness.unlock())
            compare(harness.locked, false)
            compare(harness.sessionLockLocked, false)
            lastCallback(0, "late.png")
            compare(harness.locked, false)
            compare(harness.sessionLockLocked, false)
            compare(harness.preparing, false)
        }

        function test_unlockDoesNotClearLockedState() {
            snapshot.snapshotProvider = function() { return { ready: true } }
            verify(harness.lock())
            compare(harness.locked, true)
            verify(harness.unlock())
            compare(harness.locked, true)
            compare(harness.sessionLockLocked, true)
            compare(harness._state, LockLogic.States.locked)
            compare(harness.authResets, 1)
        }

        function test_unlockDoesNotAbortRunningAuthentication() {
            snapshot.snapshotProvider = function() { return { ready: true } }
            verify(harness.lock())
            compare(harness.locked, true)
            harness._authInProgress = true
            verify(!harness.unlock())
            compare(harness.locked, true)
            compare(harness.sessionLockLocked, true)
            compare(harness.authResets, 0)
            harness._authInProgress = false
        }

        function test_releaseOnlyFollowsAuthSuccessAndExit() {
            snapshot.snapshotProvider = function() { return { ready: true } }
            verify(harness.lock())
            compare(harness.locked, true)

            // A release report without a prior auth success must be ignored.
            harness._finishRelease()
            compare(harness.locked, true)
            compare(harness.sessionLockLocked, true)

            harness._authSuccess()
            compare(harness._state, LockLogic.States.exiting)
            compare(harness.locked, true)

            harness._finishRelease()
            compare(harness._state, LockLogic.States.idle)
            compare(harness.locked, false)
            compare(harness.sessionLockLocked, false)

            // A duplicate release report after returning to idle is a no-op.
            harness._finishRelease()
            compare(harness._state, LockLogic.States.idle)

            // The controller can lock again after a completed release.
            verify(harness.lock())
            compare(harness.locked, true)
            compare(harness.sessionLockLocked, true)
        }

        function test_failsafeCommitsWhenSnapshotNeverReports() {
            snapshotConnections.enabled = false
            snapshot.snapshotProvider = function() { return { ready: false } }
            verify(harness.lock())
            verify(!harness.locked)
            tryCompare(harness, "sessionLockLocked", true, 1200)
            compare(harness.locked, true)
            compare(harness.preparing, false)
        }

        function test_seamExitFailsafeArmsOnlyAfterAuthSuccess() {
            verify(Controller.armExitFailsafe(LockLogic.States.locked,
                                              LockLogic.States.exiting))
            verify(!Controller.armExitFailsafe(LockLogic.States.idle,
                                               LockLogic.States.exiting))
            verify(!Controller.armExitFailsafe(LockLogic.States.locked,
                                               LockLogic.States.locked))
            verify(!Controller.armExitFailsafe(LockLogic.States.exiting,
                                               LockLogic.States.idle))
        }

        function test_seamExitFailsafeReleasesOnlyArmedExiting() {
            verify(Controller.exitFailsafeShouldRelease(LockLogic.States.exiting, true))
            verify(!Controller.exitFailsafeShouldRelease(LockLogic.States.exiting, false))
            verify(!Controller.exitFailsafeShouldRelease(LockLogic.States.locked, true))
            verify(!Controller.exitFailsafeShouldRelease(LockLogic.States.idle, true))
            verify(!Controller.exitFailsafeShouldRelease(LockLogic.States.preparing, true))
        }

        function test_exitFailsafeReleasesStalledExitAfterAuthSuccess() {
            snapshot.snapshotProvider = function() { return { ready: true } }
            verify(harness.lock())
            compare(harness.locked, true)

            // Successful authentication arms the bounded exit failsafe.
            harness._authSuccess()
            compare(harness._state, LockLogic.States.exiting)
            compare(harness._exitFailsafeArmed, true)

            // With no surface exit ever reported, the failsafe must still
            // release the compositor lock within its bound.
            tryCompare(harness, "sessionLockLocked", false, 1500)
            compare(harness._state, LockLogic.States.idle)
            compare(harness._exitFailsafeArmed, false)
        }

        function test_exitFailsafeDisarmsWhenSurfaceExitFinishesFirst() {
            snapshot.snapshotProvider = function() { return { ready: true } }
            verify(harness.lock())
            harness._authSuccess()
            compare(harness._exitFailsafeArmed, true)

            // The normal surface path releases and disarms before the bound.
            harness._finishRelease()
            compare(harness._state, LockLogic.States.idle)
            compare(harness._exitFailsafeArmed, false)

            // A later failsafe firing must be a guarded no-op.
            harness._exitFailsafe.restart()
            tryCompare(harness, "_exitFailsafeArmed", false, 100)
            compare(harness._state, LockLogic.States.idle)
            compare(harness.locked, false)
        }

        function test_exitFailsafeNeverReleasesWithoutAuthSuccess() {
            snapshot.snapshotProvider = function() { return { ready: true } }
            verify(harness.lock())
            compare(harness.locked, true)

            // Without a successful conversation nothing may release the
            // lock, no matter what the failsafe timer observes.
            verify(!harness._exitFailsafeArmed)
            harness._exitFailsafe.restart()
            wait(Lazer.MotionTokens.waveExit + Lazer.MotionTokens.slow + 100)
            compare(harness.locked, true)
            compare(harness.sessionLockLocked, true)
            compare(harness._state, LockLogic.States.locked)
        }
    }
}
