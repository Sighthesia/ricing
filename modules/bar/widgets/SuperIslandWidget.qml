import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../superisland" as IslandCards

// Dynamic Island-style bar widget for idle time, transient events, and hint playback.
Item {
    id: root

    property bool liveInstance: false
    property string debugInstanceLabel: liveInstance ? "live" : "preview"

    readonly property bool _debugLogging: false

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
    readonly property bool _listensToService: liveInstance
    readonly property var _baselineEvent: root._displayEvent(root._listensToService ? SuperIslandService.mainState : root._idleSnapshot())
    readonly property var _currentEvent: root._mainDisplayEvent
    readonly property bool _showEvent: root._currentEvent.type !== "idle"
    readonly property int _mainContentWidth: _mainLoader.item ? _mainLoader.item.implicitWidth : 0
    readonly property int _stripContentWidth: _stripLoader.item ? _stripLoader.item.implicitWidth : 0
    readonly property int _idleOpticalOffset: Math.max(1, Math.round(Theme.uiScale))
    readonly property int _collapsedWidth: root._mainContentWidth + root._padH * 2
    readonly property int _expandedWidth:
        Math.max(root._mainContentWidth, root._stripContentWidth) + root._padH * 2
    readonly property int _returnWidth: root._stripContentWidth + root._padH * 2
    readonly property real _mainTrackCenterY:
        root._trackCenterY(_mainLoader.item, root._pillH, root._mainDisplayEvent, true)
    readonly property real _mainTrackEnterY:
        -Math.max(root._pillH, _mainLoader.item ? _mainLoader.item.implicitHeight : root._pillH)
    readonly property real _flashTrackCenterY:
        root._trackCenterY(_stripLoader.item, root._pillH, root._flashSourceEvent, false)
    readonly property real _returnTrackCenterY:
        root._trackCenterY(_stripLoader.item, root._pillH, root._flashSourceEvent, false)
    readonly property real _flashStripY:
        root._pillH + root._flashGap + root._trackCenterY(_stripLoader.item, root._flashRowH, root._flashSourceEvent, false)
    readonly property real _hintDividerY:
        root._pillH + Math.max(0, (root._flashGap - 1) / 2) - root._hintLift
    readonly property real _hintTrackY: root._flashStripY - root._hintLift
    readonly property bool _transientPhase:
        root._phase === "enter" || root._phase === "hold" || root._phase === "exit"
    readonly property bool _hintPhase:
        root._phase === "hint" || root._phase === "hint-exit"
    readonly property real _transientAccentBaseOpacity: Colors.highlightAlpha * 0.4
    readonly property real _hintBackgroundY:
        root._hintPhase && _stripLoader.item
            ? (root._hintTrackY - root._hintPulsePad)
            : (root._pillH + root._flashGap)
    readonly property real _hintBackgroundHeight:
        root._hintPhase && _stripLoader.item
            ? Math.min(root._flashRowH, _stripLoader.item.implicitHeight + root._hintPulsePad * 2)
            : root._flashRowH
    readonly property int pillTopPadding: root._padV
    readonly property real hintFlashOpacity: root._sharedBackgroundPulseOpacity
    readonly property real sharedBackgroundPulseOpacity: root._sharedBackgroundPulseOpacity
    readonly property real hintContentGapTop:
        root._hintTrackY - (root._hintDividerY + 1)
    readonly property real hintContentGapBottom:
        (root._pillH + root._flashGap + root._flashRowH)
        - (root._hintTrackY + (_stripLoader.item ? _stripLoader.item.implicitHeight : root._flashRowH))
    readonly property real hintBackgroundGapTop:
        root._hintBackgroundY - (root._hintDividerY + 1)
    readonly property real hintBackgroundGapBottom:
        (root._pillH + root._flashGap + root._flashRowH)
        - (root._hintBackgroundY + root._hintBackgroundHeight)
    readonly property real hintRestingBackgroundOpacity:
        root._hintPhase ? root._sharedBackgroundPulseOpacity : 0

    readonly property string transitionMode:
        root._phase === "exit" ? "exit-track"
        : ((root._phase === "hint" || root._phase === "hint-exit") ? "hint-track"
        : ((root._phase === "enter" || root._phase === "hold") ? "dual-track" : "single-track"))
    readonly property bool mainTrackVisible: true
    readonly property bool flashTrackVisible:
        root._phase !== "idle" && (root._flashSourceEvent.id || "") !== ""

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
            : (root.flashTrackVisible ? root._expandedWidth : root._collapsedWidth))

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    Binding {
        target: BarLayoutService
        property: "superIslandFlashExtension"
        value: root._listensToService && root._phase !== "idle"
            ? (root._flashGap + root._flashRowH)
            : 0
        restoreMode: Binding.RestoreBindingOrValue
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
            title: Qt.formatDateTime(systemClock.date, "hh:mm"),
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

    function _startEnterTransition(event) {
        const outgoing = root._hintPhase
            ? root._cloneEvent(root._flashSourceEvent)
            : root._cloneEvent(root._mainDisplayEvent.type !== "idle"
                ? root._mainDisplayEvent
                : root._baselineEvent)

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
        root._flashSourceEvent = outgoing
        root._phase = "enter"

        _returnAnim.stop()
        _departAnim.stop()
        _pillCollapseAnim.stop()
        _pillExpandAnim.stop()
        _pillExpandAnim.start()

        root._mainTrackY = root._mainTrackEnterY
        root._mainTrackScale = 0.92
        root._mainTrackOpacity = 0.15

        root._flashTrackY = root._flashTrackCenterY
        root._flashTrackScale = 1
        root._flashTrackOpacity = 1
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
        _hintExitAnim.stop()
        _pillCollapseAnim.stop()
        _pillExpandAnim.stop()
        _pillExpandAnim.start()

        root._flashTrackY = root._hintTrackY - Theme.barWidget.contentPaddingV * 2
        root._flashTrackScale = 0.96
        root._flashTrackOpacity = 0
        _hintFlashDelayTimer.restart()

        _hintEnterAnim.start()
    }

    function _updateWindowHint(event) {
        root._flashSourceEvent = root._displayEvent(event)
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
        root._flashSourceEvent = root._cloneEvent(root._baselineEvent)

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
        _pillExpandAnim.stop()
        _pillCollapseAnim.stop()
        _pillCollapseAnim.start()
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
        _pillExpandAnim.stop()
        _pillCollapseAnim.stop()
        _pillCollapseAnim.start()
        root._triggerEdgeReboundScale()

        root._mainTrackY = root._mainTrackCenterY
        root._mainTrackScale = 1
        root._mainTrackOpacity = 1
        root._flashTrackY = root._flashStripY
        root._flashTrackScale = root._flashScale
        root._flashTrackOpacity = 0.6

        _returnAnim.start()
    }

    Component.onCompleted: {
        const initialActiveEvent = root._displayEvent(root._listensToService ? SuperIslandService.activeEvent : root._idleSnapshot())
        root._mainDisplayEvent = initialActiveEvent.type !== "idle" ? initialActiveEvent : root._baselineEvent
        root._lastActiveEvent = initialActiveEvent
        root._resetTracks()
        Qt.callLater(() => { root._initialized = true })
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

            if (nextEvent.relayReplace && previousEvent.type !== "idle") {
                root._replaceActiveTransient(nextEvent)
            } else if (nextEvent.type === "window" && previousEvent.type === "idle") {
                root._startEnterTransition(nextEvent)
            } else if (nextEvent.type === "window" && previousEvent.type === "window") {
                root._replaceActiveTransient(nextEvent)
            } else if (nextEvent.type !== "idle" && previousEvent.type === "window") {
                root._replaceActiveTransient(nextEvent)
            } else if (nextEvent.type === "idle" && previousEvent.type === "window") {
                root._startExitTransition()
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

    Item {
        id: _pillClip
        anchors.top: parent.top
        anchors.topMargin: root._padV
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true
        implicitWidth: root.implicitWidth
        implicitHeight: root._phase !== "idle"
            ? (root._pillH + root._flashGap + root._flashRowH)
            : root._pillH
        width: implicitWidth
        height: implicitHeight
        scale: root._pulseScale
        transformOrigin: Item.Center

        Behavior on implicitWidth {
            enabled: root._initialized
            NumberAnimation {
                duration: Theme.anim.springDuration
                easing.type: Theme.anim.springType
                easing.overshoot: Theme.anim.springOvershoot
            }
        }

        Rectangle {
            id: _pillBg
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root._pillH
            radius: root._pillH / 2
            color: Colors.surface
            border.color: Colors.border
            border.width: 1

            NumberAnimation {
                id: _pillExpandAnim
                target: _pillBg
                property: "height"
                to: root._pillH + root._flashGap + root._flashRowH
                duration: Theme.anim.springDuration
                easing.type: Theme.anim.springType
                easing.overshoot: Theme.anim.springOvershoot
            }

            NumberAnimation {
                id: _pillCollapseAnim
                target: _pillBg
                property: "height"
                to: root._pillH
                duration: Theme.anim.springDuration
                easing.type: Theme.anim.springType
                easing.overshoot: Theme.anim.springOvershoot
            }

            Behavior on width {
                enabled: root._initialized
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
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
            opacity: root._phase !== "idle" ? 0.35 : 0

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
            opacity: root._hintPhase ? root._sharedBackgroundPulseOpacity : 0
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
            sourceComponent: root._componentForEvent(eventData, true)
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
            const handoffY = root._flashTrackY
            const handoffScale = root._flashTrackScale
            const handoffOpacity = root._flashTrackOpacity

            root._mainDisplayEvent = returningEvent.type !== "idle" ? returningEvent : root._baselineEvent
            root._mainTrackY = handoffY
            root._mainTrackScale = handoffScale
            root._mainTrackOpacity = handoffOpacity
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
            property: "_flashTrackY"
            to: root._hintTrackY
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
            to: 0.82
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    ParallelAnimation {
        id: _hintExitAnim

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
                    text: Qt.formatDateTime(systemClock.date, "hh:mm")
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

        IslandCards.IslandNotificationCard {
            event: eventData
            iconSource: resolvedIcon
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

        IslandCards.IslandNotificationCard {
            event: eventData
            iconSource: resolvedIcon
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
}
