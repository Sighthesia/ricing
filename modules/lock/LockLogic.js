.pragma library

var States = {
    idle: "idle",
    preparing: "preparing",
    locked: "locked",
    exiting: "exiting"
}

function canStart(isLocked, isPreparing) {
    return !isLocked && !isPreparing
}

function nextState(state, event) {
    if (event === "prepare-ready")
        return States.locked
    if (event === "auth-success")
        return States.exiting
    if (event === "exit-finished")
        return States.idle
    return state
}

function shouldReleaseLock(state, animationFinished) {
    return state === States.exiting && animationFinished === true
}

function failureTransition(failureReported, currentMessage, nextMessage) {
    var message = currentMessage || ""
    var candidate = nextMessage || ""
    if (!message && candidate)
        message = candidate
    return {
        failureReported: true,
        message: message,
        shouldNotify: failureReported !== true,
    }
}
