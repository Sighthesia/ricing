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
    required property Item eventRouter
    required property Item overlayEventRouter

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
            root.eventRouter.routeActiveEvent(nextEvent)
        }
    }

    Connections {
        target: IslandOverlayService

        function onModePayloadChanged() {
            root.machine.syncOverlayFlags()
            root.machine.syncOverlayExtensionReservation()
        }

        function onStateChanged() {
            root.overlayEventRouter.routeOverlayStateChange()
        }

        function onModeChanged() {
            root.machine.syncOverlayFlags()
            root.machine.syncOverlayExtensionReservation()
        }
    }
}
