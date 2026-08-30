.pragma library
.import "LockLogic.js" as LockLogic

// Actions an unlock request is allowed to trigger. None of them release the
// session lock: a successful PAM conversation on the lock surface remains the
// only path that ever clears the compositor lock.
var UnlockActions = {
    none: "none",
    resetAuth: "reset-auth",
    cancelPreparation: "cancel-preparation"
}

// A lock request may only start from the idle state; locked, preparing and
// exiting sessions all reject duplicate requests.
function canLock(state) {
    return state === LockLogic.States.idle
}

// A prepared snapshot may commit only when it still belongs to the active
// request generation; stale reports never flip the session lock.
function shouldCommit(requestGeneration, preparedGeneration) {
    return requestGeneration >= 0 && preparedGeneration === requestGeneration
}

// State reached when the matching snapshot generation was prepared.
function commitState(state) {
    if (state !== LockLogic.States.preparing)
        return null
    return LockLogic.nextState(state, "prepare-ready")
}

// State reached when PAM reports success; the lock stays held until the
// surfaces finish their exit animation.
function authSuccessState(state) {
    if (state !== LockLogic.States.locked)
        return null
    return LockLogic.nextState(state, "auth-success")
}

// State reached when the surfaces report their completed exit animation.
function releaseState(state) {
    if (state !== LockLogic.States.exiting)
        return null
    return LockLogic.nextState(state, "exit-finished")
}

// Decide what an unlock request may do: reset the authentication presentation
// while locked, or cancel a preparation that never committed. It must never
// release the session lock itself.
function unlockAction(state, authInProgress) {
    if (state === LockLogic.States.locked)
        return authInProgress ? UnlockActions.none : UnlockActions.resetAuth
    if (state === LockLogic.States.preparing)
        return UnlockActions.cancelPreparation
    return UnlockActions.none
}
