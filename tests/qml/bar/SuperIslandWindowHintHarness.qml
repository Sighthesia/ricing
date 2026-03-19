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

    Component.onCompleted: {
        root._resetServiceState()
        _scenarioStartTimer.restart()
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
            root._assert(island._mainTrackY >= island._flashStripY - 1,
                "idle clock text should drop to the lower flash row like notification and media transitions")

            SuperIslandService.pushEvent({
                id: "notification:test-1",
                type: "notification",
                priority: "important",
                title: "Alert",
                subtitle: "Body",
                icon: "dialog-information",
                timeoutMs: 30
            })
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
            Qt.quit()
        }
    }
}
