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

    readonly property bool _debugLogging: liveInstance
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
    readonly property real _attachedRevealSeedHeight: 0
    readonly property real _attachedRevealSeedWidth:
        Math.max(root._overlayPillBackgroundWidth, root._collapsedWidth)
    readonly property real _pillThrowLift:
        Math.max(6, Math.round(root._pillH * 0.2))
    readonly property real _pillThrowDrop:
        Math.max(10, Math.round(root._pillH * 0.32))
    readonly property int _pillThrowLeadDuration:
        Math.max(1, Math.round(Theme.anim.highlightDuration * 0.5))
    readonly property int _pillThrowDropDuration:
        Math.max(1, Math.round(Theme.anim.highlightDuration * 0.7))
    readonly property bool _detachedHintActive:
        root._isFullHintEventType(root._flashSourceEvent.type) || root._phase === "hint-exit"
    readonly property bool _attachedPanelActive:
        root._overlaySessionActive || root._detachedHintActive
    readonly property bool _overlayClosing:
        root._overlaySessionActive && IslandOverlayService.state === "closing"
    readonly property bool _attachedPanelExpanded:
        root._overlaySessionActive
            ? (root._overlayExpandedActive || root._overlayClosing)
            : (root._phase === "hint" || root._phase === "hint-exit")
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
            ? ((root._overlayExpandedActive || root._overlayClosing) ? 1 : 0)
            : (root._detachedHintActive
                ? 1
                : 0)
    readonly property real _attachedPanelScale:
        root._overlaySessionActive
            ? ((root._overlayExpandedActive || root._overlayClosing) ? 1 : 0.985)
            : 1
    readonly property real _attachedContentScale:
        root._overlaySessionActive ? 1 : root._attachedPanelScale
    readonly property real _attachedSurfaceScale:
        root._pulseScale * root._attachedContentScale
    readonly property real _attachedPulseOpacity:
        root._attachedPanelActive ? root._sharedBackgroundPulseOpacity : 0
    readonly property real _transientExpandedHeight: root._pillH + root._flashGap + root._flashRowH
    readonly property real _collapsedPillHeight: root._pillH
    readonly property bool _pillExpanded:
        !root._attachedPanelActive
        && (root._phase === "enter" || root._phase === "hold" || root._phase === "hint")

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
        Math.max(0, (_overlayPanelHost.y + root._attachedPanelVisibleHeight) - root._overlayShellY)

    Component.onCompleted: {
        currentTime = new Date()
        root._syncOverlayFlags()
        const initialActiveEvent = root._displayEvent(root._listensToService ? SuperIslandService.activeEvent : root._idleSnapshot())
        root._mainDisplayEvent = initialActiveEvent.type !== "idle" ? initialActiveEvent : root._baselineEvent
        root._lastActiveEvent = initialActiveEvent
        root._resetTracks()
        root._attachedPanelRevealWidth = root._attachedPanelActive ? root._attachedPanelWidth : 0
        root._attachedPanelRevealHeight = root._attachedPanelActive ? root._attachedPanelHeight : 0
        root._attachedContentOpacity = root._attachedPanelActive ? 1 : 0
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
    property bool _overlayPulsePending: false
    property string _pulseOwner: ""
    property real _attachedPanelRevealWidth: 0
    property real _attachedPanelRevealHeight: 0
    property real _attachedContentOpacity: 0
    property real _pillThrowOffsetY: 0
    property bool _attachedRevealUseHandoffCurve: false
    property var _overlayHandoffHintEvent: _idleSnapshot()
    property bool _overlayHintHandoffActive: false
    readonly property real _attachedPanelVisibleWidth:
        root._attachedPanelActive
            ? Math.max(
                root._attachedRevealSeedWidth,
                Math.min(root._attachedPanelRevealWidth, root._attachedPanelWidth)
            )
            : 0
    readonly property real _attachedPanelVisibleHeight:
        root._attachedPanelActive
            ? Math.max(0, Math.min(root._attachedPanelRevealHeight, root._attachedPanelHeight))
            : 0
    readonly property real _attachedWidthRevealProgress:
        root._attachedPanelWidth > root._attachedRevealSeedWidth
            ? Math.max(
                0,
                Math.min(
                    1,
                    (root._attachedPanelVisibleWidth - root._attachedRevealSeedWidth)
                        / (root._attachedPanelWidth - root._attachedRevealSeedWidth)
                )
            )
            : 1
    readonly property real _attachedHeightRevealProgress:
        root._attachedPanelHeight > root._attachedRevealSeedHeight
            ? Math.max(
                0,
                Math.min(
                    1,
                    (root._attachedPanelVisibleHeight - root._attachedRevealSeedHeight)
                        / (root._attachedPanelHeight - root._attachedRevealSeedHeight)
                )
            )
            : 1
    readonly property real _attachedRevealProgress:
        root._attachedPanelActive
            ? Math.min(root._attachedWidthRevealProgress, root._attachedHeightRevealProgress)
            : 0
    readonly property real _attachedRevealYOffset:
        (1 - root._attachedRevealProgress) * root._overlayRevealLift
    readonly property bool _hintRevealSettled:
        root._detachedHintActive
        && !root._overlaySessionActive
        && !_attachedRevealDelayTimer.running
        && !_pillThrowOutAnim.running
        && !_attachedRevealAnim.running
        && root._attachedContentOpacity >= 0.99
        && root._attachedPanelVisibleWidth >= root._detachedHintWidth - 1
        && root._attachedPanelVisibleHeight >= root._detachedHintHeight - 1
    readonly property bool _showOverlayHandoffHint:
        root._overlayHintHandoffActive
        && root._overlaySessionActive
        && root._attachedRevealProgress < 0.78
    readonly property bool _attachedCollapseTailHidden:
        root._attachedPanelActive
        && (root._phase === "hint-exit" || root._overlayClosing)
        && (root._attachedRevealProgress <= 0.1
            || root._attachedPanelVisibleHeight <= Math.max(6, root._overlayAttachmentOverlap + 4))

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

    function _logPulse(message) {
        if (!root._debugLogging)
            return

        console.log(
            "SuperIslandWidget[" + root.debugInstanceLabel + "]: pulse", message,
            "owner=", root._pulseOwner,
            "phase=", root._phase,
            "flashType=", root._flashSourceEvent.type || "",
            "overlayMode=", IslandOverlayService.mode,
            "overlayState=", IslandOverlayService.state,
            "overlaySessionActive=", root._overlaySessionActive,
            "overlayExpandedActive=", root._overlayExpandedActive,
            "overlayPulsePending=", root._overlayPulsePending,
            "pulseAnimRunning=", _sharedBackgroundPulseAnim.running,
            "scaleAnimRunning=", _pulseScaleAnim.running
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
        const overlayModeActive = IslandOverlayService.mode !== "none"
        const wasOverlaySessionActive = root._overlaySessionActive
        const wasOverlayExpandedActive = root._overlayExpandedActive
        root._overlaySessionActive = overlayModeActive
            && IslandOverlayService.state !== "closed"
        root._overlayExpandedActive = overlayModeActive
            && (IslandOverlayService.state === "opening" || IslandOverlayService.state === "open")

        if (!wasOverlayExpandedActive && root._overlayExpandedActive)
            root._overlayPulsePending = true

        if (!root._overlaySessionActive)
            root._overlayPulsePending = false

        if (!root._overlaySessionActive) {
            root._overlayHintHandoffActive = false
            root._overlayHandoffHintEvent = root._idleSnapshot()
        }

        if (overlayModeActive)
            _hintFlashDelayTimer.stop()
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
        root._triggerSharedBackgroundPulse("hint-update")

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
        if (fullHint)
            root._startAttachedReveal()
        _hintFlashDelayTimer.restart()

        Qt.callLater(function() {
            _hintEnterAnim.start()
        })
    }

    function _updateWindowHint(event) {
        root._flashSourceEvent = root._displayEvent(event)
        root._syncOverlayExtensionReservation()

        if (root._overlaySessionActive || IslandOverlayService.mode !== "none")
            return

        root._triggerSharedBackgroundPulse("replace")
    }

    function _startAttachedReveal(fromWidth, fromHeight, withThrowKick) {
        if (!root._attachedPanelActive)
            return

        const shouldThrowKick = withThrowKick !== false
        const preservingThrowMotion = !shouldThrowKick && _pillThrowOutAnim.running
        const preserveVisibleContent = !shouldThrowKick
            && (root._attachedContentOpacity > 0 || _attachedRevealAnim.running)
        const immediateRevealWithThrow = shouldThrowKick
            && (root._attachedContentOpacity > 0 || _attachedRevealAnim.running)
        const handoffReveal = root._overlaySessionActive
            && (preserveVisibleContent || immediateRevealWithThrow)
        const resolvedFromWidth = fromWidth !== undefined
            ? fromWidth
            : root._attachedRevealSeedWidth
        const resolvedFromHeight = fromHeight !== undefined
            ? fromHeight
            : root._attachedRevealSeedHeight

        _attachedCollapseAnim.stop()
        root._attachedPanelRevealWidth = Math.min(
            Math.max(root._attachedRevealSeedWidth, resolvedFromWidth),
            root._attachedPanelWidth
        )
        root._attachedPanelRevealHeight = Math.min(
            Math.max(0, resolvedFromHeight),
            root._attachedPanelHeight
        )
        root._attachedRevealUseHandoffCurve = handoffReveal
        _pillCatchAnim.stop()

        if (!shouldThrowKick) {
            _attachedRevealAnim.stop()
            if (!preserveVisibleContent)
                root._attachedContentOpacity = 0
            _attachedRevealDelayTimer.stop()
            if (!preservingThrowMotion) {
                _pillThrowOutAnim.stop()
                root._pillThrowOffsetY = 0
            }
            _attachedRevealAnim.start()
            return
        }

        _attachedRevealAnim.stop()
        _attachedRevealDelayTimer.stop()
        _pillThrowOutAnim.stop()
        root._pillThrowOffsetY = 0
        if (!immediateRevealWithThrow)
            root._attachedContentOpacity = 0
        _pillThrowOutAnim.start()
        _attachedRevealAnim.start()
    }

    function _startAttachedCollapse(toWidth, toHeight) {
        if (!root._attachedPanelActive)
            return

        root._overlayHintHandoffActive = false
        root._overlayHandoffHintEvent = root._idleSnapshot()
        _attachedRevealDelayTimer.stop()
        _attachedRevealAnim.stop()
        _attachedCollapseAnim.stop()
        _pillThrowOutAnim.stop()
        _pillCatchAnim.stop()
        root._pillThrowOffsetY = 0

        root._attachedPanelRevealWidth = Math.min(
            Math.max(root._attachedRevealSeedWidth, root._attachedPanelVisibleWidth),
            root._attachedPanelWidth
        )
        root._attachedPanelRevealHeight = Math.min(
            Math.max(0, root._attachedPanelVisibleHeight),
            root._attachedPanelHeight
        )

        _attachedCollapseAnim.targetWidth = toWidth !== undefined
            ? toWidth
            : root._attachedRevealSeedWidth
        _attachedCollapseAnim.targetHeight = toHeight !== undefined
            ? toHeight
            : root._attachedRevealSeedHeight
        _pillCatchAnim.start()
        _attachedCollapseAnim.start()
    }

    function _cancelSharedBackgroundPulse() {
        root._logPulse("cancelSharedBackgroundPulse")
        _sharedBackgroundPulseAnim.stop()
        _pulseScaleAnim.stop()
        root._sharedBackgroundPulseOpacity = 0
        root._pulseScale = 1
        root._pulseOwner = ""
    }

    function _triggerSharedBackgroundPulse(owner) {
        const resolvedOwner = owner || "general"
        root._logPulse("triggerSharedBackgroundPulse owner=" + resolvedOwner)
        root._cancelSharedBackgroundPulse()
        root._pulseOwner = resolvedOwner
        _sharedBackgroundPulseAnim.start()
        _pulseScaleAnim.start()
    }

    function _maybeTriggerOverlayOpenPulse() {
        if (!root._overlayPulsePending)
            return

        root._overlayPulsePending = false

        root._logPulse("maybeTriggerOverlayOpenPulse")

        _hintFlashDelayTimer.stop()

        if (_sharedBackgroundPulseAnim.running || _pulseScaleAnim.running) {
            root._pulseOwner = "overlay"
            return
        }

        root._triggerSharedBackgroundPulse("overlay")
    }

    function _handoffFullHintToOverlay() {
        if (!root._hintPhase || !root._isFullHintEventType(root._flashSourceEvent.type))
            return

        _hintFlashDelayTimer.stop()
        _hintEnterAnim.stop()
        _hintExitAnim.stop()

        root._phase = "idle"
        root._flashSourceEvent = root._idleSnapshot()
        root._flashTrackY = root._flashStripY
        root._flashTrackScale = root._flashScale
        root._flashTrackOpacity = 0
        root._mainDisplayEvent = root._baselineEvent
        root._mainTrackY = root._mainTrackCenterY
        root._mainTrackScale = 1
        root._mainTrackOpacity = 1
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
        root._triggerSharedBackgroundPulse("hint-delay")
    }

    Timer {
        id: _hintFlashDelayTimer
        interval: Theme.anim.moveDuration
        repeat: false
        onTriggered: {
            root._logPulse("hintFlashDelayTimer")
            if (root._overlaySessionActive || IslandOverlayService.mode !== "none")
                return

            if (!root._hintPhase || !root._isFullHintEventType(root._flashSourceEvent.type))
                return

            root._triggerHintFlash()
        }
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
        if (root._isFullHintEventType(root._flashSourceEvent.type))
            root._startAttachedCollapse()
        if (!root._isFullHintEventType(root._flashSourceEvent.type))
            root._triggerEdgeReboundScale()
        _hintExitAnim.start()
    }

    function _completeWindowHintExit() {
        root._phase = "idle"
        root._flashSourceEvent = root._idleSnapshot()
        root._mainDisplayEvent = root._baselineEvent
        root._sharedBackgroundPulseOpacity = 0
        root._attachedPanelRevealWidth = 0
        root._attachedPanelRevealHeight = 0
        root._attachedContentOpacity = 0
        root._resetTracks()
        root._syncOverlayExtensionReservation()
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

            root._log(
                "activeEventChanged prev=" + previousEvent.type + " next=" + nextEvent.type
                    + " phase=" + root._phase
                    + " overlayMode=" + IslandOverlayService.mode
                    + " overlayState=" + IslandOverlayService.state
            )

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
            const previousAttachedWidth = root._attachedPanelVisibleWidth
            const previousAttachedHeight = root._attachedPanelVisibleHeight
            const wasDetachedHintActive = root._detachedHintActive
            const wasHintRevealSettled = root._hintRevealSettled

            root._syncOverlayFlags()

            root._syncOverlayExtensionReservation()

            root._logPulse("overlayStateChanged")

            if (IslandOverlayService.state === "opening") {
                if (wasDetachedHintActive) {
                    root._overlayHandoffHintEvent = root._cloneEvent(root._flashSourceEvent)
                    root._overlayHintHandoffActive = true
                } else {
                    root._overlayHintHandoffActive = false
                    root._overlayHandoffHintEvent = root._idleSnapshot()
                }

                root._handoffFullHintToOverlay()
                root._startAttachedReveal(
                    wasDetachedHintActive
                        ? Math.max(previousAttachedWidth, root._attachedRevealSeedWidth)
                        : undefined,
                    wasDetachedHintActive
                        ? Math.max(previousAttachedHeight, root._attachedRevealSeedHeight)
                        : undefined,
                    !wasDetachedHintActive || wasHintRevealSettled
                )
                root._maybeTriggerOverlayOpenPulse()
                _overlayCloseSettleTimer.stop()
                _overlayOpenSettleTimer.restart()
                return
            }

            if (IslandOverlayService.state === "closing") {
                root._startAttachedCollapse()
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
        anchors.topMargin: root._padV + root._pillThrowOffsetY
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
            opacity: (root._transientPhase || root._overlaySessionActive)
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

        visible: root._attachedPanelActive && !root._attachedCollapseTailHidden
        width: root._attachedPanelVisibleWidth
        height: root._overlayShellHeight
        y: root._overlayShellY
        z: -1
        opacity: root._attachedPanelOpacity
        scale: root._attachedSurfaceScale
        anchors.horizontalCenter: _pillClip.horizontalCenter
        transformOrigin: Item.Top

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
                fillColor: Qt.rgba(
                    Colors.surface.r * (1 - root._attachedPulseOpacity) + Colors.highlight.r * root._attachedPulseOpacity,
                    Colors.surface.g * (1 - root._attachedPulseOpacity) + Colors.highlight.g * root._attachedPulseOpacity,
                    Colors.surface.b * (1 - root._attachedPulseOpacity) + Colors.highlight.b * root._attachedPulseOpacity,
                    1
                )
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

        visible: root._attachedPanelActive && !root._attachedCollapseTailHidden
        enabled: root._attachedPanelActive && !root._attachedCollapseTailHidden
        width: root._attachedPanelVisibleWidth
        height: root._attachedPanelVisibleHeight
        y: root._overlayDetachedY - root._overlayAttachmentOverlap
            + (root._attachedPanelExpanded ? 0 : -root._overlayRevealLift)
            - root._attachedRevealYOffset
        opacity: root._attachedPanelOpacity
        scale: root._attachedSurfaceScale
        clip: true
        anchors.horizontalCenter: _pillClip.horizontalCenter
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
        }

        Item {
            anchors.fill: parent
            opacity: root._attachedContentOpacity

            Loader {
                id: _overlayHintCardLoader
                property var eventData: root._overlaySessionActive && root._overlayHintHandoffActive
                    ? root._overlayHandoffHintEvent
                    : root._flashSourceEvent

                active: root._attachedPanelActive
                    && (root._detachedHintActive || root._overlayHintHandoffActive)
                anchors.fill: parent
                anchors.margins: 1
                opacity: root._overlaySessionActive
                    ? (root._showOverlayHandoffHint ? 1 : 0)
                    : 1
                sourceComponent: _windowHintCardComponent

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim.highlightDuration
                        easing.type: Theme.anim.highlightType
                    }
                }
            }

            Loader {
                id: _overlayDeckLoader
                property var eventData: root._flashSourceEvent

                active: root._attachedPanelActive && root._overlaySessionActive
                anchors.fill: parent
                anchors.margins: 1
                opacity: root._overlaySessionActive
                    ? (root._showOverlayHandoffHint ? 0 : 1)
                    : 0
                sourceComponent: _overlayDeckComponent

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim.highlightDuration
                        easing.type: Theme.anim.highlightType
                    }
                }
            }
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

    Timer {
        id: _attachedRevealDelayTimer
        interval: root._pillThrowLeadDuration + root._pillThrowDropDuration
        repeat: false
        onTriggered: {
            if (root._attachedPanelActive)
                _attachedRevealAnim.start()
        }
    }

    SequentialAnimation {
        id: _pillThrowOutAnim

        NumberAnimation {
            target: root
            property: "_pillThrowOffsetY"
            to: -root._pillThrowLift
            duration: root._pillThrowLeadDuration
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root
            property: "_pillThrowOffsetY"
            to: root._pillThrowDrop
            duration: root._pillThrowDropDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_pillThrowOffsetY"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onStopped: root._pillThrowOffsetY = 0
        onFinished: root._pillThrowOffsetY = 0
    }

    SequentialAnimation {
        id: _pillCatchAnim

        NumberAnimation {
            target: root
            property: "_pillThrowOffsetY"
            to: -Math.max(3, Math.round(root._pillThrowLift * 1.05))
            duration: Math.max(1, Math.round(Theme.anim.highlightDuration * 0.55))
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root
            property: "_pillThrowOffsetY"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onStopped: root._pillThrowOffsetY = 0
        onFinished: root._pillThrowOffsetY = 0
    }

    ParallelAnimation {
        id: _attachedRevealAnim

        NumberAnimation {
            target: root
            property: "_attachedPanelRevealWidth"
            to: root._attachedPanelWidth
            duration: Theme.anim.moveDuration
            easing.type: root._attachedRevealUseHandoffCurve
                ? Theme.anim.moveType
                : Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_attachedPanelRevealHeight"
            to: root._attachedPanelHeight
            duration: Theme.anim.moveDuration
            easing.type: root._attachedRevealUseHandoffCurve
                ? Theme.anim.moveType
                : Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_attachedContentOpacity"
            to: 1
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        onFinished: {
            if (!root._attachedPanelActive)
                return

            root._attachedPanelRevealWidth = root._attachedPanelWidth
            root._attachedPanelRevealHeight = root._attachedPanelHeight
            root._attachedContentOpacity = 1
            root._attachedRevealUseHandoffCurve = false
            root._overlayHintHandoffActive = false
            root._overlayHandoffHintEvent = root._idleSnapshot()
        }
    }

    ParallelAnimation {
        id: _attachedCollapseAnim

        property real targetWidth: root._attachedRevealSeedWidth
        property real targetHeight: root._attachedRevealSeedHeight

        NumberAnimation {
            target: root
            property: "_attachedPanelRevealWidth"
            to: _attachedCollapseAnim.targetWidth
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_attachedPanelRevealHeight"
            to: _attachedCollapseAnim.targetHeight
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_attachedContentOpacity"
            to: root._overlaySessionActive ? 0 : 1
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        onFinished: {
            if (root._phase === "hint-exit" && !root._overlaySessionActive)
                root._completeWindowHintExit()
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
            if (root._isFullHintEventType(root._flashSourceEvent.type))
                return

            root._completeWindowHintExit()
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

        onFinished: {
            if (!_pulseScaleAnim.running)
                root._pulseOwner = ""
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

        onFinished: {
            if (!_sharedBackgroundPulseAnim.running)
                root._pulseOwner = ""
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
