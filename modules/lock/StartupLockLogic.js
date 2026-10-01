.pragma library
.import "LockSurfaceLogic.js" as SurfaceLogic

function canAttempt(state, armed, screensReady) {
    return armed === true && screensReady === true && state === "idle"
}

// Identify the compositor session the shell was started from. NIRI_SOCKET is
// regenerated on every niri start, so a new niri re-arms the startup lock while
// a Quickshell reload inside the same niri keeps the marker match.
function sessionKey(niriSocket, xdgSessionId) {
    var socket = String(niriSocket === undefined || niriSocket === null ? "" : niriSocket).trim()
    if (socket.length > 0)
        return socket
    return String(xdgSessionId === undefined || xdgSessionId === null ? "" : xdgSessionId).trim()
}

// A marker equal to the current key means this session already auto-locked.
function markerMatches(markerText, key) {
    var wanted = String(key === undefined || key === null ? "" : key).trim()
    if (wanted.length === 0)
        return false
    return String(markerText === undefined || markerText === null ? "" : markerText).trim() === wanted
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

// Which background a lock request prepares.
//
// The screenshot exists to keep visual continuity with the desktop the user was
// just looking at. The session-start lock has no such desktop: it engages before
// the chrome is built, while the wallpaper reveal is still running, so a capture
// can only ever record a half-assembled frame — and the lock surface unveils the
// wallpaper itself, which that frame would then contradict. The startup request
// therefore skips the capture. Every other request keeps the configured mode, so
// a mid-session lock still recedes from the desktop it interrupted.
function backgroundModeFor(configuredMode, startup) {
    return startup === true
        ? SurfaceLogic.backgroundModes.wallpaper
        : configuredMode
}
