import QtQuick
import qs.config
import qs.services
import "." as IslandParts

// Owns SuperIsland transient state transitions, timers, and animation choreography.
Item {
    id: controller

    required property Item host
    required property QtObject state

    visible: false
    width: 0
    height: 0

    IslandParts.SuperIslandStateMachineTimeline {
        id: timeline

        host: controller.host
        state: controller.state
        resetReplaceLayers: controller.resetReplaceLayers
        completeWindowHintExit: controller.completeWindowHintExit
    }

    IslandParts.SuperIslandStateMachineBridge {
        id: bridge

        host: controller.host
        state: controller.state
        machine: controller
        timeline: timeline
        eventRouter: eventRouter
        overlayEventRouter: overlayEventRouter
    }

    IslandParts.SuperIslandEventRouter {
        id: eventRouter

        host: controller.host
        state: controller.state
        machine: controller
    }

    IslandParts.SuperIslandOverlayEventRouter {
        id: overlayEventRouter

        host: controller.host
        state: controller.state
        machine: controller
        bridge: bridge
    }

    IslandParts.SuperIslandStateMachineTransientPolicy {
        id: transientPolicy

        host: controller.host
        state: controller.state
        machine: controller
        timeline: timeline
        bridge: bridge
    }

    IslandParts.SuperIslandStateMachineLifecyclePolicy {
        id: lifecyclePolicy

        host: controller.host
        state: controller.state
        machine: controller
    }

    IslandParts.SuperIslandStateMachinePulsePolicy {
        id: pulsePolicy

        host: controller.host
        state: controller.state
        machine: controller
        timeline: timeline
    }

    IslandParts.SuperIslandStateMachineOverlayPolicy {
        id: overlayPolicy

        host: controller.host
        state: controller.state
        machine: controller
        timeline: timeline
        bridge: bridge
    }

    function initialize() {
        lifecyclePolicy.initialize()
    }

    function teardown() {
        lifecyclePolicy.teardown()
    }

    function log(message, event) {
        if (!host._debugLogging)
            return

        if (!event) {
            console.log("SuperIslandWidget[" + host.debugInstanceLabel + "]:", message)
            return
        }

        console.log(
            "SuperIslandWidget[" + host.debugInstanceLabel + "]:", message,
            "id=", event.id || "",
            "type=", event.type || "",
            "priority=", event.priority || "",
            "title=", event.title || "",
            "subtitle=", event.subtitle || ""
        )
    }

    function logPulse(message) {
        if (!host._debugLogging)
            return

        console.log(
            "SuperIslandWidget[" + host.debugInstanceLabel + "]: pulse", message,
            "owner=", state._pulseOwner,
            "phase=", state._phase,
            "flashType=", state._flashSourceEvent.type || "",
            "overlayMode=", IslandOverlayService.mode,
            "overlayState=", IslandOverlayService.state,
            "overlaySessionActive=", state._overlaySessionActive,
            "overlayExpandedActive=", state._overlayExpandedActive,
            "overlayPulsePending=", state._overlayPulsePending,
            "pulseAnimRunning=", timeline.sharedBackgroundPulseAnim.running,
            "scaleAnimRunning=", timeline.pulseScaleAnim.running
        )
    }

    function resetTracks() {
        lifecyclePolicy.resetTracks()
    }

    function syncOverlayFlags() {
        overlayPolicy.syncOverlayFlags()
    }

    function syncOverlayExtensionReservation() {
        overlayPolicy.syncOverlayExtensionReservation()
    }

    function startEnterTransition(event) {
        transientPolicy.startEnterTransition(event)
    }

    function startWindowHint(event) {
        transientPolicy.startWindowHint(event)
    }

    function updateWindowHint(event) {
        transientPolicy.updateWindowHint(event)
    }

    function startAttachedReveal(fromWidth, fromHeight, withThrowKick) {
        overlayPolicy.startAttachedReveal(fromWidth, fromHeight, withThrowKick)
    }

    function startAttachedCollapse(toWidth, toHeight) {
        overlayPolicy.startAttachedCollapse(toWidth, toHeight)
    }

    function cancelSharedBackgroundPulse() {
        pulsePolicy.cancelSharedBackgroundPulse()
    }

    function triggerSharedBackgroundPulse(owner) {
        pulsePolicy.triggerSharedBackgroundPulse(owner)
    }

    function maybeTriggerOverlayOpenPulse() {
        overlayPolicy.maybeTriggerOverlayOpenPulse()
    }

    function handoffFullHintToOverlay() {
        overlayPolicy.handoffFullHintToOverlay()
    }

    function triggerEdgeReboundScale() {
        pulsePolicy.triggerEdgeReboundScale()
    }

    function resetReplaceLayers() {
        transientPolicy.resetReplaceLayers()
    }

    function replaceActiveTransient(event) {
        transientPolicy.replaceActiveTransient(event)
    }

    function triggerHintFlash() {
        transientPolicy.triggerHintFlash()
    }

    function finishWindowHint() {
        transientPolicy.finishWindowHint()
    }

    function completeWindowHintExit() {
        transientPolicy.completeWindowHintExit()
    }

    function startExitTransition() {
        transientPolicy.startExitTransition()
    }
}
