import QtQuick
import qs.services

// Routes overlay service state transitions to attached-panel handoff actions.
Item {
    id: root

    required property Item host
    required property QtObject state
    required property Item machine
    required property Item bridge

    visible: false
    width: 0
    height: 0

    function routeOverlayStateChange() {
        const previousAttachedWidth = root.host._attachedPanelVisibleWidth
        const previousAttachedHeight = root.host._attachedPanelVisibleHeight
        const wasDetachedHintActive = root.host._detachedHintActive
        const wasHintRevealSettled = root.host._hintRevealSettled

        root.machine.syncOverlayFlags()
        root.machine.syncOverlayExtensionReservation()
        root.machine.logPulse("overlayStateChanged")

        if (IslandOverlayService.state === "opening") {
            if (wasDetachedHintActive) {
                root.state._overlayHandoffHintEvent = root.host._cloneEvent(root.state._attachedHintEvent)
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
            root.bridge.overlayCloseSettleTimer.stop()
            root.bridge.overlayOpenSettleTimer.restart()
            return
        }

        if (IslandOverlayService.state === "closing") {
            root.machine.startAttachedCollapse()
            root.bridge.overlayOpenSettleTimer.stop()
            root.bridge.overlayCloseSettleTimer.restart()
            return
        }

        root.bridge.overlayOpenSettleTimer.stop()
        root.bridge.overlayCloseSettleTimer.stop()

        if (IslandOverlayService.state === "closed")
            root.machine.restoreTransientAfterOverlayClose()
    }
}
