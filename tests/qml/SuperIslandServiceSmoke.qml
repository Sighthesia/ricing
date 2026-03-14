import Quickshell
import QtQuick
import qs.config
import qs.services
import "modules/bar/widgets" as BarWidgets

// Smoke harness for SuperIsland transient playback, restore, and suppression rules.
ShellRoot {
    id: root

    property bool _phaseOnePassed: false
    property string _initialIdleTitle: ""
    property real _transientHoldWidth: 0
    property real _hintHoldWidth: 0
    property bool _observedExitPulseScale: false
    property bool _observedHintExitPulseScale: false
    property bool _awaitingHintExitPulseScale: false

    BarWidgets.SuperIslandWidget {
        id: superIslandWidget
        visible: false
        liveInstance: true
        debugInstanceLabel: "smoke"
    }

    Connections {
        target: superIslandWidget

        function on_PulseScaleChanged() {
            if (superIslandWidget.transitionMode === "exit-track" && superIslandWidget._pulseScale > 1)
                root._observedExitPulseScale = true

            if (root._awaitingHintExitPulseScale && superIslandWidget._pulseScale > 1)
                root._observedHintExitPulseScale = true
        }
    }

    function _resetService() {
        SuperIslandService._queue = []
        SuperIslandService._baselineState = ({})
        SuperIslandService._suppressExternalSources = true
        SuperIslandService._lastMediaSignature = ""
        SuperIslandService._lastNotificationId = ""
        SuperIslandService._lastWorkspaceId = ""
        SuperIslandService._lastFocusedWindowId = ""
        BarLayoutService.workspaceFlashExtension = 0
        BarLayoutService.superIslandFlashExtension = 0
        SuperIslandService.mainState = SuperIslandService._idleEvent()
        SuperIslandService.flashEvent = ({})
        SuperIslandService.mode = "idle"
        SuperIslandService.activeEvent = SuperIslandService._idleEvent()

        superIslandWidget._phase = "idle"
        superIslandWidget._mainDisplayEvent = superIslandWidget._idleSnapshot()
        superIslandWidget._flashSourceEvent = superIslandWidget._idleSnapshot()
        superIslandWidget._lastActiveEvent = superIslandWidget._idleSnapshot()
        superIslandWidget._sharedBackgroundPulseOpacity = 0
        superIslandWidget._resetTracks()
    }

    function _eventId(event) {
        return event && event.id ? event.id : ""
    }

    function _eventType(event) {
        return event && event.type ? event.type : ""
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function _setSuperIslandToggles(showMedia, showNotifications, showWorkspaceEvents) {
        SettingsService.data.superIsland.showMedia = showMedia
        SettingsService.data.superIsland.showNotifications = showNotifications
        SettingsService.data.superIsland.showWorkspaceEvents = showWorkspaceEvents
    }

    Component.onCompleted: {
        _resetService()
        root._setSuperIslandToggles(true, true, true)
        root._initialIdleTitle = superIslandWidget._currentEvent.title

        _assert(root._eventType(SuperIslandService.mainState) === "idle", "mainState should start from idle baseline")
        _assert(root._eventType(SuperIslandService.activeEvent) === "idle", "activeEvent should start idle")
        _assert(superIslandWidget._mainTrackCenterY >= 0,
            "idle baseline content should fit inside the Pill without a negative vertical offset")

        SuperIslandService.pushEvent({
            id: "flash:test",
            type: "media",
            groupKey: "media:flash",
            priority: "important",
            title: "Flash",
            subtitle: "playing",
            icon: "dialog-information",
            timeoutMs: 1500
        })

        _assert(root._eventType(SuperIslandService.mainState) === "idle", "baseline mainState should remain idle during transient playback")
        _assert(root._eventId(SuperIslandService.activeEvent) === "flash:test", "activeEvent should own the transient slot")

        let enterTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 60; repeat: false }', root)
        enterTimer.triggered.connect(function() {
            root._assert(BarLayoutService.barFlashExtension > 0, "transient playback should raise flash extension")
            root._assert(superIslandWidget.transitionMode === "dual-track", "transient playback should use dual-track mode")
            root._assert(superIslandWidget._currentEvent.title === "Flash", "new transient content should occupy Pill")
            root._assert(superIslandWidget._flashSourceEvent.title === root._initialIdleTitle, "old baseline content should move into flash")
            root._assert(superIslandWidget.sharedBackgroundPulseOpacity > 0,
                "transient playback should trigger the shared background pulse layer")
            root._assert(superIslandWidget.pillTopPadding > 0, "pill should keep top padding from the widget edge")
            root._assert(superIslandWidget._mainTrackCenterY > 0, "media card should keep vertical padding inside the pill")
            root._transientHoldWidth = superIslandWidget.implicitWidth
        })
        enterTimer.start()

        let transientSettleVisualTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 380; repeat: false }', root)
        transientSettleVisualTimer.triggered.connect(function() {
            root._assert(Math.abs(superIslandWidget._flashTrackY - superIslandWidget._flashStripY) <= 1,
                "transient playback should keep the returning row on the standard flash strip")
        })
        transientSettleVisualTimer.start()

        let exitTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 1620; repeat: false }', root)
        exitTimer.triggered.connect(function() {
            root._assert(superIslandWidget.transitionMode === "exit-track", "after 1.5s the transient should exit and baseline should return")
            root._assert(superIslandWidget.mainTrackVisible === true, "main track should remain visible during return animation")
            root._assert(superIslandWidget.flashTrackVisible === true, "flash track should remain visible during return animation")
            root._assert(root._observedExitPulseScale === true,
                "SuperIsland should keep a center-based rebound scale during transient exit so all four edges participate")
            root._assert(superIslandWidget.implicitWidth < root._transientHoldWidth,
                "restore animation should start shrinking width before the exit flow completes")
        })
        exitTimer.start()

        let settleTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 2000; repeat: false }', root)
        settleTimer.triggered.connect(function() {
            root._assert(superIslandWidget._currentEvent.type === "idle", "baseline content should return to Pill after transient completes")
            root._assert(BarLayoutService.barFlashExtension === 0, "flash extension should settle back to zero")
            root._phaseOnePassed = true

            root._resetService()
            root._initialIdleTitle = superIslandWidget._currentEvent.title

            SuperIslandService.pushEvent({
                id: "window:test",
                type: "window",
                groupKey: "window-focus",
                priority: "important",
                title: "Kitty",
                subtitle: "kitty",
                workspaceLabel: "2",
                timeoutMs: 1500
            })

            let hintTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 80; repeat: false }', root)
            hintTimer.triggered.connect(function() {
                root._assert(superIslandWidget.transitionMode === "dual-track",
                    "window switching should use the same dual-track transient mode as media and notifications")
                root._assert(superIslandWidget._currentEvent.type === "window",
                    "window switching should occupy the main Pill like other transient events")
                root._assert(superIslandWidget._flashSourceEvent.type === "idle",
                    "window switching should push the baseline content into the flash strip")
                root._hintHoldWidth = superIslandWidget.implicitWidth
            })
            hintTimer.start()

            let hintSettleVisualTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 380; repeat: false }', root)
            hintSettleVisualTimer.triggered.connect(function() {
                root._assert(superIslandWidget.sharedBackgroundPulseOpacity > 0,
                    "window switching should reuse the shared transient background pulse layer")
                root._assert(Math.abs(superIslandWidget._flashTrackY - superIslandWidget._flashStripY) <= 1,
                    "window switching should keep the baseline row on the standard flash strip")
            })
            hintSettleVisualTimer.start()

            let hintPulseReleaseTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 980; repeat: false }', root)
            hintPulseReleaseTimer.triggered.connect(function() {
                root._assert(superIslandWidget.sharedBackgroundPulseOpacity === 0,
                    "window transient background pulse should clear after the flash")
            })
            hintPulseReleaseTimer.start()

            let hintExitArmTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 1450; repeat: false }', root)
            hintExitArmTimer.triggered.connect(function() {
                root._awaitingHintExitPulseScale = true
            })
            hintExitArmTimer.start()

            let hintExitTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 1700; repeat: false }', root)
            hintExitTimer.triggered.connect(function() {
                root._assert(root._observedHintExitPulseScale === true,
                    "SuperIsland should keep a center-based rebound scale during hint exit so all four edges participate")
                root._awaitingHintExitPulseScale = false
                root._assert(superIslandWidget.implicitWidth < root._hintHoldWidth,
                    "window transient exit should start shrinking width before the collapse finishes")
            })
            hintExitTimer.start()

            let hintSettleTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 2100; repeat: false }', root)
            hintSettleTimer.triggered.connect(function() {
                root._assert(superIslandWidget._currentEvent.type === "idle", "window transient should settle back to idle")

                root._resetService()
                root._setSuperIslandToggles(true, true, true)
                root._initialIdleTitle = superIslandWidget._currentEvent.title

                SuperIslandService.pushEvent({
                    id: "window:interrupt",
                    type: "window",
                    groupKey: "window-focus",
                    priority: "important",
                    title: "Firefox",
                    subtitle: "firefox",
                    workspaceLabel: "4",
                    timeoutMs: 1500
                })

                let interruptHintTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 380; repeat: false }', root)
                interruptHintTimer.triggered.connect(function() {
                    SuperIslandService.pushEvent({
                        id: "media:interrupt",
                        type: "media",
                        groupKey: "media:interrupt",
                        priority: "important",
                        title: "Override Media",
                        subtitle: "playing",
                        icon: "dialog-information",
                        timeoutMs: 1500
                    })
                })
                interruptHintTimer.start()

                let interruptAssertTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 460; repeat: false }', root)
                interruptAssertTimer.triggered.connect(function() {
                    root._assert(superIslandWidget._currentEvent.type === "media",
                        "interrupting a window transient should move the new transient into the Pill")
                    root._assert(superIslandWidget._flashSourceEvent.type === "idle",
                        "interrupting a window transient should keep the baseline content in the flash strip instead of the old window title")
                    root._assert(superIslandWidget.transitionMode === "dual-track",
                        "interrupting a window transient should continue directly into the dual-track transient state")

                    root._resetService()
                    root._setSuperIslandToggles(true, false, false)
                    root._initialIdleTitle = superIslandWidget._currentEvent.title

                    SuperIslandService.pushEvent({
                        id: "first:test",
                        type: "notification",
                        groupKey: "notification:first",
                        priority: "important",
                        title: "First",
                        subtitle: "First transient",
                        timeoutMs: 1500
                    })

                    root._assert(root._eventType(SuperIslandService.activeEvent) === "idle",
                        "notification toggle should suppress notification rendering")

                    root._resetService()
                    root._setSuperIslandToggles(false, true, false)
                    root._initialIdleTitle = superIslandWidget._currentEvent.title

                    SuperIslandService.pushEvent({
                        id: "media:disabled",
                        type: "media",
                        groupKey: "media:disabled",
                        priority: "important",
                        title: "Muted Media",
                        subtitle: "playing",
                        timeoutMs: 1500
                    })

                    root._assert(root._eventType(SuperIslandService.activeEvent) === "idle",
                        "media toggle should suppress media rendering")

                    root._resetService()
                    root._setSuperIslandToggles(false, false, false)
                    root._initialIdleTitle = superIslandWidget._currentEvent.title

                    SuperIslandService.pushEvent({
                        id: "window:disabled",
                        type: "window",
                        groupKey: "window-focus",
                        priority: "important",
                        title: "Hidden Window",
                        subtitle: "app",
                        workspaceLabel: "3",
                        timeoutMs: 1500
                    })

                    root._assert(root._eventType(SuperIslandService.activeEvent) === "idle",
                        "workspace toggle should suppress window hint rendering")

                    root._resetService()
                    root._setSuperIslandToggles(true, true, true)
                    root._initialIdleTitle = superIslandWidget._currentEvent.title

                    SuperIslandService.pushEvent({
                        id: "first:test",
                        type: "notification",
                        groupKey: "notification:first",
                        priority: "important",
                        title: "First",
                        subtitle: "First transient",
                        timeoutMs: 1500
                    })

                    let pendingTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 120; repeat: false }', root)
                    pendingTimer.triggered.connect(function() {
                        SuperIslandService.pushEvent({
                            id: "second:test",
                            type: "notification",
                            groupKey: "notification:second",
                            priority: "important",
                            title: "Second",
                            subtitle: "Second transient",
                            timeoutMs: 1500
                        })

                        SuperIslandService.pushEvent({
                            id: "third:test",
                            type: "notification",
                            groupKey: "notification:third",
                            priority: "important",
                            title: "Third",
                            subtitle: "Third transient",
                            timeoutMs: 1500
                        })
                    })
                    pendingTimer.start()

                    let pendingChainTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 1620; repeat: false }', root)
                    pendingChainTimer.triggered.connect(function() {
                        root._assert(superIslandWidget._currentEvent.title === "Third",
                            "queued transient playback should replace the main Pill content directly with the next event")
                        root._assert(superIslandWidget._currentEvent.type !== "idle",
                            "queued transient playback should not fall back to idle between events")
                        root._assert(superIslandWidget.transitionMode !== "exit-track",
                            "queued transient playback should not enter the exit-track return animation between events")
                    })
                    pendingChainTimer.start()

                    let pendingAssertTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 2050; repeat: false }', root)
                    pendingAssertTimer.triggered.connect(function() {
                        root._assert(superIslandWidget._currentEvent.title === "Third", "only the last pending transient should start after the first flow completes")
                        root._assert(superIslandWidget._flashSourceEvent.title === root._initialIdleTitle, "pending transient should still push baseline content into flash")
                    })
                    pendingAssertTimer.start()

                    let finalTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 3900; repeat: false }', root)
                    finalTimer.triggered.connect(function() {
                        root._assert(root._phaseOnePassed, "phase one assertions should have passed")
                        root._assert(superIslandWidget._currentEvent.type === "idle", "widget should settle back to idle after pending transient completes")
                        root._assert(BarLayoutService.barFlashExtension === 0, "flash extension should settle back to zero after pending transient")
                        console.log("SuperIslandService smoke test passed")
                        Qt.callLater(Qt.quit)
                    })
                    finalTimer.start()
                })
                interruptAssertTimer.start()
            })
            hintSettleTimer.start()
        })
        settleTimer.start()
    }
}
