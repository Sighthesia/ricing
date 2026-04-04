import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
    readonly property bool flashTrackVisible: root._phase !== "idle"
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
    readonly property int _windowHintStagePadV: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int _windowHintRowGap: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int _windowHintWorkspaceColumnGap: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int _windowHintSideHeight:
        Math.max(30, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV * 2)
    readonly property int _windowHintPrimaryHeight:
        Math.max(44, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV * 5)
    readonly property int _windowHintTitleHeight:
        Math.max(30, Theme.fontSizeBody + Theme.barWidget.badgePaddingV * 6)
    readonly property real _hintTrackY: root._mainTrackCenterY - root._hintLift
    readonly property real _hintDividerY: root._pillH + Math.max(0, (root._flashGap - 1) / 2)
    readonly property real _hintBackgroundY: root._flashRowBaseY
    readonly property real _hintBackgroundHeight: root._flashRowH
    readonly property real _hintBackgroundPulseOpacity:
        root._hintPhase && !root._isHintEventType(root._flashSourceEvent.type)
            ? root._sharedBackgroundPulseOpacity
            : 0
    readonly property real _returnTrackCenterY:
        root._trackCenterY(_stripLoader.item, root._pillH, root._flashSourceEvent, false)
    readonly property real _overlayBodyHeight: Math.round(528 * Theme.uiScale)
    readonly property real _overlayDetachedOffset: Theme.barHeight
    readonly property real _overlayDetachedY: root._overlayDetachedOffset
    readonly property real _overlayRevealLift:
        Math.max(8, Theme.barWidget.contentPaddingV * 4)
    readonly property real _overlayAttachmentOverlap: 1
    readonly property real _overlayShellRadius: Theme.cornerRadius
    readonly property real _overlayPillBackgroundWidth: _pillBg.width
    readonly property real _overlayBridgeOutset:
        root._overlayAttachmentOverlap
    readonly property real _overlayInwardCornerRadius:
        Math.max(10, Math.min(root._overlayShellRadius, Math.round(18 * Theme.uiScale)))
    readonly property real _overlayInwardCornerDepth:
        Math.max(root._overlayInwardCornerRadius, Math.round(28 * Theme.uiScale))
    readonly property bool _detachedHintActive:
        root._isFullHintEventType(root._flashSourceEvent.type) || root._phase === "hint-exit"
    readonly property bool _attachedPanelActive:
        root._overlaySessionActive || root._detachedHintActive
    readonly property bool _attachedPanelExpanded:
        root._overlaySessionActive ? root._overlayExpandedActive : (root._phase === "hint")
    readonly property real _attachedPanelWidth:
        root._overlaySessionActive ? root._overlayExpandedWidth : root._detachedHintWidth
    readonly property real _attachedPanelHeight:
        root._overlaySessionActive ? root._overlayBodyHeight : root._detachedHintHeight
    readonly property real _detachedHintWidth:
        Math.max(
            root._collapsedWidth,
            (_detachedHintMeasureLoader.item ? _detachedHintMeasureLoader.item.implicitWidth : root._collapsedWidth) + 2
        )
    readonly property real _detachedHintHeight:
        Math.max(
            root._transientExpandedHeight,
            (_detachedHintMeasureLoader.item ? _detachedHintMeasureLoader.item.implicitHeight : root._fullHintExpandedPillHeight) + 2
        )
    readonly property real _attachedPanelOpacity:
        root._overlaySessionActive
            ? (root._overlayExpandedActive ? 1 : 0)
            : (root._detachedHintActive ? root._flashTrackOpacity : 0)
    readonly property real _attachedPanelScale:
        root._overlaySessionActive
            ? (root._overlayExpandedActive ? 1 : 0.985)
            : (root._detachedHintActive ? root._flashTrackScale : 1)
    readonly property real _transientExpandedHeight: root._pillH + root._flashGap + root._flashRowH
    readonly property real _collapsedPillHeight: root._pillH
    readonly property bool _pillExpanded:
        root._phase === "enter" || root._phase === "hold" || root._phase === "hint"

    readonly property real _overlayExpandedWidth: {
        const availableWidth = Math.max(
            760,
            BarLayoutService.barContentWidth - Math.max(24, Theme.barPadding * 2)
        )
        return Math.max(root._collapsedWidth, Math.min(Math.round(980 * Theme.uiScale), availableWidth))
    }

    // Reserve the full window-hint surface with a stable maximum height so the
    // layer-shell bar window does not resize every animation frame while the
    // hint capsules animate their own heights internally.
    readonly property real _fullHintExpandedPillHeight:
        root._pillH
        + root._windowHintSideHeight * 2
        + root._windowHintPrimaryHeight
        + root._windowHintWorkspaceColumnGap * 2
        + root._windowHintRowGap
        + root._windowHintTitleHeight
        + Theme.barWidget.contentPaddingV * 2
        + root._windowHintStagePadV * 2
    readonly property bool _fullHintExpandedSurface:
        root._isFullHintEventType(root._flashSourceEvent.type)
        || (root._hintPhase && root._isFullHintEventType(SuperIslandService.activeEvent.type))
    readonly property real _expandedPillHeight: root._transientExpandedHeight
    readonly property real _verticalRevealSurfaceHeight: _verticalReveal.surfaceHeight
    readonly property real _verticalRevealClipHeight: _verticalReveal.clipHeight

    readonly property real _collapsedWidth:
        (_mainLoader.item ? _mainLoader.item.implicitWidth : 0) + root._padH * 2
    readonly property real _expandedWidth:
        Math.max(
            root._collapsedWidth,
            (_stripLoader.item ? _stripLoader.item.implicitWidth : 0) + root._padH * 2
        )

    readonly property real _mainTrackEnterY:
        -Math.max(root._pillH, _mainLoader.item ? _mainLoader.item.implicitHeight : root._pillH)
    readonly property real _returnWidth:
        (_stripLoader.item ? _stripLoader.item.implicitWidth : 0) + root._padH * 2
    readonly property real _transitionCollapsedWidth:
        root._phase === "exit" ? root._returnWidth : root._collapsedWidth
    readonly property real _idleOpticalOffset: 0
    readonly property bool _hintPhase: root._phase === "hint" || root._phase === "hint-exit"
    readonly property bool _listensToService: true
    readonly property real _transientAccentBaseOpacity: 0
    readonly property real _overlayReservedExtension:
        root._attachedPanelActive
            ? root._overlayDetachedOffset + root._attachedPanelHeight
            : 0
    readonly property real _overlayShellY: _pillClip.y
    readonly property real _overlayShellHeight:
        Math.max(0, (_overlayPanelHost.y + root._attachedPanelHeight) - root._overlayShellY)

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
        animateSurface: false
        sharedTransition: _pillTransition
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
        animateHeight: true
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
            sticky: !!source.sticky,
            title: source.title || "",
            subtitle: source.subtitle || "",
            icon: source.icon || "",
            workspaceLabel: source.workspaceLabel || "",
            timeoutMs: source.timeoutMs || 0,
            revision: source.revision || 0,
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

    function _isHintEventType(eventType) {
        return eventType === "window" || eventType === "window-hint"
    }

    function _isFullHintEventType(eventType) {
        return eventType === "window-hint"
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
        if (event.type === "window-hint")
            return _windowHintCardComponent
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
            || root._detachedHintActive
            ? root._overlayReservedExtension
            : 0

        if (root._attachedPanelActive) {
            BarLayoutService.setTransientExtension("super-island-overlay", reservedHeight)
            return
        }

        BarLayoutService.clearTransientExtension("super-island-overlay")
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
        const fullHint = root._isFullHintEventType(event.type)

        root._log("startWindowHint", event)
        root._mainDisplayEvent = root._baselineEvent
        root._flashSourceEvent = root._displayEvent(event)
        root._phase = "hint"
        root._syncOverlayExtensionReservation()

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
        root._syncOverlayExtensionReservation()
        root._triggerSharedBackgroundPulse()
    }

    function _triggerSharedBackgroundPulse() {
        _sharedBackgroundPulseAnim.stop()
        _pulseScaleAnim.stop()
        root._sharedBackgroundPulseOpacity = 0
        root._pulseScale = 1
        _sharedBackgroundPulseAnim.start()
        _pulseScaleAnim.start()
    }

    function _triggerEdgeReboundScale() {
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

    function _finishWindowHint() {
        if (root._phase !== "hint")
            return

        root._phase = "hint-exit"
        root._syncOverlayExtensionReservation()
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
            const nextIsHint = root._isHintEventType(nextEvent.type)
            const previousIsHint = root._isHintEventType(previousEvent.type)

            if (nextEvent.type === "overlay" || previousEvent.type === "overlay") {
                root._lastActiveEvent = nextEvent.type === "overlay"
                    ? root._idleSnapshot()
                    : nextEvent
                return
            }

            if (nextEvent.relayReplace && previousEvent.type !== "idle") {
                if (previousIsHint)
                    root._startEnterTransition(nextEvent)
                else
                    root._replaceActiveTransient(nextEvent)
            } else if (nextIsHint && previousEvent.type === "idle") {
                root._startWindowHint(nextEvent)
            } else if (nextIsHint && previousIsHint) {
                if (root._hintPhase)
                    root._updateWindowHint(nextEvent)
                else
                    root._startWindowHint(nextEvent)
            } else if (nextEvent.type !== "idle" && previousIsHint) {
                root._startEnterTransition(nextEvent)
            } else if (nextEvent.type === "idle" && previousIsHint) {
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
                _overlayCloseSettleTimer.stop()
                _overlayOpenSettleTimer.restart()
                return
            }

            if (IslandOverlayService.state === "closing") {
                _overlayOpenSettleTimer.stop()
                _overlayCloseSettleTimer.restart()
                return
            }

            _overlayOpenSettleTimer.stop()
            _overlayCloseSettleTimer.stop()
        }

        function onModeChanged() {
            root._syncOverlayFlags()
            root._syncOverlayExtensionReservation()
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
            radius: root._pillH / 2
            color: Colors.surface
            border.color: Colors.border
            border.width: root._attachedPanelActive ? 0 : 1
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
            opacity: root._phase !== "idle" && root._flashSourceEvent.type !== "window-hint" ? 0.35 : 0

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
            visible: root.flashTrackVisible && root._flashSourceEvent.type !== "window-hint"
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
            active: root.flashTrackVisible && !root._isFullHintEventType(eventData.type)
            y: root._flashTrackY
            opacity: root._flashTrackOpacity
            scale: root._flashTrackScale
            height: root._isFullHintEventType(eventData.type) ? root._verticalRevealSurfaceHeight : root._flashRowH
            clip: !root._isFullHintEventType(eventData.type)
            sourceComponent: root._componentForEvent(eventData, true)
        }

    }

    // Draw one continuous shell behind the pill and the attached panel so the
    // overlay reads as a single surface rather than stacked rectangles.
    Item {
        id: _overlayShellHost

        visible: root._attachedPanelActive
        width: root._attachedPanelWidth
        height: root._overlayShellHeight
        y: root._overlayShellY
        z: -1
        opacity: root._attachedPanelOpacity
        anchors.horizontalCenter: _pillClip.horizontalCenter

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true

            ShapePath {
                id: _overlayShellPath

                readonly property real _minR: 0.01
                readonly property real _pillWidth: _pillClip.width
                readonly property real _pillLeft: (_overlayShellHost.width - _pillWidth) / 2
                readonly property real _pillRight: _pillLeft + _pillWidth
                readonly property real _pillRadius: Math.max(_minR, root._pillH / 2)
                readonly property real _panelLeft: 0.5
                readonly property real _panelRight: _overlayShellHost.width - 0.5
                readonly property real _panelTop:
                    Math.max(root._pillH, _overlayPanelHost.y - _overlayShellHost.y + root._overlayAttachmentOverlap)
                readonly property real _panelBottom: _overlayShellHost.height - 0.5
                readonly property real _panelRadius:
                    Math.max(_minR, Math.min(root._overlayShellRadius, Math.max(1, (_panelBottom - _panelTop) / 2)))
                readonly property real _availableCornerHeight:
                    Math.max(_minR, _panelTop - root._pillH)
                readonly property real _neckRight:
                    Math.max(
                        _pillRight,
                        Math.min(_panelRight - _panelRadius - _minR, _pillRight + root._overlayBridgeOutset)
                    )
                readonly property real _neckLeft:
                    Math.min(
                        _pillLeft,
                        Math.max(_panelLeft + _panelRadius + _minR, _pillLeft - root._overlayBridgeOutset)
                    )
                readonly property real _cornerStartY:
                    _panelTop - _cutRadius
                readonly property real _cornerHorizontalSpan:
                    Math.max(
                        _minR,
                        Math.min(
                            _panelRight - _panelRadius - _neckRight,
                            _neckLeft - (_panelLeft + _panelRadius)
                        )
                    )
                readonly property real _cutRadius:
                    Math.max(
                        _minR,
                        Math.min(root._overlayInwardCornerRadius, _availableCornerHeight, _cornerHorizontalSpan)
                    )
                readonly property real _rightShoulderX: _neckRight + _cutRadius
                readonly property real _leftShoulderX: _neckLeft - _cutRadius

                strokeColor: Colors.border
                strokeWidth: 1
                fillColor: Colors.surface
                startX: _pillLeft + _pillRadius
                startY: 0

                PathLine {
                    x: _overlayShellPath._pillRight - _overlayShellPath._pillRadius
                    y: 0
                }

                PathArc {
                    x: _overlayShellPath._pillRight
                    y: _overlayShellPath._pillRadius
                    radiusX: _overlayShellPath._pillRadius
                    radiusY: _overlayShellPath._pillRadius
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: _overlayShellPath._pillRight
                    y: root._pillH
                }

                PathLine {
                    x: _overlayShellPath._neckRight
                    y: root._pillH
                }

                PathLine {
                    x: _overlayShellPath._neckRight
                    y: _overlayShellPath._cornerStartY
                }

                PathLine {
                    x: _overlayShellPath._neckRight
                    y: _overlayShellPath._cornerStartY
                }

                PathArc {
                    x: _overlayShellPath._rightShoulderX
                    y: _overlayShellPath._panelTop
                    radiusX: _overlayShellPath._cutRadius
                    radiusY: _overlayShellPath._cutRadius
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: _overlayShellPath._panelRight - _overlayShellPath._panelRadius
                    y: _overlayShellPath._panelTop
                }

                PathArc {
                    x: _overlayShellPath._panelRight
                    y: _overlayShellPath._panelTop + _overlayShellPath._panelRadius
                    radiusX: _overlayShellPath._panelRadius
                    radiusY: _overlayShellPath._panelRadius
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: _overlayShellPath._panelRight
                    y: _overlayShellPath._panelBottom - _overlayShellPath._panelRadius
                }

                PathArc {
                    x: _overlayShellPath._panelRight - _overlayShellPath._panelRadius
                    y: _overlayShellPath._panelBottom
                    radiusX: _overlayShellPath._panelRadius
                    radiusY: _overlayShellPath._panelRadius
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: _overlayShellPath._panelLeft + _overlayShellPath._panelRadius
                    y: _overlayShellPath._panelBottom
                }

                PathArc {
                    x: _overlayShellPath._panelLeft
                    y: _overlayShellPath._panelBottom - _overlayShellPath._panelRadius
                    radiusX: _overlayShellPath._panelRadius
                    radiusY: _overlayShellPath._panelRadius
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: _overlayShellPath._panelLeft
                    y: _overlayShellPath._panelTop + _overlayShellPath._panelRadius
                }

                PathArc {
                    x: _overlayShellPath._panelLeft + _overlayShellPath._panelRadius
                    y: _overlayShellPath._panelTop
                    radiusX: _overlayShellPath._panelRadius
                    radiusY: _overlayShellPath._panelRadius
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: _overlayShellPath._leftShoulderX
                    y: _overlayShellPath._panelTop
                }

                PathArc {
                    x: _overlayShellPath._neckLeft
                    y: _overlayShellPath._cornerStartY
                    radiusX: _overlayShellPath._cutRadius
                    radiusY: _overlayShellPath._cutRadius
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: _overlayShellPath._neckLeft
                    y: _overlayShellPath._cornerStartY
                }

                PathLine {
                    x: _overlayShellPath._neckLeft
                    y: root._pillH
                }

                PathLine {
                    x: _overlayShellPath._pillLeft
                    y: root._pillH
                }

                PathLine {
                    x: _overlayShellPath._pillLeft
                    y: _overlayShellPath._pillRadius
                }

                PathArc {
                    x: _overlayShellPath._pillLeft + _overlayShellPath._pillRadius
                    y: 0
                    radiusX: _overlayShellPath._pillRadius
                    radiusY: _overlayShellPath._pillRadius
                    direction: PathArc.Clockwise
                }
            }
        }
    }

    // Keep the content host detached from layout, but let the shell overlap the
    // connection seam by 1px to avoid fractional-scaling hairlines.
    Item {
        id: _overlayPanelHost

        visible: root._attachedPanelActive
        enabled: root._attachedPanelActive
        width: root._attachedPanelWidth
        height: root._attachedPanelHeight
        y: root._overlayDetachedY - root._overlayAttachmentOverlap
            + (root._attachedPanelExpanded ? 0 : -root._overlayRevealLift)
        opacity: root._attachedPanelOpacity
        scale: root._attachedPanelScale
        anchors.horizontalCenter: _pillClip.horizontalCenter
        transformOrigin: Item.Top

        Behavior on y {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        Loader {
            id: _overlayDeckLoader
            property var eventData: root._flashSourceEvent

            active: root._attachedPanelActive
            anchors.fill: parent
            anchors.margins: 1
            sourceComponent: root._overlaySessionActive ? _overlayDeckComponent : _windowHintCardComponent
        }
    }

    Loader {
        id: _detachedHintMeasureLoader
        property var eventData: root._flashSourceEvent

        active: root._detachedHintActive
        visible: false
        enabled: false
        sourceComponent: _windowHintCardComponent
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
            to: root._isFullHintEventType(root._flashSourceEvent.type)
                ? root._mainTrackCenterY
                : root._windowHintEntryMeta.mainRole.targetY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_mainTrackScale"
            to: root._isFullHintEventType(root._flashSourceEvent.type) ? 1 : root._flashScale
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_mainTrackOpacity"
            to: root._isFullHintEventType(root._flashSourceEvent.type) ? 1 : 0.6
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
            if (root._isFullHintEventType(root._flashSourceEvent.type)) {
                root._flashSourceEvent = root._idleSnapshot()
            }
            root._phase = "idle"
            root._flashSourceEvent = root._idleSnapshot()
            root._mainDisplayEvent = root._baselineEvent
            root._sharedBackgroundPulseOpacity = 0
            root._resetTracks()
            root._syncOverlayExtensionReservation()
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
        id: _windowHintCardComponent

        IslandCards.IslandWindowHintCard {
            event: eventData
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

        IslandCards.ExpandedPanelDeck {
            drawSurface: false
        }
    }
}
