import QtQuick
import qs.config
import qs.services

// Event bridge for SuperIsland state machine timers and service connections.
Item {
    id: root

    required property Item host
    required property QtObject state
    required property Item machine
    required property Item timeline

    visible: false
    width: 0
    height: 0

    property alias hintFlashDelayTimer: _hintFlashDelayTimer
    property alias overlayOpenSettleTimer: _overlayOpenSettleTimer
    property alias overlayCloseSettleTimer: _overlayCloseSettleTimer
    property alias attachedRevealDelayTimer: _attachedRevealDelayTimer

    Timer {
        id: _hintFlashDelayTimer
        interval: Theme.anim.moveDuration
        repeat: false
        onTriggered: {
            root.machine.logPulse("hintFlashDelayTimer")
            if (root.state._overlaySessionActive || IslandOverlayService.mode !== "none")
                return

            if (!root.host._hintPhase || !root.host._isFullHintEventType(root.state._flashSourceEvent.type))
                return

            root.machine.triggerHintFlash()
        }
    }

    Timer {
        id: _overlayOpenSettleTimer
        interval: Theme.anim.moveDuration
        repeat: false
        onTriggered: {
            if (IslandOverlayService.mode !== "none" && IslandOverlayService.state === "opening")
                IslandOverlayService.setSettledState(IslandOverlayService.mode, "open")
        }
    }

    Timer {
        id: _overlayCloseSettleTimer
        interval: Theme.anim.moveDuration
        repeat: false
        onTriggered: {
            if (IslandOverlayService.mode !== "none" && IslandOverlayService.state === "closing")
                IslandOverlayService.setSettledState(IslandOverlayService.mode, "closed")
        }
    }

    Timer {
        id: _attachedRevealDelayTimer
        interval: root.host._pillThrowLeadDuration + root.host._pillThrowDropDuration
        repeat: false
        onTriggered: {
            if (root.host._attachedPanelActive)
                root.timeline.attachedRevealAnim.start()
        }
    }

    Connections {
        enabled: root.host._listensToService
        target: SuperIslandService

        function onMainStateChanged() {
            if (root.state._phase === "idle")
                root.state._mainDisplayEvent = root.host._baselineEvent
        }

        function onActiveEventChanged() {
            const nextEvent = root.host._displayEvent(SuperIslandService.activeEvent)
            const previousEvent = root.host._cloneEvent(root.state._lastActiveEvent)
            const nextIsHint = root.host._isHintEventType(nextEvent.type)
            const previousIsHint = root.host._isHintEventType(previousEvent.type)

            root.machine.log(
                "activeEventChanged prev=" + previousEvent.type + " next=" + nextEvent.type
                    + " phase=" + root.state._phase
                    + " overlayMode=" + IslandOverlayService.mode
                    + " overlayState=" + IslandOverlayService.state
            )

            if (nextEvent.type === "overlay" || previousEvent.type === "overlay") {
                root.state._lastActiveEvent = nextEvent.type === "overlay"
                    ? root.host._idleSnapshot()
                    : nextEvent
                return
            }

            if (nextEvent.relayReplace && previousEvent.type !== "idle") {
                if (previousIsHint)
                    root.machine.startEnterTransition(nextEvent)
                else
                    root.machine.replaceActiveTransient(nextEvent)
            } else if (nextIsHint && previousEvent.type === "idle") {
                root.machine.startWindowHint(nextEvent)
            } else if (nextIsHint && previousIsHint) {
                if (root.host._hintPhase)
                    root.machine.updateWindowHint(nextEvent)
                else
                    root.machine.startWindowHint(nextEvent)
            } else if (nextEvent.type !== "idle" && previousIsHint) {
                root.machine.startEnterTransition(nextEvent)
            } else if (nextEvent.type === "idle" && previousIsHint) {
                root.machine.finishWindowHint()
            } else if (nextEvent.type !== "idle" && previousEvent.type === "idle") {
                root.machine.startEnterTransition(nextEvent)
            } else if (nextEvent.type !== "idle" && previousEvent.type !== "idle") {
                root.machine.startEnterTransition(nextEvent)
            } else if (nextEvent.type === "idle" && previousEvent.type !== "idle") {
                root.machine.startExitTransition()
            }

            root.state._lastActiveEvent = nextEvent
        }
    }

    Connections {
        target: IslandOverlayService

        function onModePayloadChanged() {
            root.machine.syncOverlayFlags()
            root.machine.syncOverlayExtensionReservation()
        }

        function onStateChanged() {
            const previousAttachedWidth = root.host._attachedPanelVisibleWidth
            const previousAttachedHeight = root.host._attachedPanelVisibleHeight
            const wasDetachedHintActive = root.host._detachedHintActive
            const wasHintRevealSettled = root.host._hintRevealSettled

            root.machine.syncOverlayFlags()
            root.machine.syncOverlayExtensionReservation()
            root.machine.logPulse("overlayStateChanged")

            if (IslandOverlayService.state === "opening") {
                if (wasDetachedHintActive) {
                    root.state._overlayHandoffHintEvent = root.host._cloneEvent(root.state._flashSourceEvent)
                    root.state._overlayHintHandoffActive = true
                } else {
                    root.state._overlayHintHandoffActive = false
                    root.state._overlayHandoffHintEvent = root.host._idleSnapshot()
                }

                root.machine.handoffFullHintToOverlay()
                root.machine.startAttachedReveal(
                    wasDetachedHintActive
                        ? Math.max(previousAttachedWidth, root.host._attachedRevealSeedWidth)
                        : undefined,
                    wasDetachedHintActive
                        ? Math.max(previousAttachedHeight, root.host._attachedRevealSeedHeight)
                        : undefined,
                    !wasDetachedHintActive || wasHintRevealSettled
                )
                root.machine.maybeTriggerOverlayOpenPulse()
                _overlayCloseSettleTimer.stop()
                _overlayOpenSettleTimer.restart()
                return
            }

            if (IslandOverlayService.state === "closing") {
                root.machine.startAttachedCollapse()
                _overlayOpenSettleTimer.stop()
                _overlayCloseSettleTimer.restart()
                return
            }

            _overlayOpenSettleTimer.stop()
            _overlayCloseSettleTimer.stop()
        }

        function onModeChanged() {
            root.machine.syncOverlayFlags()
            root.machine.syncOverlayExtensionReservation()
        }
    }
}
