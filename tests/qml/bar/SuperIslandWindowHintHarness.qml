import QtQuick
import qs.config
import qs.services
import "../../../modules/bar/widgets" as BarWidgets

// Minimal Super Island regression harness for window-hint overlap handoff.
Item {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function _resetServiceState() {
        SuperIslandService._suppressExternalSources = true
        SuperIslandService._queue = []
        SuperIslandService._baselineState = ({})
        SuperIslandService._snoozedGroups = ({})
        SuperIslandService._lastNotificationId = ""
        SuperIslandService._lastWorkspaceId = ""
        SuperIslandService._lastFocusedWindowId = ""
        SuperIslandService._lastMediaSignature = ""
        SuperIslandService.mainState = SuperIslandService._idleEvent()
        SuperIslandService.flashEvent = ({})
        SuperIslandService.mode = "idle"
        SuperIslandService.activeEvent = SuperIslandService._idleEvent()
        BarLayoutService.superIslandFlashExtension = 0
    }

    function _runWindowOverlapScenario() {
        SuperIslandService.replaceEvent("window-focus", {
            id: "window:test-1",
            type: "window",
            priority: "important",
            title: "Window A",
            subtitle: "app-a",
            icon: "dialog-information",
            timeoutMs: Theme.anim.moveDuration * 2
        })
        _windowAssertionTimer.restart()
    }

    BarWidgets.SuperIslandWidget {
        id: island
    }

    Timer {
        id: _scenarioStartTimer
        interval: 30
        repeat: false
        onTriggered: root._runWindowOverlapScenario()
    }

    Timer {
        id: _windowAssertionTimer
        interval: Theme.anim.moveDuration + 30
        repeat: false
        onTriggered: {
            root._assert(island._phase === "hint", "window hint should enter hint phase")
            root._assert(island._mainDisplayEvent.type === "idle",
                "window hint should keep baseline content in the pill")
            root._assert(island._flashSourceEvent.type === "window",
                "window hint should render only on the flash track")
            root._assert(island._notificationEntryMeta.outgoingBaseline.targetCenterY === island._windowHintEntryMeta.mainRole.targetCenterY,
                "window hint main role should stay on the same flash-lane center as notification outgoing baseline")
            root._assert(island._notificationEntryMeta.outgoingBaseline.scale === island._windowHintEntryMeta.mainRole.scale,
                "window hint main role should reuse notification outgoing baseline scale")
            root._assert(island._notificationEntryMeta.outgoingBaseline.opacity === island._windowHintEntryMeta.mainRole.opacity,
                "window hint main role should reuse notification outgoing baseline opacity")
            root._assert(island._notificationEntryMeta.outgoingBaseline.durationToken === island._windowHintEntryMeta.mainRole.durationToken,
                "window hint main role should reuse notification outgoing baseline duration token")
            root._assert(island._notificationEntryMeta.outgoingBaseline.easingToken === island._windowHintEntryMeta.mainRole.easingToken,
                "window hint main role should reuse notification outgoing baseline easing token")
            root._assert(island._windowHintEntryMeta.mainRole.targetY === island._windowHintEntryMeta.mainFlashLaneTargetY,
                "window hint main role should use the main-track flash-lane target")
            root._assert(island._windowHintEntryMeta.mainRole.targetY < island._windowHintEntryMeta.flashRole.targetY,
                "window hint clock should sit higher than the smaller workspace card when both are centered in the flash lane")
            root._assert(island._windowHintEntryMeta.flashRole.targetY === island._windowHintEntryMeta.flashLaneTargetY,
                "window hint flash role should stay on the flash lane target")
            root._assert(island._windowHintEntryMeta.flashRole.deltaY === island._notificationEntryMeta.incomingTransient.deltaY,
                "window hint flash role should reuse notification incoming transient delta")
            root._assert(island._windowHintEntryMeta.flashRole.scale === island._notificationEntryMeta.incomingTransient.scale,
                "window hint flash role should reuse notification incoming transient scale")
            root._assert(island._windowHintEntryMeta.flashRole.opacity === island._notificationEntryMeta.incomingTransient.opacity,
                "window hint flash role should reuse notification incoming transient opacity")
            root._assert(island._windowHintEntryMeta.flashRole.durationToken === island._notificationEntryMeta.incomingTransient.durationToken,
                "window hint flash role should reuse notification incoming transient duration token")
            root._assert(island._windowHintEntryMeta.flashRole.easingToken === island._notificationEntryMeta.incomingTransient.easingToken,
                "window hint flash role should reuse notification incoming transient easing token")
            root._assert(island._windowHintEntryMeta.flashRole.targetY !== island._notificationEntryMeta.incomingTransient.targetY,
                "window hint flash role should not reuse notification incoming transient geometry")
            root._assert(island._resolvedWindowHintState.mainTargetY === island._windowHintEntryMeta.mainRole.targetY,
                "live main hint state should match the main role seam")
            root._assert(island._resolvedWindowHintState.mainScale === island._windowHintEntryMeta.mainRole.scale,
                "live main hint scale should match the main role seam")
            root._assert(island._resolvedWindowHintState.mainOpacity === island._windowHintEntryMeta.mainRole.opacity,
                "live main hint opacity should match the main role seam")
            root._assert(island._resolvedWindowHintState.flashTargetY === island._windowHintEntryMeta.flashRole.targetY,
                "live flash hint state should match the flash role seam")
            root._assert(island._resolvedWindowHintState.flashScale === island._windowHintEntryMeta.flashRole.scale,
                "live flash hint scale should match the flash role seam")
            root._assert(island._resolvedWindowHintState.flashOpacity === island._windowHintEntryMeta.flashRole.opacity,
                "live flash hint opacity should match the flash role seam")
            root._assert(island._mainTrackY === island._resolvedWindowHintState.mainTargetY,
                "live main track position should match the resolved hint state")
            root._assert(island._mainTrackScale === island._resolvedWindowHintState.mainScale,
                "live main track scale should match the resolved hint state")
            root._assert(island._mainTrackOpacity === island._resolvedWindowHintState.mainOpacity,
                "live main track opacity should match the resolved hint state")
            root._assert(island._flashTrackY === island._resolvedWindowHintState.flashTargetY,
                "live flash track position should match the resolved hint state")
            root._assert(island._flashTrackScale === island._resolvedWindowHintState.flashScale,
                "live flash track scale should match the resolved hint state")
            root._assert(island._flashTrackOpacity === island._resolvedWindowHintState.flashOpacity,
                "live flash track opacity should match the resolved hint state")
            root._assert(island._sharedBackgroundPulseOpacity > 0,
                "window hint should retain the shared super island pulse")
            root._assert(island._hintBackgroundPulseOpacity === 0,
                "window hint should not leave a flash-lane highlight pulse behind")

            SuperIslandService.pushEvent({
                id: "notification:test-1",
                type: "notification",
                priority: "important",
                title: "Alert",
                subtitle: "Body",
                icon: "dialog-information",
                timeoutMs: 30
            })
            _handoffAssertionTimer.restart()
        }
    }

    Timer {
        id: _handoffAssertionTimer
        interval: Theme.anim.moveDuration + 30
        repeat: false
        onTriggered: {
            root._assert(island._phase !== "idle", "notification should still be driving the overlap handoff")
            root._assert(island._mainDisplayEvent.type === "notification",
                "notification should take over the primary transient path")
            root._assert(island._flashSourceEvent.type === "window",
                "window hint should remain parked on the flash track during overlap")
            root._assert(BarLayoutService.superIslandFlashExtension > 0,
                "overlap handoff should keep the flash extension active")
            _finalAssertionTimer.restart()
        }
    }

    Timer {
        id: _finalAssertionTimer
        interval: Theme.anim.moveDuration + Theme.anim.springDuration + Theme.anim.moveDuration + 180
        repeat: false
        onTriggered: {
            root._assert(island._phase === "idle", "super island should settle back to idle")
            root._assert(island._mainDisplayEvent.type === "idle",
                "transient exit should restore idle baseline into the pill")
            root._assert(island._flashSourceEvent.type === "idle",
                "flash source should be cleared after transient exit")
            root._assert(BarLayoutService.superIslandFlashExtension === 0,
                "flash extension should collapse after overlap handoff")
            root._assert(island._resolvedWindowHintState.mainOpacity === island._idleMotionMeta.mainOpacity,
                "idle cleanup should restore main opacity metadata")
            root._assert(island._resolvedWindowHintState.mainScale === island._idleMotionMeta.mainScale,
                "idle cleanup should restore main scale metadata")
            root._assert(island._resolvedWindowHintState.flashOpacity === island._idleMotionMeta.flashOpacity,
                "idle cleanup should restore flash opacity metadata")
            root._assert(island._resolvedWindowHintState.flashScale === island._idleMotionMeta.flashScale,
                "idle cleanup should restore flash scale metadata")
            root._assert(island._sharedBackgroundPulseOpacity === 0,
                "cleanup should leave no residual shared pulse")
            root._assert(island._hintBackgroundPulseOpacity === 0,
                "cleanup should leave no residual flash highlight pulse")
            Qt.quit()
        }
    }

    Component.onCompleted: {
        root._resetServiceState()
        _scenarioStartTimer.restart()
    }
}
