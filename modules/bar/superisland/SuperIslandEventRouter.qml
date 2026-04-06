import QtQuick
import qs.services

// Routes normalized SuperIsland active-event transitions to state-machine actions.
Item {
    id: root

    required property Item host
    required property QtObject state
    required property Item machine

    visible: false
    width: 0
    height: 0

    function routeActiveEvent(nextEvent) {
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
