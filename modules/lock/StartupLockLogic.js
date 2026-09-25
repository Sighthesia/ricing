.pragma library

function canAttempt(state, armed, screensReady) {
    return armed === true && screensReady === true && state === "idle"
}

function nextAttempt(armed, screensReady, state, lockResult) {
    if (lockResult === true)
        return { armed: false, retry: false }
    if (armed !== true || state !== "idle")
        return { armed: false, retry: false }
    if (screensReady !== true)
        return { armed: true, retry: true }
    return { armed: false, retry: false }
}
