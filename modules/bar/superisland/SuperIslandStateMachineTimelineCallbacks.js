.pragma library

function ensureThrowReset(state) {
    state._pillThrowOffsetY = 0
}

function debugLog(host, state, message) {
    if (!host || !host._debugLogging)
        return

    console.log(
        "[DymicShell:SuperIslandReturn]",
        message,
        "phase=", state && state._phase ? state._phase : "",
        "flashType=", state && state._flashSourceEvent ? (state._flashSourceEvent.type || "") : "",
        "attachedHintType=", state && state._attachedHintEvent ? (state._attachedHintEvent.type || "") : "",
        "attachedBaseWidth=", state && state._attachedCollapseBaseWidth !== undefined ? Math.round(state._attachedCollapseBaseWidth) : -1,
        "overlaySessionActive=", state ? state._overlaySessionActive : false
    )
}

function debugWindowHintReturnLog(host, state, message) {
    if (!host || !host._debugLogging || typeof host._logWindowHintReturn !== "function")
        return

    host._logWindowHintReturn(message, "timeline callback", "actual-return")
}

function ensureAttachedRevealSettled(state, host) {
    if (!host._attachedPanelActive)
        return

    state._attachedPanelRevealWidth = host._attachedPanelWidth
    state._attachedPanelRevealHeight = host._attachedPanelHeight
    state._attachedContentOpacity = 1
    state._attachedRevealUseHandoffCurve = false
    state._overlayHintHandoffActive = false
    state._overlayHandoffHintEvent = host._idleSnapshot()
    host._hintRevealSettled = true
}

function resetAttachedOverlayState(state, host) {
    if (!host)
        return

    state._attachedHintEvent = host._idleSnapshot()
    state._attachedCollapseAnimating = false
    state._overlayHintHandoffActive = false
    state._overlayHandoffHintEvent = host._idleSnapshot()
    state._attachedCollapseBaseWidth = 0
    state._attachedPanelRevealWidth = 0
    state._attachedPanelRevealHeight = 0
    state._attachedContentOpacity = 0
    state._pillThrowOffsetY = 0
    host._hintRevealSettled = false
}

function maybeCompleteHintExitAfterCollapse(state, host, completeWindowHintExitFn) {
    if (state._overlaySessionActive)
        return

    debugLog(host, state, "maybeCompleteHintExitAfterCollapse")

    if (!host || !host._isFullHintEventType || !host._isFullHintEventType(state._attachedHintEvent.type)) {
        resetAttachedOverlayState(state, host)
        debugWindowHintReturnLog(host, state, "maybeCompleteHintExitAfterCollapse:resetOnly")
        return
    }

    if (state._phase !== "hint-exit")
        return

    if (typeof completeWindowHintExitFn === "function")
        completeWindowHintExitFn()
}

function completeWindowHintExit(state, host, settledMainEvent, retainedActiveEvent, resetTracksFn, syncReservationFn) {
    if (!host)
        return

    if (typeof host._releaseBarExpandedSharedClockReturnTarget === "function")
        host._releaseBarExpandedSharedClockReturnTarget()

    resetAttachedOverlayState(state, host)
    state._phase = "idle"
    state._flashSourceEvent = host._idleSnapshot()
    state._flashTrackY = host._flashStripY
    state._flashTrackScale = host._flashScale
    state._flashTrackOpacity = 0
    state._mainDisplayEvent = settledMainEvent
    state._lastActiveEvent = retainedActiveEvent.type === "idle"
        ? state._lastActiveEvent
        : retainedActiveEvent
    state._sharedBackgroundPulseOpacity = 0

    if (typeof resetTracksFn === "function")
        resetTracksFn()

    if (typeof syncReservationFn === "function")
        syncReservationFn()

    debugWindowHintReturnLog(host, state, "completeWindowHintExit:steadyStateRestored")
}

function finishReplace(state, host, resetReplaceLayersFn) {
    if (typeof resetReplaceLayersFn === "function")
        resetReplaceLayersFn()

    state._mainTrackY = host._mainTrackCenterY
    state._mainTrackOpacity = 1
}

function maybeEnterHold(state) {
    if (state._phase === "enter")
        state._phase = "hold"
}

function finishReturn(state, host) {
    var returningEvent = host._displayEvent(state._flashSourceEvent)
    var returningFromHint = typeof host._isHintEventType === "function"
        ? host._isHintEventType(returningEvent.type)
        : (returningEvent.type === "window")
    var handoffY = state._flashTrackY
    var handoffScale = state._flashTrackScale
    var handoffOpacity = state._flashTrackOpacity

    var returningToBaseline = returningFromHint || returningEvent.type === "idle"

    debugLog(
        host,
        state,
        "finishReturn returning=" + returningEvent.type + " baseline=" + returningToBaseline
    )

    state._mainDisplayEvent = returningToBaseline
        ? host._baselineEvent
        : returningEvent
    state._mainTrackY = returningToBaseline ? host._mainTrackCenterY : handoffY
    state._mainTrackScale = returningToBaseline ? 1 : handoffScale
    state._mainTrackOpacity = returningToBaseline ? 1 : handoffOpacity

    state._phase = "idle"
    state._flashSourceEvent = host._idleSnapshot()
    state._flashTrackY = host._flashStripY
    state._flashTrackScale = host._flashScale
    state._flashTrackOpacity = 0
    state._attachedCollapseBaseWidth = 0

    if (returningToBaseline && typeof host._deferPillSnapToCollapsed === "function")
        host._deferPillSnapToCollapsed()
}

function maybeCompleteHintExit(state, host, completeWindowHintExitFn) {
    if (host._isFullHintEventType(state._attachedHintEvent.type))
        return

    if (state._phase !== "hint-exit")
        return

    debugWindowHintReturnLog(host, state, "maybeCompleteHintExit:enter")

    if (typeof completeWindowHintExitFn === "function")
        completeWindowHintExitFn()
}

function clearPulseOwnerWhenIdle(state, pulseScaleRunning, sharedBackgroundPulseRunning) {
    if (!pulseScaleRunning && !sharedBackgroundPulseRunning)
        state._pulseOwner = ""
}
