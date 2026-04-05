import QtQuick
import qs.services

// Encapsulates overlay handoff and attached-panel reveal/collapse strategies.
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

    function syncOverlayFlags() {
        const overlayModeActive = IslandOverlayService.mode !== "none"
        const wasOverlayExpandedActive = root.state._overlayExpandedActive
        root.state._overlaySessionActive = overlayModeActive
            && IslandOverlayService.state !== "closed"
        root.state._overlayExpandedActive = overlayModeActive
            && (IslandOverlayService.state === "opening" || IslandOverlayService.state === "open")

        if (!wasOverlayExpandedActive && root.state._overlayExpandedActive)
            root.state._overlayPulsePending = true

        if (!root.state._overlaySessionActive)
            root.state._overlayPulsePending = false

        if (!root.state._overlaySessionActive) {
            root.state._overlayHintHandoffActive = false
            root.state._overlayHandoffHintEvent = root.host._idleSnapshot()
        }

        if (overlayModeActive)
            root.bridge.hintFlashDelayTimer.stop()
    }

    function syncOverlayExtensionReservation() {
        if (!root.host.liveInstance)
            return

        const reservedHeight = root.state._overlaySessionActive || root.host._detachedHintActive
            ? root.host._overlayReservedExtension
            : 0

        if (root.host._attachedPanelActive) {
            BarLayoutService.setTransientExtension("super-island-overlay", reservedHeight)
            return
        }

        BarLayoutService.clearTransientExtension("super-island-overlay")
    }

    function startAttachedReveal(fromWidth, fromHeight, withThrowKick) {
        if (!root.host._attachedPanelActive)
            return

        const shouldThrowKick = withThrowKick !== false
        const preservingThrowMotion = !shouldThrowKick && root.timeline.pillThrowOutAnim.running
        const preserveVisibleContent = !shouldThrowKick
            && (root.state._attachedContentOpacity > 0 || root.timeline.attachedRevealAnim.running)
        const immediateRevealWithThrow = shouldThrowKick
            && (root.state._attachedContentOpacity > 0 || root.timeline.attachedRevealAnim.running)
        const handoffReveal = root.state._overlaySessionActive
            && (preserveVisibleContent || immediateRevealWithThrow)
        const resolvedFromWidth = fromWidth !== undefined
            ? fromWidth
            : root.host._attachedRevealSeedWidth
        const resolvedFromHeight = fromHeight !== undefined
            ? fromHeight
            : root.host._attachedRevealSeedHeight

        root.timeline.attachedCollapseAnim.stop()
        root.state._attachedPanelRevealWidth = Math.min(
            Math.max(root.host._attachedRevealSeedWidth, resolvedFromWidth),
            root.host._attachedPanelWidth
        )
        root.state._attachedPanelRevealHeight = Math.min(
            Math.max(0, resolvedFromHeight),
            root.host._attachedPanelHeight
        )
        root.state._attachedRevealUseHandoffCurve = handoffReveal
        root.timeline.pillCatchAnim.stop()

        if (!shouldThrowKick) {
            root.timeline.attachedRevealAnim.stop()
            if (!preserveVisibleContent)
                root.state._attachedContentOpacity = 0
            root.bridge.attachedRevealDelayTimer.stop()
            if (!preservingThrowMotion) {
                root.timeline.pillThrowOutAnim.stop()
                root.state._pillThrowOffsetY = 0
            }
            root.timeline.attachedRevealAnim.start()
            return
        }

        root.timeline.attachedRevealAnim.stop()
        root.bridge.attachedRevealDelayTimer.stop()
        root.timeline.pillThrowOutAnim.stop()
        root.state._pillThrowOffsetY = 0
        if (!immediateRevealWithThrow)
            root.state._attachedContentOpacity = 0
        root.timeline.pillThrowOutAnim.start()
        root.timeline.attachedRevealAnim.start()
    }

    function startAttachedCollapse(toWidth, toHeight) {
        if (!root.host._attachedPanelActive)
            return

        root.state._overlayHintHandoffActive = false
        root.state._overlayHandoffHintEvent = root.host._idleSnapshot()
        root.bridge.attachedRevealDelayTimer.stop()
        root.timeline.attachedRevealAnim.stop()
        root.timeline.attachedCollapseAnim.stop()
        root.timeline.pillThrowOutAnim.stop()
        root.timeline.pillCatchAnim.stop()
        root.state._pillThrowOffsetY = 0

        root.state._attachedPanelRevealWidth = Math.min(
            Math.max(root.host._attachedRevealSeedWidth, root.host._attachedPanelVisibleWidth),
            root.host._attachedPanelWidth
        )
        root.state._attachedPanelRevealHeight = Math.min(
            Math.max(0, root.host._attachedPanelVisibleHeight),
            root.host._attachedPanelHeight
        )

        root.timeline.attachedCollapseAnim.targetWidth = toWidth !== undefined
            ? toWidth
            : root.host._attachedRevealSeedWidth
        root.timeline.attachedCollapseAnim.targetHeight = toHeight !== undefined
            ? toHeight
            : root.host._attachedRevealSeedHeight
        root.timeline.pillCatchAnim.start()
        root.timeline.attachedCollapseAnim.start()
    }

    function maybeTriggerOverlayOpenPulse() {
        if (!root.state._overlayPulsePending)
            return

        root.state._overlayPulsePending = false

        root.machine.logPulse("maybeTriggerOverlayOpenPulse")

        root.bridge.hintFlashDelayTimer.stop()

        if (root.timeline.sharedBackgroundPulseAnim.running || root.timeline.pulseScaleAnim.running) {
            root.state._pulseOwner = "overlay"
            return
        }

        root.machine.triggerSharedBackgroundPulse("overlay")
    }

    function handoffFullHintToOverlay() {
        if (!root.host._hintPhase || !root.host._isFullHintEventType(root.state._flashSourceEvent.type))
            return

        root.bridge.hintFlashDelayTimer.stop()
        root.timeline.hintEnterAnim.stop()
        root.timeline.hintExitAnim.stop()

        root.state._phase = "idle"
        root.state._flashSourceEvent = root.host._idleSnapshot()
        root.state._flashTrackY = root.host._flashStripY
        root.state._flashTrackScale = root.host._flashScale
        root.state._flashTrackOpacity = 0
        root.state._mainDisplayEvent = root.host._baselineEvent
        root.state._mainTrackY = root.host._mainTrackCenterY
        root.state._mainTrackScale = 1
        root.state._mainTrackOpacity = 1
    }
}
