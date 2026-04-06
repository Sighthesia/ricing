.pragma library

function ensureThrowReset(state) {
    state._pillThrowOffsetY = 0
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
}

function maybeCompleteHintExitAfterCollapse(state, completeWindowHintExitFn) {
    if (state._phase !== "hint-exit" || state._overlaySessionActive)
        return

    if (typeof completeWindowHintExitFn === "function")
        completeWindowHintExitFn()
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
    var returningFromWindowHint = returningEvent.type === "window"
    var handoffY = state._flashTrackY
    var handoffScale = state._flashTrackScale
    var handoffOpacity = state._flashTrackOpacity

    state._mainDisplayEvent = returningFromWindowHint
        ? host._baselineEvent
        : (returningEvent.type !== "idle" ? returningEvent : host._baselineEvent)
    state._mainTrackY = returningFromWindowHint ? host._mainTrackCenterY : handoffY
    state._mainTrackScale = returningFromWindowHint ? 1 : handoffScale
    state._mainTrackOpacity = returningFromWindowHint ? 1 : handoffOpacity
    state._phase = "idle"
    state._flashSourceEvent = host._idleSnapshot()
    state._flashTrackY = host._flashStripY
    state._flashTrackScale = host._flashScale
    state._flashTrackOpacity = 0
}

function maybeCompleteHintExit(state, host, completeWindowHintExitFn) {
    if (host._isFullHintEventType(state._flashSourceEvent.type))
        return

    if (typeof completeWindowHintExitFn === "function")
        completeWindowHintExitFn()
}

function clearPulseOwnerWhenIdle(state, pulseScaleRunning, sharedBackgroundPulseRunning) {
    if (!pulseScaleRunning && !sharedBackgroundPulseRunning)
        state._pulseOwner = ""
}
