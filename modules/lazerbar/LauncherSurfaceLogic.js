.pragma library

// Pure decision seam shared by every launcher surface mount (production bar,
// legacy top bar, and the integration harness): maps a snapshot of the
// session/surface/coordinator state onto the next action so the session
// mirroring cannot drift between callers.

// Snapshot keys: sessionVisible, hostPhase, activeTarget, transitioning,
// pendingTarget.
function openAction(state) {
    if (!state.sessionVisible)
        return "open-session"
    if (state.activeTarget !== "launcher")
        return "request-coordinated-open"
    if (state.hostPhase === "opening" || state.hostPhase === "open")
        return "refocus-search"
    // Closing or desynced-closed: recall the same live instance instead of
    // letting the close finish and swallow the newest open request.
    return "reopen-host"
}

// Reaction when the session turned hidden.
function closeAction(state) {
    if (state.sessionVisible)
        return "none"
    if (state.transitioning)
        return state.pendingTarget === "launcher" ? "cancel-stale-open" : "none"
    if (state.activeTarget !== "launcher")
        return "none"
    if (state.hostPhase === "opening" || state.hostPhase === "open")
        return "request-coordinated-close"
    return "none"
}
