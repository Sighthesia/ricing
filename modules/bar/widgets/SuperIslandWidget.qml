import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "../superisland" as IslandCards

// Dynamic Island-style bar widget for idle time, transient events, and hint playback.
Item {
    id: root

property bool liveInstance: false
property string debugInstanceLabel: liveInstance ? "live" : "preview"

readonly property bool _debugLogging: false
property date currentTime
Timer {
    id: timeTimer
    interval: 60 * 1000
    running: true
    repeat: true
    onTriggered: currentTime = new Date()
}

readonly property int _padV: Theme.iconPadding
readonly property int _padH: Theme.barWidget.contentPaddingH
readonly property int _pillH: Theme.barWidget.pillHeight
readonly property int _flashGap: Theme.barWidget.stackGap
readonly property int _flashRowH: Theme.barWidget.pillHeight
    readonly property int _hintPulsePad: Theme.barWidget.focusPulsePadding
    readonly property int _hintLift: Theme.barWidget.contentPaddingV
    readonly property int _replaceOffset: Math.max(6, Theme.barWidget.contentPaddingV * 3)
readonly property int _replaceDelay: Math.max(50, Math.round(Theme.anim.highlightDuration / 2))
readonly property real _flashScale: 0.85
property bool _initialized: false
property string _phase: "idle"
property var _mainDisplayEvent: _idleSnapshot()
property var _flashSourceEvent: _idleSnapshot()
property var _replaceOutgoingEvent: _idleSnapshot()
property var _replaceIncomingEvent: _idleSnapshot()
property var _lastActiveEvent: _idleSnapshot()
property real _mainTrackY: 0
property real _mainTrackScale: 1
property real _mainTrackOpacity: 1
property real _flashTrackY: 0
property real _flashTrackScale: _flashScale
property real _flashTrackOpacity: 0
    readonly property var _notificationEntryMeta: ({
        outgoingBaseline: ({
            targetY: root._flashStripY,
            deltaY: root._flashStripY - root._flashTrackCenterY,
            targetCenterY: root._flashLaneCenterY,
            scale: root._flashScale,
            opacity: 0.6,
            durationToken: "moveDuration",
            easingToken: "moveType"
        }),
        incomingTransient: ({
            targetY: root._mainTrackCenterY,
            deltaY: root._mainTrackCenterY - root._mainTrackEnterY,
            targetCenterY: root._mainTrackCenterY
                + ((_mainLoader.item ? _mainLoader.item.implicitHeight : root._pillH) / 2),
            scale: 1,
            opacity: 1,
            durationToken: "moveDuration",
            easingToken: "moveType"
        })
    })
    readonly property var _windowHintEntryMeta: ({
        mainRole: ({
            targetY: root._mainFlashTrackY,
            deltaY: root._mainFlashTrackY - root._mainTrackCenterY,
            targetCenterY: root._flashLaneCenterY,
            scale: root._notificationEntryMeta.outgoingBaseline.scale,
            opacity: root._notificationEntryMeta.outgoingBaseline.opacity,
            durationToken: root._notificationEntryMeta.outgoingBaseline.durationToken,
            easingToken: root._notificationEntryMeta.outgoingBaseline.easingToken
        }),
        mainFlashLaneTargetY: root._mainFlashTrackY,
        flashLaneTargetY: Theme.barWidget.contentPaddingV,
        flashLaneCenterY: root._flashLaneCenterY,
        flashRole: ({
            targetY: Theme.barWidget.contentPaddingV,
            deltaY: root._notificationEntryMeta.incomingTransient.deltaY,
            targetCenterY: root._flashLaneCenterY,
            scale: root._notificationEntryMeta.incomingTransient.scale,
            opacity: root._notificationEntryMeta.incomingTransient.opacity,
            durationToken: root._notificationEntryMeta.incomingTransient.durationToken,
            easingToken: root._notificationEntryMeta.incomingTransient.easingToken
        })
    })
    readonly property var _idleMotionMeta: ({
        mainOpacity: 1,
        mainScale: 1,
        flashOpacity: 0,
        flashScale: root._flashScale
    })
    readonly property var _resolvedWindowHintState: ({
        mainTargetY: root._mainTrackY,
        mainScale: root._mainTrackScale,
        mainOpacity: root._mainTrackOpacity,
        flashTargetY: root._flashTrackY,
        flashScale: root._flashTrackScale,
        flashOpacity: root._flashTrackOpacity
    })

    // --- derived state (avoid undefined bindings + runtime crashes) ---
    readonly property var _baselineEvent: root._displayEvent(SuperIslandService.mainState)
    readonly property var _currentEvent: root._mainDisplayEvent
    readonly property string transitionMode:
        root._phase === "exit" ? "exit-track"
        : (root._phase === "idle" ? "single-track" : "dual-track")
    readonly property bool flashTrackVisible: root._phase !== "idle" && !root._overlaySessionActive
    readonly property bool _transientPhase: root._phase !== "idle"
    property bool _overlaySessionActive: false
    property bool _overlayExpandedActive: false
    readonly property real pillTopPadding: root._padV

    readonly property real _mainTrackCenterY:
        root._trackCenterY(_mainLoader.item, root._pillH, root._mainDisplayEvent, true)
    readonly property real _flashTrackCenterY:
        root._trackCenterY(_stripLoader.item, root._pillH, root._flashSourceEvent, false)
    readonly property real _flashRowBaseY: root._pillH + root._flashGap
    readonly property real _flashLaneCenterY: root._flashRowBaseY + root._flashRowH / 2
    readonly property real _flashStripY:
        root._flashRowBaseY
        + root._trackCenterY(_stripLoader.item, root._flashRowH, root._flashSourceEvent, false)
    readonly property real _mainFlashTrackY:
        root._flashRowBaseY
        + root._trackCenterY(_mainLoader.item, root._flashRowH, root._mainDisplayEvent, true)
    readonly property real _hintTrackY: root._mainTrackCenterY - root._hintLift
    readonly property real _hintDividerY: root._pillH + Math.max(0, (root._flashGap - 1) / 2)
    readonly property real _hintBackgroundY: root._flashRowBaseY
    readonly property real _hintBackgroundHeight: root._flashRowH
    readonly property real _hintBackgroundPulseOpacity:
        root._hintPhase && root._flashSourceEvent.type !== "window"
            ? root._sharedBackgroundPulseOpacity
            : 0
    readonly property real _returnTrackCenterY:
        root._trackCenterY(_stripLoader.item, root._pillH, root._flashSourceEvent, false)
    readonly property real _overlayBodyHeight: Math.round(528 * Theme.uiScale)
    readonly property real _transientExpandedHeight: root._pillH + root._flashGap + root._flashRowH
    readonly property real _collapsedPillHeight: root._pillH
    readonly property real _expandedPillHeight:
        root._overlaySessionActive
            ? (root._pillH + root._flashGap + root._overlayBodyHeight)
            : root._transientExpandedHeight
    readonly property bool _pillExpanded:
        root._overlayExpandedActive
        || root._phase === "enter" || root._phase === "hold" || root._phase === "hint"

    readonly property real _overlayExpandedWidth: {
        const availableWidth = Math.max(
            760,
            BarLayoutService.barContentWidth - Math.max(24, Theme.barPadding * 2)
        )
        return Math.max(root._collapsedWidth, Math.min(Math.round(980 * Theme.uiScale), availableWidth))
    }

    readonly property real _verticalRevealSurfaceHeight: _verticalReveal.surfaceHeight
    readonly property real _verticalRevealClipHeight: _verticalReveal.clipHeight

    readonly property real _collapsedWidth:
        (_mainLoader.item ? _mainLoader.item.implicitWidth : 0) + root._padH * 2
    readonly property real _expandedWidth:
        root._overlayExpandedActive
            ? root._overlayExpandedWidth
            : Math.max(
                root._collapsedWidth,
                (_stripLoader.item ? _stripLoader.item.implicitWidth : 0) + root._padH * 2
            )

    readonly property real _mainTrackEnterY:
        -Math.max(root._pillH, _mainLoader.item ? _mainLoader.item.implicitHeight : root._pillH)
    readonly property real _returnWidth:
        root._overlayExpandedActive
            ? root._collapsedWidth
            : ((_stripLoader.item ? _stripLoader.item.implicitWidth : 0) + root._padH * 2)
    readonly property real _transitionCollapsedWidth:
        root._overlayExpandedActive
            ? root._collapsedWidth
            : (root._phase === "exit" ? root._returnWidth : root._collapsedWidth)
    readonly property real _idleOpticalOffset: 0
    readonly property bool _hintPhase: root._phase === "hint" || root._phase === "hint-exit"
    readonly property bool _listensToService: true
    readonly property real _transientAccentBaseOpacity: 0
    readonly property real _overlayReservedExtension:
        root._overlaySessionActive
            ? Math.max(0, root._expandedPillHeight - root._collapsedPillHeight)
            : 0

    Component.onCompleted: {
        currentTime = new Date()
        root._syncOverlayFlags()
        const initialActiveEvent = root._displayEvent(root._listensToService ? SuperIslandService.activeEvent : root._idleSnapshot())
        root._mainDisplayEvent = initialActiveEvent.type !== "idle" ? initialActiveEvent : root._baselineEvent
        root._lastActiveEvent = initialActiveEvent
        root._resetTracks()
        root._syncOverlayExtensionReservation()
        Qt.callLater(() => { root._initialized = true })
    }

    Component.onDestruction: {
        if (root.liveInstance)
            BarLayoutService.clearTransientExtension("super-island-overlay")
    }

    onLiveInstanceChanged: root._syncOverlayExtensionReservation()
    property real _replaceOutgoingY: 0
    property real _replaceOutgoingOpacity: 0
    property real _replaceOutgoingTargetY: 0
    property real _replaceIncomingY: 0
    property real _replaceIncomingOpacity: 0
    property bool _replaceOutgoingVisible: false
    property bool _replaceIncomingVisible: false
    property real _sharedBackgroundPulseOpacity: 0
    property real _pulseScale: 1

    implicitHeight: Theme.barHeight
    implicitWidth: root._phase === "hint-exit"
        ? root._collapsedWidth
        : (root._phase === "exit"
            ? root._returnWidth
            : (root._pillExpanded ? root._expandedWidth : root._collapsedWidth))

    BarComponents.BarTransientRevealHost {
        id: _verticalReveal

        collapsedHeight: root._collapsedPillHeight
        expandedHeight: root._expandedPillHeight
        expanded: root._pillExpanded
        extensionOwnerKey: root.liveInstance ? "super-island" : ""
        animateSurface: root._overlaySessionActive
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    BarComponents.BarExpandTransition {
        id: _pillTransition

        collapsedWidth: root._transitionCollapsedWidth
        expandedWidth: root._expandedWidth
        collapsedHeight: root._collapsedPillHeight
        expandedHeight: root._expandedPillHeight
        expanded: root._pillExpanded
        animateWidth: true
        animateHeight: false
    }

    function _log(message, event) {
        if (!root._debugLogging)
            return

        if (!event) {
            console.log("SuperIslandWidget[" + root.debugInstanceLabel + "]:", message)
            return
        }

        console.log(
            "SuperIslandWidget[" + root.debugInstanceLabel + "]:", message,
            "id=", event.id || "",
            "type=", event.type || "",
            "priority=", event.priority || "",
            "title=", event.title || "",
            "subtitle=", event.subtitle || ""
        )
    }

    function _cloneEvent(event) {
        const source = event || root._idleSnapshot()
        return {
            id: source.id || "",
            type: source.type || "idle",
            groupKey: source.groupKey || "idle",
            priority: source.priority || "passive",
            relayReplace: !!source.relayReplace,
            title: source.title || "",
            subtitle: source.subtitle || "",
            icon: source.icon || "",
            workspaceLabel: source.workspaceLabel || "",
            timeoutMs: source.timeoutMs || 0,
            timestamp: source.timestamp || 0
        }
    }

    function _idleSnapshot() {
        return {
            id: "idle",
            type: "idle",
            groupKey: "idle",
            priority: "passive",
            relayReplace: false,
            title: Qt.formatDateTime(currentTime, "hh:mm"),
            subtitle: "",
            icon: "",
            workspaceLabel: "",
            timeoutMs: 0,
            timestamp: Date.now()
        }
    }

    function _displayEvent(event) {
        if (!event || event.type === "idle")
            return root._idleSnapshot()
        return root._cloneEvent(event)
    }

    function _resolvedIconSource(iconName) {
        if (!iconName)
            return Quickshell.iconPath("dialog-information")
        if (iconName.indexOf("://") !== -1 || iconName.startsWith("/"))
            return iconName
        return Quickshell.iconPath(iconName, "dialog-information")
    }

    function _componentForEvent(event, useStrip) {
        if (!event || event.type === "idle")
            return _idleComponent
        if (event.type === "media")
            return useStrip ? _stripMediaCardComponent : _mainMediaCardComponent
        if (event.type === "workspace" || event.type === "window")
            return useStrip ? _stripWorkspaceCardComponent : _mainWorkspaceCardComponent
        if (event.priority === "critical" || event.subtitle !== "")
            return useStrip ? _stripNotificationCardComponent : _mainNotificationCardComponent
        return useStrip ? _stripCompactEventComponent : _compactEventComponent
    }

    function _notificationIdFromEvent(event) {
        if (!event || event.type !== "notification")
            return ""

        const eventId = String(event.id || "")
        const prefix = "notification:"
        if (!eventId.startsWith(prefix))
            return ""

        return eventId.slice(prefix.length)
    }

    function _activateNotificationEvent(event) {
        const notificationId = root._notificationIdFromEvent(event)
        if (!notificationId)
            return false

        return NotificationService.invokeDefaultAction(notificationId)
    }

    function _preferredOverlayPage() {
        const configuredPage = SettingsService.data.superIsland
            ? SettingsService.data.superIsland.expandedDefaultPage
            : "launcher"

        if (configuredPage === "settings" || configuredPage === "notifications")
            return configuredPage

        return "launcher"
    }

    function _trackCenterY(item, zoneHeight, event, includeOpticalOffset) {
        const itemHeight = item ? item.implicitHeight : zoneHeight
        const opticalOffset = includeOpticalOffset && event && event.type === "idle"
            ? root._idleOpticalOffset
            : 0
        return (zoneHeight - itemHeight) / 2 + opticalOffset
    }

    function _resetTracks() {
        root._mainTrackY = root._mainTrackCenterY
        root._mainTrackScale = 1
        root._mainTrackOpacity = 1
        root._flashTrackY = root._flashStripY
        root._flashTrackScale = root._flashScale
        root._flashTrackOpacity = 0
    }

    function _syncOverlayFlags() {
        root._overlaySessionActive = IslandOverlayService.mode !== "none"
            && IslandOverlayService.state !== "closed"
        root._overlayExpandedActive = IslandOverlayService.mode !== "none"
            && (IslandOverlayService.state === "opening" || IslandOverlayService.state === "open")
    }

    function _syncOverlayExtensionReservation() {
        if (!root.liveInstance)
            return

        let reservedHeight = root._overlaySessionActive
            ? root._overlayReservedExtension
            : 0

        if (root._overlaySessionActive) {
            BarLayoutService.setTransientExtension("super-island-overlay", reservedHeight)
            return
        }

        BarLayoutService.clearTransientExtension("super-island-overlay")
    }

    function _resetOverlayDrivenState() {
        _departAnim.stop()
        _returnAnim.stop()
        _hintEnterAnim.stop()
        _hintExitAnim.stop()
        _replaceAnim.stop()
        _hintFlashDelayTimer.stop()
        _sharedBackgroundPulseAnim.stop()
        _pulseScaleAnim.stop()

        root._phase = "idle"
        root._flashSourceEvent = root._idleSnapshot()
        root._mainDisplayEvent = root._baselineEvent
        root._sharedBackgroundPulseOpacity = 0
        root._pulseScale = 1
        root._resetReplaceLayers()
        root._resetTracks()
    }

    function _startEnterTransition(event) {
        const wasHintPhase = root._hintPhase
        const outgoing = root._cloneEvent(root._hintPhase
            ? root._baselineEvent
            : (root._mainDisplayEvent.type !== "idle"
                ? root._mainDisplayEvent
                : root._baselineEvent))

        root._log("startEnterTransition", event)
        if (root._hintPhase) {
            _hintFlashDelayTimer.stop()
            _hintEnterAnim.stop()
            _hintExitAnim.stop()
            root._resetTracks()
        } else if (root._phase !== "idle") {
            _returnAnim.stop()
            _departAnim.stop()
            root._phase = "idle"
            root._mainDisplayEvent = root._baselineEvent
            root._resetTracks()
        }

        root._mainDisplayEvent = root._displayEvent(event)
        root._phase = "enter"

        _returnAnim.stop()
        _departAnim.stop()

        root._mainTrackY = root._mainTrackEnterY
        root._mainTrackScale = 0.92
        root._mainTrackOpacity = 0.15

        if (wasHintPhase) {
            root._flashSourceEvent = root._cloneEvent(root._flashSourceEvent)
            root._flashTrackY = root._windowHintEntryMeta.flashRole.targetY
            root._flashTrackScale = root._windowHintEntryMeta.flashRole.scale
            root._flashTrackOpacity = root._windowHintEntryMeta.flashRole.opacity
        } else {
            root._flashSourceEvent = outgoing
            root._flashTrackY = root._flashTrackCenterY
            root._flashTrackScale = 1
            root._flashTrackOpacity = 1
        }
        root._triggerSharedBackgroundPulse()

        Qt.callLater(function() {
            _departAnim.start()
        })
    }

    function _startWindowHint(event) {
        root._log("startWindowHint", event)
        root._mainDisplayEvent = root._baselineEvent
        root._flashSourceEvent = root._displayEvent(event)
        root._phase = "hint"

        _departAnim.stop()
        _returnAnim.stop()
        _hintEnterAnim.stop()
        _hintExitAnim.stop()

        root._mainTrackY = root._mainTrackCenterY
        root._mainTrackScale = 1
        root._mainTrackOpacity = 1
        root._flashTrackY = root._windowHintEntryMeta.flashRole.targetY
            - root._windowHintEntryMeta.flashRole.deltaY
        root._flashTrackScale = 0.92
        root._flashTrackOpacity = 0
        _hintFlashDelayTimer.restart()

        Qt.callLater(function() {
            _hintEnterAnim.start()
        })
    }

    function _updateWindowHint(event) {
        root._flashSourceEvent = root._displayEvent(event)
        root._triggerSharedBackgroundPulse()
    }

    function _triggerSharedBackgroundPulse() {
        if (root._overlaySessionActive)
            return

        _sharedBackgroundPulseAnim.stop()
        _pulseScaleAnim.stop()
        root._sharedBackgroundPulseOpacity = 0
        root._pulseScale = 1
        _sharedBackgroundPulseAnim.start()
        _pulseScaleAnim.start()
    }

    function _triggerEdgeReboundScale() {
        if (root._overlaySessionActive)
            return

        _pulseScaleAnim.stop()
        root._pulseScale = 1
        _pulseScaleAnim.start()
    }

    function _resetReplaceLayers() {
        root._replaceOutgoingVisible = false
        root._replaceIncomingVisible = false
        root._replaceOutgoingOpacity = 0
        root._replaceIncomingOpacity = 0
        root._replaceOutgoingTargetY = root._mainTrackCenterY + root._replaceOffset
        root._replaceOutgoingEvent = root._idleSnapshot()
        root._replaceIncomingEvent = root._idleSnapshot()
    }

    function _replaceActiveTransient(event) {
        const outgoingEvent = root._cloneEvent(
            root._replaceIncomingVisible ? root._replaceIncomingEvent : root._mainDisplayEvent
        )
        const outgoingFromIncomingLayer = root._replaceIncomingVisible
        const outgoingY = root._replaceIncomingVisible ? root._replaceIncomingY : root._mainTrackY
        const outgoingOpacity = root._replaceIncomingVisible ? root._replaceIncomingOpacity : root._mainTrackOpacity
        const shouldAnimateReplace = outgoingEvent.type !== "idle"
        const nextEvent = root._displayEvent(event)

        root._mainDisplayEvent = nextEvent
        root._flashSourceEvent = root._hintPhase
            ? root._cloneEvent(root._flashSourceEvent)
            : root._cloneEvent(root._baselineEvent)

        _returnAnim.stop()
        _hintEnterAnim.stop()
        _hintExitAnim.stop()
        _replaceAnim.stop()
        root._resetReplaceLayers()

        if (!root._transientPhase)
            root._phase = "hold"

        if (shouldAnimateReplace) {
            root._replaceOutgoingEvent = outgoingEvent
            root._replaceIncomingEvent = nextEvent
            root._replaceOutgoingY = outgoingY
            root._replaceOutgoingOpacity = outgoingOpacity
            root._replaceOutgoingTargetY = outgoingFromIncomingLayer
                ? outgoingY
                : (root._mainTrackCenterY + root._replaceOffset)
            root._replaceIncomingY = root._mainTrackCenterY - root._replaceOffset
            root._replaceIncomingOpacity = 0
            root._replaceOutgoingVisible = true
            root._replaceIncomingVisible = true

            root._mainTrackScale = 1
            root._mainTrackOpacity = 0
            _replaceAnim.start()
        } else {
            root._replaceOutgoingVisible = false
            root._replaceIncomingVisible = false
            root._mainTrackScale = 1
            root._mainTrackY = root._mainTrackCenterY
            root._mainTrackOpacity = 1
        }

        root._triggerSharedBackgroundPulse()
    }

    function _triggerHintFlash() {
        root._triggerSharedBackgroundPulse()
    }

    Timer {
        id: _hintFlashDelayTimer
        interval: Theme.anim.moveDuration
        repeat: false
        onTriggered: root._triggerHintFlash()
    }

    function _finishWindowHint() {
        if (root._phase !== "hint")
            return

        root._phase = "hint-exit"
        _hintEnterAnim.stop()
        root._triggerEdgeReboundScale()
        _hintExitAnim.start()
    }

    function _startExitTransition() {
        root._log("startExitTransition", root._mainDisplayEvent)
        root._phase = "exit"

        _departAnim.stop()
        _returnAnim.stop()
        _hintEnterAnim.stop()
        _hintExitAnim.stop()
        root._triggerEdgeReboundScale()

        root._mainTrackY = root._mainTrackCenterY
        root._mainTrackScale = 1
        root._mainTrackOpacity = 1
        root._flashTrackY = root._flashStripY
        root._flashTrackScale = root._flashScale
        root._flashTrackOpacity = 0.6

        _returnAnim.start()
    }

    Connections {
        enabled: root._listensToService
        target: SuperIslandService

        function onMainStateChanged() {
            if (root._phase === "idle")
                root._mainDisplayEvent = root._baselineEvent
        }

        function onActiveEventChanged() {
            const nextEvent = root._displayEvent(SuperIslandService.activeEvent)
            const previousEvent = root._cloneEvent(root._lastActiveEvent)

            if (nextEvent.type === "overlay" || previousEvent.type === "overlay") {
                root._lastActiveEvent = nextEvent.type === "overlay"
                    ? root._idleSnapshot()
                    : nextEvent
                return
            }

            if (nextEvent.relayReplace && previousEvent.type !== "idle") {
                if (previousEvent.type === "window")
                    root._startEnterTransition(nextEvent)
                else
                    root._replaceActiveTransient(nextEvent)
            } else if (nextEvent.type === "window" && previousEvent.type === "idle") {
                root._startWindowHint(nextEvent)
            } else if (nextEvent.type === "window" && previousEvent.type === "window") {
                if (root._hintPhase)
                    root._updateWindowHint(nextEvent)
                else
                    root._startWindowHint(nextEvent)
            } else if (nextEvent.type !== "idle" && previousEvent.type === "window") {
                root._startEnterTransition(nextEvent)
            } else if (nextEvent.type === "idle" && previousEvent.type === "window") {
                root._finishWindowHint()
            } else if (nextEvent.type !== "idle" && previousEvent.type === "idle") {
                root._startEnterTransition(nextEvent)
            } else if (nextEvent.type !== "idle" && previousEvent.type !== "idle") {
                root._startEnterTransition(nextEvent)
            } else if (nextEvent.type === "idle" && previousEvent.type !== "idle") {
                root._startExitTransition()
            }

            root._lastActiveEvent = nextEvent
        }
    }

    Connections {
        target: IslandOverlayService

        function onModePayloadChanged() {
            root._syncOverlayFlags()
            root._syncOverlayExtensionReservation()
        }

        function onStateChanged() {
            root._syncOverlayFlags()
            root._syncOverlayExtensionReservation()

            if (IslandOverlayService.state === "opening") {
                root._resetOverlayDrivenState()
                return
            }

            if (IslandOverlayService.state === "closed")
                root._resetOverlayDrivenState()
        }

        function onModeChanged() {
            root._syncOverlayFlags()
            root._syncOverlayExtensionReservation()
        }
    }

    Connections {
        target: _verticalReveal

        function onStateChanged() {
            if (IslandOverlayService.mode === "none")
                return

            if (_verticalReveal.state === "open" && IslandOverlayService.state === "opening") {
                IslandOverlayService.setSettledState(IslandOverlayService.mode, "open")
                return
            }

            if (_verticalReveal.state === "closed" && IslandOverlayService.state === "closing")
                IslandOverlayService.setSettledState(IslandOverlayService.mode, "closed")
        }
    }

    Item {
        id: _pillClip
        anchors.top: parent.top
        anchors.topMargin: root._padV
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true
        implicitWidth: _pillTransition.animatedWidth
        implicitHeight: root._verticalRevealClipHeight
        width: _pillTransition.animatedWidth
        height: root._verticalRevealClipHeight
        scale: root._pulseScale
        transformOrigin: Item.Center

        Rectangle {
            id: _pillBg
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root._verticalRevealSurfaceHeight
            radius: root._overlaySessionActive ? Theme.cornerRadius : (root._pillH / 2)
            color: Colors.surface
            border.color: Colors.border
            border.width: 1
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root._phase === "hint" || root._phase === "hint-exit")
                ? root._hintDividerY
                : (root._pillH + Math.max(0, (root._flashGap - height) / 2))
            width: Math.max(0, _pillBg.width - root._padH * 2)
            height: 1
            radius: height / 2
            color: Colors.border
            opacity: root._phase !== "idle" && !root._overlaySessionActive ? 0.35 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
        }

        Rectangle {
            anchors.fill: _pillBg
            radius: _pillBg.radius
            color: Colors.highlight
            opacity: root._transientPhase
                ? Math.min(1, root._transientAccentBaseOpacity + root._sharedBackgroundPulseOpacity)
                : 0
        }

        Rectangle {
            x: 0
            y: root._hintBackgroundY
            width: _pillBg.width
            height: root._hintBackgroundHeight
            radius: height / 2
            color: Colors.highlight
            opacity: root._hintBackgroundPulseOpacity
            visible: root.flashTrackVisible
        }

        Loader {
            id: _replaceLoader
            property var eventData: root._replaceOutgoingEvent
            property string resolvedIcon: root._resolvedIconSource(eventData.icon || "")
            anchors.horizontalCenter: parent.horizontalCenter
            active: root._replaceOutgoingVisible
            y: root._replaceOutgoingY
            opacity: root._replaceOutgoingOpacity
            sourceComponent: root._componentForEvent(eventData, false)
        }

        Loader {
            id: _replaceIncomingLoader
            property var eventData: root._replaceIncomingEvent
            property string resolvedIcon: root._resolvedIconSource(eventData.icon || "")
            anchors.horizontalCenter: parent.horizontalCenter
            active: root._replaceIncomingVisible
            y: root._replaceIncomingY
            opacity: root._replaceIncomingOpacity
            sourceComponent: root._componentForEvent(eventData, false)
        }

        Loader {
            id: _mainLoader
            property var eventData: root._mainDisplayEvent
            property string resolvedIcon: root._resolvedIconSource(eventData.icon || "")
            anchors.horizontalCenter: parent.horizontalCenter
            y: root._mainTrackY
            scale: root._mainTrackScale
            opacity: (root._replaceOutgoingVisible || root._replaceIncomingVisible) ? 0 : root._mainTrackOpacity
            sourceComponent: root._componentForEvent(eventData, false)
        }

        Loader {
            id: _stripLoader
            property var eventData: root._flashSourceEvent
            property string resolvedIcon: root._resolvedIconSource(eventData.icon || "")
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.flashTrackVisible
            y: root._flashTrackY
            opacity: root._flashTrackOpacity
            scale: root._flashTrackScale
            height: root._flashRowH
            clip: true
            sourceComponent: root._componentForEvent(eventData, true)
        }

        Loader {
            id: _overlayDeckLoader

            active: root._overlaySessionActive
            anchors {
                top: parent.top
                topMargin: root._flashRowBaseY
                left: parent.left
                right: parent.right
                leftMargin: 10
                rightMargin: 10
            }
            height: root._overlayBodyHeight
            visible: active
            sourceComponent: _overlayDeckComponent
        }
    }

    ParallelAnimation {
        id: _replaceAnim

        SequentialAnimation {
            PauseAnimation {
                duration: root._replaceDelay
            }

            ParallelAnimation {
                NumberAnimation {
                    target: root
                    property: "_replaceIncomingY"
                    to: root._mainTrackCenterY
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }

                NumberAnimation {
                    target: root
                    property: "_replaceIncomingOpacity"
                    to: 1
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
        }

        NumberAnimation {
            target: root
            property: "_replaceOutgoingY"
            to: root._replaceOutgoingTargetY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_replaceOutgoingOpacity"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: {
            root._resetReplaceLayers()
            root._mainTrackY = root._mainTrackCenterY
            root._mainTrackOpacity = 1
        }
    }

    ParallelAnimation {
        id: _departAnim

        NumberAnimation {
            target: root
            property: "_mainTrackY"
            to: root._mainTrackCenterY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_mainTrackScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_mainTrackOpacity"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_flashTrackY"
            to: root._flashStripY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_flashTrackScale"
            to: root._flashScale
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_flashTrackOpacity"
            to: 0.6
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: {
            if (root._phase === "enter")
                root._phase = "hold"
        }
    }

    ParallelAnimation {
        id: _returnAnim

        NumberAnimation {
            target: root
            property: "_mainTrackY"
            to: root._mainTrackEnterY
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root
            property: "_mainTrackScale"
            to: 0.92
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root
            property: "_mainTrackOpacity"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_flashTrackY"
            to: root._returnTrackCenterY
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root
            property: "_flashTrackScale"
            to: 1
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root
            property: "_flashTrackOpacity"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: {
            const returningEvent = root._displayEvent(root._flashSourceEvent)
            const returningFromWindowHint = returningEvent.type === "window"
            const handoffY = root._flashTrackY
            const handoffScale = root._flashTrackScale
            const handoffOpacity = root._flashTrackOpacity

            root._mainDisplayEvent = returningFromWindowHint
                ? root._baselineEvent
                : (returningEvent.type !== "idle" ? returningEvent : root._baselineEvent)
            root._mainTrackY = returningFromWindowHint ? root._mainTrackCenterY : handoffY
            root._mainTrackScale = returningFromWindowHint ? 1 : handoffScale
            root._mainTrackOpacity = returningFromWindowHint ? 1 : handoffOpacity
            root._phase = "idle"
            root._flashSourceEvent = root._idleSnapshot()
            root._flashTrackY = root._flashStripY
            root._flashTrackScale = root._flashScale
            root._flashTrackOpacity = 0
        }
    }

    ParallelAnimation {
        id: _hintEnterAnim

        NumberAnimation {
            target: root
            property: "_mainTrackY"
            to: root._windowHintEntryMeta.mainRole.targetY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_mainTrackScale"
            to: root._flashScale
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_mainTrackOpacity"
            to: 0.6
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_flashTrackY"
            to: root._windowHintEntryMeta.flashRole.targetY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_flashTrackScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_flashTrackOpacity"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    ParallelAnimation {
        id: _hintExitAnim

        NumberAnimation {
            target: root
            property: "_mainTrackY"
            to: root._mainTrackCenterY
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_flashTrackY"
            to: root._hintTrackY - Theme.barWidget.contentPaddingV * 3
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_flashTrackScale"
            to: 0.96
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_flashTrackOpacity"
            to: 0
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: {
            root._phase = "idle"
            root._flashSourceEvent = root._idleSnapshot()
            root._mainDisplayEvent = root._baselineEvent
            root._sharedBackgroundPulseOpacity = 0
            root._resetTracks()
        }
    }

    SequentialAnimation {
        id: _sharedBackgroundPulseAnim

        NumberAnimation {
            target: root
            property: "_sharedBackgroundPulseOpacity"
            from: 0
            to: 0.16
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root
            property: "_sharedBackgroundPulseOpacity"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    SequentialAnimation {
        id: _pulseScaleAnim

        NumberAnimation {
            target: root
            property: "_pulseScale"
            from: 1
            to: 1.018
            duration: Theme.anim.pulseSpringDuration
            easing.type: Theme.anim.pulseSpringType
            easing.overshoot: Theme.anim.pulseSpringOvershoot
        }

        NumberAnimation {
            target: root
            property: "_pulseScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    Component {
        id: _idleComponent

Item {
    implicitWidth: _idleRow.implicitWidth
    implicitHeight: root._pillH

    RowLayout {
        id: _idleRow
        anchors.centerIn: parent
        spacing: Theme.barWidget.iconLabelSpacing

        Text {
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
            text: Qt.formatDateTime(currentTime, "hh:mm")
            color: Colors.text
        }

        Rectangle {
                    visible: SuperIslandService.hasPendingEvents
                    implicitWidth: Theme.barWidget.indicatorDotSize
                    implicitHeight: Theme.barWidget.indicatorDotSize
                    radius: width / 2
                    color: Colors.highlight
                    opacity: Colors.highlightAlpha + 0.2
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    Component {
        id: _compactEventComponent

        Item {
            implicitWidth: _eventRow.implicitWidth
            implicitHeight: root._pillH

            RowLayout {
                id: _eventRow
                anchors.centerIn: parent
                spacing: Theme.barWidget.iconLabelSpacing

                Image {
                    source: resolvedIcon
                    sourceSize.width: Theme.barWidget.primaryIconSize
                    sourceSize.height: Theme.barWidget.primaryIconSize
                    width: Theme.barWidget.primaryIconSize
                    height: Theme.barWidget.primaryIconSize
                    fillMode: Image.PreserveAspectFit
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: eventData.title || ""
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                        Layout.maximumWidth: Math.round(220 * Theme.uiScale)
                    }

                    Text {
                        visible: text !== ""
                        text: eventData.subtitle || ""
                        color: Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                        Layout.maximumWidth: Math.round(180 * Theme.uiScale)
                    }
                }
            }
        }
    }

    Component {
        id: _mainNotificationCardComponent

        Item {
            implicitWidth: _card.implicitWidth
            implicitHeight: _card.implicitHeight

            IslandCards.IslandNotificationCard {
                id: _card
                event: eventData
                iconSource: resolvedIcon
                anchors.fill: parent
            }

            Connections {
                target: _card
                function onActivated() {
                    if (!root._activateNotificationEvent(eventData))
                        BarLayoutService.notificationHistoryOpen = true
                }
            }
        }
    }

    Component {
        id: _mainMediaCardComponent

        IslandCards.IslandMediaCard {
            event: eventData
            iconSource: resolvedIcon
            compact: true
        }
    }

    Component {
        id: _mainWorkspaceCardComponent

        IslandCards.IslandWorkspaceCard {
            event: eventData
            iconSource: resolvedIcon
        }
    }

    Component {
        id: _stripCompactEventComponent

        Item {
            implicitWidth: _stripEventRow.implicitWidth
            implicitHeight: root._flashRowH

            RowLayout {
                id: _stripEventRow
                anchors.centerIn: parent
                spacing: Theme.barWidget.iconLabelSpacing

                Image {
                    source: resolvedIcon
                    sourceSize.width: Theme.barWidget.primaryIconSize
                    sourceSize.height: Theme.barWidget.primaryIconSize
                    width: Theme.barWidget.primaryIconSize
                    height: Theme.barWidget.primaryIconSize
                    fillMode: Image.PreserveAspectFit
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: eventData.title || ""
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                        Layout.maximumWidth: Math.round(220 * Theme.uiScale)
                    }

                    Text {
                        visible: text !== ""
                        text: eventData.subtitle || ""
                        color: Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                        Layout.maximumWidth: Math.round(180 * Theme.uiScale)
                    }
                }
            }
        }
    }

    Component {
        id: _stripNotificationCardComponent

        Item {
            implicitWidth: _card.implicitWidth
            implicitHeight: _card.implicitHeight

            IslandCards.IslandNotificationCard {
                id: _card
                event: eventData
                iconSource: resolvedIcon
                anchors.fill: parent
            }

            Connections {
                target: _card
                function onActivated() {
                    if (!root._activateNotificationEvent(eventData))
                        BarLayoutService.notificationHistoryOpen = true
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root._overlaySessionActive
        onActivated: IslandOverlayService.closeOverlay("super-island-shortcut")
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !BarLayoutService.suppressWidgetPrimaryActions && !root._overlaySessionActive
        onClicked: {
            IslandOverlayService.toggleOverlay(root._preferredOverlayPage(), "super-island", "")
        }
    }

    Component {
        id: _stripMediaCardComponent

        IslandCards.IslandMediaCard {
            event: eventData
            iconSource: resolvedIcon
            compact: false
        }
    }

    Component {
        id: _stripWorkspaceCardComponent

        IslandCards.IslandWorkspaceCard {
            event: eventData
            iconSource: resolvedIcon
        }
    }

    Component {
        id: _overlayDeckComponent

        IslandCards.ExpandedPanelDeck {}
    }
}
