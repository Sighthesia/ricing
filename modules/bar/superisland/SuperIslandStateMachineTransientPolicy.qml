import QtQuick
import qs.services

// Encapsulates transient and window-hint transition strategies for the state machine.
Item {
    id: root

    required property Item host
    required property QtObject state
    required property Item machine
    required property Item timeline
    required property Item bridge

    visible: false
    width: 0
    height: 0

    function startEnterTransition(event) {
        const wasHintPhase = root.host._hintPhase
        const wasFullHintPhase = wasHintPhase
            && root.host._isFullHintEventType(root.state._attachedHintEvent.type)

        root.machine.log("startEnterTransition", event)
        if (root.host._hintPhase) {
            root.bridge.hintFlashDelayTimer.stop()
            root.timeline.hintEnterAnim.stop()
            root.timeline.hintExitAnim.stop()
            if (wasFullHintPhase) {
                root.timeline.pillThrowOutAnim.stop()
                root.timeline.pillCatchAnim.stop()
                root.state._attachedCollapseAnimating = true
                root.machine.startAttachedCollapse()
            }
            root.machine.resetTracks()
        } else if (root.state._phase !== "idle") {
            root.timeline.returnAnim.stop()
            root.timeline.departAnim.stop()
            root.state._phase = "idle"
            root.state._mainDisplayEvent = root.host._baselineEvent
            root.machine.resetTracks()
        }

        root.state._mainDisplayEvent = root.host._displayEvent(event)
        root.state._phase = "enter"

        root.timeline.returnAnim.stop()
        root.timeline.departAnim.stop()

        root.state._mainTrackY = root.host._mainTrackEnterY
        root.state._mainTrackScale = 0.92
        root.state._mainTrackOpacity = 0.15

        root.state._flashSourceEvent = root.host._idleSnapshot()
        root.state._flashTrackY = root.host._flashStripY
        root.state._flashTrackScale = root.host._flashScale
        root.state._flashTrackOpacity = 1
        root.machine.triggerSharedBackgroundPulse("hint-update")

        Qt.callLater(function() {
            root.timeline.departAnim.start()
        })
    }

    function resumeTransient(event) {
        const nextEvent = root.host._displayEvent(event)
        const wasHintPhase = root.host._hintPhase
        const wasFullHintPhase = wasHintPhase
            && root.host._isFullHintEventType(root.state._attachedHintEvent.type)

        root.machine.log("resumeTransient", nextEvent)

        root.bridge.hintFlashDelayTimer.stop()
        root.timeline.departAnim.stop()
        root.timeline.returnAnim.stop()
        root.timeline.hintEnterAnim.stop()
        root.timeline.hintExitAnim.stop()
        root.timeline.replaceAnim.stop()
        resetReplaceLayers()

        if (wasFullHintPhase) {
            root.timeline.pillThrowOutAnim.stop()
            root.timeline.pillCatchAnim.stop()
            root.state._attachedCollapseAnimating = true
            root.machine.startAttachedCollapse()
        }

        root.state._mainDisplayEvent = nextEvent
        root.state._phase = "hold"
        root.machine.resetTracks()
        root.state._flashSourceEvent = root.host._idleSnapshot()
        root.state._flashTrackY = root.host._flashStripY
        root.state._flashTrackScale = root.host._flashScale
        root.state._flashTrackOpacity = 1
    }

    function startWindowHint(event) {
        const fullHint = root.host._isFullHintEventType(event.type)
        const keepMainEvent = root.state._mainDisplayEvent.type !== "idle"
            && !root.host._isHintEventType(root.state._mainDisplayEvent.type)

        root.machine.log("startWindowHint", event)
        root.state._mainDisplayEvent = keepMainEvent
            ? root.host._cloneEvent(root.state._mainDisplayEvent)
            : root.host._baselineEvent
        root.state._attachedHintEvent = root.host._displayEvent(event)
        root.state._flashSourceEvent = root.host._idleSnapshot()
        root.state._phase = "hint"
        root.machine.syncOverlayExtensionReservation()

        root.timeline.departAnim.stop()
        root.timeline.returnAnim.stop()
        root.timeline.hintEnterAnim.stop()
        root.timeline.hintExitAnim.stop()

        root.state._mainTrackY = root.host._mainTrackCenterY
        root.state._mainTrackScale = 1
        root.state._mainTrackOpacity = 1
        root.state._flashTrackY = root.host._windowHintEntryMeta.flashRole.targetY
            - root.host._windowHintEntryMeta.flashRole.deltaY
        root.state._flashTrackScale = 0.92
        root.state._flashTrackOpacity = 0
        if (fullHint)
            root.machine.startAttachedReveal()
        root.bridge.hintFlashDelayTimer.restart()

        Qt.callLater(function() {
            root.timeline.hintEnterAnim.start()
        })
    }

    function updateWindowHint(event) {
        const previousEvent = root.state._attachedHintEvent
        const nextEvent = root.host._displayEvent(event)
        const isBarExpandedHint = nextEvent.presentation === "bar-expanded"
        root.state._attachedHintEvent = nextEvent
        if (isBarExpandedHint) {
            root.state._mainDisplayEvent = nextEvent
            root.state._phase = "hint"
            root.state._mainTrackY = root.host._mainTrackCenterY
            root.state._mainTrackScale = 1
            root.state._mainTrackOpacity = 1
            root.state._flashTrackY = root.host._flashStripY
            root.state._flashTrackScale = root.host._flashScale
            root.state._flashTrackOpacity = 1
            root.timeline.hintEnterAnim.stop()
            root.timeline.hintExitAnim.stop()
        }
        root.machine.syncOverlayExtensionReservation()

        if (root.host._detachedHintActive
                && (root.host._barExpandedHintActive
                    || root.host._attachedPanelHeight > root.state._attachedPanelRevealHeight)) {
            root.state._attachedPanelRevealHeight = root.host._attachedPanelHeight
        }

        if (root.state._overlaySessionActive || IslandOverlayService.mode !== "none")
            return

        if (_hintSwitchChanged(previousEvent, nextEvent))
            root.machine.triggerSharedBackgroundPulse("hint-switch")

        // Live window switches should retarget content without replaying entry motion.
    }

    function _hintSwitchChanged(previousEvent, nextEvent) {
        const previous = previousEvent || root.host._idleSnapshot()
        const next = nextEvent || root.host._idleSnapshot()

        return (previous.currentWindowId || "") !== (next.currentWindowId || "")
            || (previous.currentIndex !== undefined ? previous.currentIndex : -1)
                !== (next.currentIndex !== undefined ? next.currentIndex : -1)
            || (previous.workspaceId || "") !== (next.workspaceId || "")
            || (previous.workspaceIndex !== undefined ? previous.workspaceIndex : -1)
                !== (next.workspaceIndex !== undefined ? next.workspaceIndex : -1)
            || (previous.activeWorkspacePosition !== undefined ? previous.activeWorkspacePosition : -1)
                !== (next.activeWorkspacePosition !== undefined ? next.activeWorkspacePosition : -1)
    }

    function resetReplaceLayers() {
        root.state._replaceOutgoingVisible = false
        root.state._replaceIncomingVisible = false
        root.state._replaceOutgoingOpacity = 0
        root.state._replaceIncomingOpacity = 0
        root.state._replaceOutgoingTargetY = root.host._mainTrackCenterY + root.host._replaceOffset
        root.state._replaceOutgoingEvent = root.host._idleSnapshot()
        root.state._replaceIncomingEvent = root.host._idleSnapshot()
    }

    function _sameEvent(left, right) {
        const leftEvent = left || root.host._idleSnapshot()
        const rightEvent = right || root.host._idleSnapshot()

        return (leftEvent.id || "") === (rightEvent.id || "")
            && (leftEvent.type || "idle") === (rightEvent.type || "idle")
            && (leftEvent.revision || 0) === (rightEvent.revision || 0)
            && (leftEvent.title || "") === (rightEvent.title || "")
            && (leftEvent.subtitle || "") === (rightEvent.subtitle || "")
            && (leftEvent.icon || "") === (rightEvent.icon || "")
    }

    function replacePreviewTransient(event) {
        const outgoingFromIncomingLayer = root.state._replaceIncomingVisible
        const currentEvent = root.host._displayEvent(
            outgoingFromIncomingLayer ? root.state._replaceIncomingEvent : root.state._mainDisplayEvent
        )
        const nextEvent = root.host._displayEvent(event)
        const currentDisplayEvent = currentEvent.type === "idle"
            ? root.host._baselineEvent
            : currentEvent
        const nextDisplayEvent = nextEvent.type === "idle"
            ? root.host._baselineEvent
            : nextEvent
        const outgoingY = outgoingFromIncomingLayer ? root.state._replaceIncomingY : root.state._mainTrackY
        const outgoingOpacity = outgoingFromIncomingLayer
            ? root.state._replaceIncomingOpacity
            : root.state._mainTrackOpacity

        if (_sameEvent(currentDisplayEvent, nextDisplayEvent)) {
            root.state._mainDisplayEvent = nextDisplayEvent
            root.state._mainTrackY = root.host._mainTrackCenterY
            root.state._mainTrackScale = 1
            root.state._mainTrackOpacity = 1
            resetReplaceLayers()
            return
        }

        root.timeline.replaceAnim.stop()
        resetReplaceLayers()

        root.state._mainDisplayEvent = nextDisplayEvent
        root.state._replaceOutgoingEvent = currentDisplayEvent
        root.state._replaceIncomingEvent = nextDisplayEvent
        root.state._replaceOutgoingY = outgoingY
        root.state._replaceOutgoingOpacity = outgoingOpacity
        root.state._replaceOutgoingTargetY = outgoingFromIncomingLayer
            ? outgoingY
            : (root.host._mainTrackCenterY + root.host._replaceOffset)
        root.state._replaceIncomingY = root.host._mainTrackCenterY - root.host._replaceOffset
        root.state._replaceIncomingOpacity = 0
        root.state._replaceOutgoingVisible = true
        root.state._replaceIncomingVisible = true
        root.state._mainTrackY = root.host._mainTrackCenterY
        root.state._mainTrackScale = 1
        root.state._mainTrackOpacity = 0
        root.timeline.replaceAnim.start()
        root.machine.triggerSharedBackgroundPulse("preview-replace")
    }

    function replaceActiveTransient(event) {
        const outgoingEvent = root.host._cloneEvent(
            root.state._replaceIncomingVisible ? root.state._replaceIncomingEvent : root.state._mainDisplayEvent
        )
        const outgoingFromIncomingLayer = root.state._replaceIncomingVisible
        const outgoingY = root.state._replaceIncomingVisible ? root.state._replaceIncomingY : root.state._mainTrackY
        const outgoingOpacity = root.state._replaceIncomingVisible ? root.state._replaceIncomingOpacity : root.state._mainTrackOpacity
        const shouldAnimateReplace = outgoingEvent.type !== "idle"
        const nextEvent = root.host._displayEvent(event)

        root.state._mainDisplayEvent = nextEvent
        root.state._flashSourceEvent = root.host._idleSnapshot()
        root.state._flashTrackY = root.host._flashStripY
        root.state._flashTrackScale = root.host._flashScale
        root.state._flashTrackOpacity = 1

        root.timeline.departAnim.stop()
        root.timeline.returnAnim.stop()
        root.timeline.hintEnterAnim.stop()
        root.timeline.hintExitAnim.stop()
        root.timeline.replaceAnim.stop()
        resetReplaceLayers()

        root.state._phase = "hold"

        if (shouldAnimateReplace) {
            root.state._replaceOutgoingEvent = outgoingEvent
            root.state._replaceIncomingEvent = nextEvent
            root.state._replaceOutgoingY = outgoingY
            root.state._replaceOutgoingOpacity = outgoingOpacity
            root.state._replaceOutgoingTargetY = outgoingFromIncomingLayer
                ? outgoingY
                : (root.host._mainTrackCenterY + root.host._replaceOffset)
            root.state._replaceIncomingY = root.host._mainTrackCenterY - root.host._replaceOffset
            root.state._replaceIncomingOpacity = 0
            root.state._replaceOutgoingVisible = true
            root.state._replaceIncomingVisible = true

            root.state._mainTrackScale = 1
            root.state._mainTrackOpacity = 0
            root.timeline.replaceAnim.start()
        } else {
            root.state._replaceOutgoingVisible = false
            root.state._replaceIncomingVisible = false
            root.state._mainTrackScale = 1
            root.state._mainTrackY = root.host._mainTrackCenterY
            root.state._mainTrackOpacity = 1
        }

        root.machine.triggerSharedBackgroundPulse()
    }

    function triggerHintFlash() {
        root.machine.triggerSharedBackgroundPulse("hint-delay")
    }

    function finishWindowHint() {
        if (root.state._phase !== "hint")
            return

        if (root.host._isFullHintEventType(root.state._attachedHintEvent.type)
                && !root.state._overlaySessionActive) {
            root.state._attachedCollapseBaseWidth = 0
            root.host._barExpandedExitBaseWidth = Math.max(
                root.host._barExpandedExitBaseWidth,
                root.host._barExpandedHostFootprintWidth,
                root.host._attachedPanelVisibleWidth,
                root.host._barExpandedDetachedHintWidth,
                root.host._idleCollapsedWidthLive
            )
        }

        root.state._phase = "hint-exit"
        root.machine.syncOverlayExtensionReservation()
        root.timeline.hintEnterAnim.stop()
        if (root.host._isFullHintEventType(root.state._attachedHintEvent.type))
            root.machine.startAttachedCollapse()
        if (!root.host._isFullHintEventType(root.state._attachedHintEvent.type))
            root.machine.triggerEdgeReboundScale()
        root.timeline.hintExitAnim.start()
    }

    function completeWindowHintExit() {
        const pendingEvent = root.host._displayEvent(SuperIslandService.activeEvent)

        root.state._phase = "idle"
        root.state._attachedCollapseAnimating = false
        root.state._attachedHintEvent = root.host._idleSnapshot()
        root.state._flashSourceEvent = root.host._idleSnapshot()
        root.state._mainDisplayEvent = root.host._baselineEvent
        root.state._sharedBackgroundPulseOpacity = 0
        root.state._attachedPanelRevealWidth = 0
        root.state._attachedPanelRevealHeight = 0
        root.state._attachedContentOpacity = 0
        root.state._attachedCollapseBaseWidth = 0
        root.machine.resetTracks()
        root.machine.syncOverlayExtensionReservation()

        if (!root.state._overlaySessionActive
                && pendingEvent.type !== "idle"
                && !root.host._isHintEventType(pendingEvent.type))
            root.machine.resumeTransient(pendingEvent)
    }

    function startBarExpandedWindowHint(event) {
        const nextEvent = root.host._displayEvent(event)
        root.machine.log("startBarExpandedWindowHint", nextEvent)
        root.state._mainDisplayEvent = nextEvent
        root.state._attachedHintEvent = nextEvent
        root.state._phase = "hint"
        root.machine.syncOverlayExtensionReservation()
        root.state._mainTrackY = root.host._mainTrackCenterY
        root.state._mainTrackScale = 1
        root.state._mainTrackOpacity = 1
        root.state._flashSourceEvent = root.host._idleSnapshot()
        root.state._flashTrackY = root.host._flashStripY
        root.state._flashTrackScale = root.host._flashScale
        root.state._flashTrackOpacity = 1
        root.machine.triggerSharedBackgroundPulse("bar-expanded-hint-enter")
        root.machine.startAttachedReveal(undefined, undefined, false)
    }

    function startExitTransition() {
        root.machine.log("startExitTransition", root.state._mainDisplayEvent)
        root.machine.logPulse(
            "startExitTransition flash=" + root.state._flashSourceEvent.type
                + " attachedHint=" + root.state._attachedHintEvent.type
        )

        root.state._phase = "exit"

        root.timeline.departAnim.stop()
        root.timeline.returnAnim.stop()
        root.timeline.hintEnterAnim.stop()
        root.timeline.hintExitAnim.stop()
        root.machine.triggerEdgeReboundScale()

        root.state._mainTrackY = root.host._mainTrackCenterY
        root.state._mainTrackScale = 1
        root.state._mainTrackOpacity = 1
        root.state._flashTrackY = root.host._flashStripY
        root.state._flashTrackScale = root.host._flashScale
        root.state._flashTrackOpacity = 0.6

        root.timeline.returnAnim.start()
    }
}
