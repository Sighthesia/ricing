.pragma library

// Pure decision seam shared by every launcher surface mount (production bar,
// legacy top bar, and the integration harness): maps a snapshot of the
// session/surface/coordinator state onto the next action so the session
// mirroring cannot drift between callers.

// Snapshot keys: sessionVisible, hostPhase, activeTarget, transitioning,
// pendingTarget, requestedRoute.
//
// The wave owner serves several sibling routes, so every decision is made
// against the route the caller actually asked for rather than a hard-coded
// launcher. An absent requestedRoute means "launcher", which keeps every
// launcher-only caller and its tests valid.
function openAction(state) {
    var route = requestedRoute(state)
    if (!state.sessionVisible)
        return "open-session"
    if (state.activeTarget !== route)
        return "request-coordinated-open"
    if (state.hostPhase === "opening" || state.hostPhase === "open")
        return "refocus-search"
    // Closing or desynced-closed: recall the same live instance instead of
    // letting the close finish and swallow the newest open request.
    return "reopen-host"
}

// Reaction when the session turned hidden. The session mirrors the whole wave
// owner, so a hidden session closes whichever route it was showing.
function closeAction(state) {
    var route = requestedRoute(state)
    if (state.sessionVisible)
        return "none"
    if (state.transitioning)
        return state.pendingTarget === route ? "cancel-stale-open" : "none"
    if (state.activeTarget !== route)
        return "none"
    if (state.hostPhase === "opening" || state.hostPhase === "open")
        return "request-coordinated-close"
    return "none"
}

function requestedRoute(state) {
    return state.requestedRoute == null || state.requestedRoute === ""
            ? "launcher" : String(state.requestedRoute)
}
