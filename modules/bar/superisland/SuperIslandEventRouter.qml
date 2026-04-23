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
        const interruptingDetachedHint = !nextIsHint
            && nextEvent.type !== "idle"
            && root.host._hintPhase
            && root.host._isFullHintEventType(root.state._attachedHintEvent.type)
        const overlayOwnsGeometry = IslandOverlayService.mode !== "none"
            && IslandOverlayService.state !== "closed"

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

        if (overlayOwnsGeometry) {
            root.machine.log(
                "routeActiveEvent skipped while overlay owns geometry"
                    + " next=" + nextEvent.type
                    + " prev=" + previousEvent.type,
                nextEvent
            )
            root.state._lastActiveEvent = nextEvent
            return
        }

        if (interruptingDetachedHint) {
            root.machine.finishWindowHint()
        } else if (nextEvent.presentation === "bar-expanded" && nextEvent.type === "window-hint") {
            if (previousIsHint && root.host._hintPhase)
                root.machine.updateWindowHint(nextEvent)
            else
                root.machine.startBarExpandedWindowHint(nextEvent)
        } else if (nextEvent.relayReplace && previousEvent.type !== "idle") {
            if (previousIsHint)
                root.machine.resumeTransient(nextEvent)
            else
                root.machine.replaceActiveTransient(nextEvent)
        } else if (nextIsHint && previousEvent.type === "idle") {
            root.machine.startWindowHint(nextEvent)
        } else if (nextIsHint && !previousIsHint) {
            root.machine.startWindowHint(nextEvent)
        } else if (nextIsHint && previousIsHint) {
            if (root.host._hintPhase)
                root.machine.updateWindowHint(nextEvent)
            else
                root.machine.startWindowHint(nextEvent)
        } else if (nextEvent.type !== "idle" && previousIsHint) {
            root.machine.resumeTransient(nextEvent)
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
