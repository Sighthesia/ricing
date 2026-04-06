import QtQuick

// Mutable SuperIsland runtime state shared by host bindings and state-machine policies.
QtObject {
    id: root

    function _idleEvent() {
        return {
            id: "idle",
            type: "idle",
            groupKey: "idle",
            priority: "passive",
            relayReplace: false,
            sticky: false,
            title: "",
            subtitle: "",
            icon: "",
            workspaceLabel: "",
            timeoutMs: 0,
            revision: 0,
            timestamp: 0
        }
    }

    property date currentTime: new Date()

    property QtObject flow: QtObject {
        id: flow

        property string phase: "idle"
        property var mainDisplayEvent: root._idleEvent()
        property var flashSourceEvent: root._idleEvent()
        property var lastActiveEvent: root._idleEvent()
    }

    property QtObject tracks: QtObject {
        id: tracks

        property real mainY: 0
        property real mainScale: 1
        property real mainOpacity: 1
        property real flashY: 0
        property real flashScale: 0.85
        property real flashOpacity: 0
    }

    property QtObject replace: QtObject {
        id: replace

        property var outgoingEvent: root._idleEvent()
        property var incomingEvent: root._idleEvent()
        property real outgoingY: 0
        property real outgoingOpacity: 0
        property real outgoingTargetY: 0
        property real incomingY: 0
        property real incomingOpacity: 0
        property bool outgoingVisible: false
        property bool incomingVisible: false
    }

    property QtObject pulse: QtObject {
        id: pulse

        property real backgroundOpacity: 0
        property real scale: 1
        property bool overlayPending: false
        property string owner: ""
    }

    property QtObject overlay: QtObject {
        id: overlay

        property bool sessionActive: false
        property bool expandedActive: false
        property var handoffHintEvent: root._idleEvent()
        property bool hintHandoffActive: false
    }

    property QtObject attached: QtObject {
        id: attached

        property real panelRevealWidth: 0
        property real panelRevealHeight: 0
        property real contentOpacity: 0
        property real pillThrowOffsetY: 0
        property bool revealUseHandoffCurve: false
    }

    // Canonical aliases.
    property alias phase: flow.phase
    property alias mainDisplayEvent: flow.mainDisplayEvent
    property alias flashSourceEvent: flow.flashSourceEvent
    property alias lastActiveEvent: flow.lastActiveEvent

    property alias mainTrackY: tracks.mainY
    property alias mainTrackScale: tracks.mainScale
    property alias mainTrackOpacity: tracks.mainOpacity
    property alias flashTrackY: tracks.flashY
    property alias flashTrackScale: tracks.flashScale
    property alias flashTrackOpacity: tracks.flashOpacity

    property alias replaceOutgoingEvent: replace.outgoingEvent
    property alias replaceIncomingEvent: replace.incomingEvent
    property alias replaceOutgoingY: replace.outgoingY
    property alias replaceOutgoingOpacity: replace.outgoingOpacity
    property alias replaceOutgoingTargetY: replace.outgoingTargetY
    property alias replaceIncomingY: replace.incomingY
    property alias replaceIncomingOpacity: replace.incomingOpacity
    property alias replaceOutgoingVisible: replace.outgoingVisible
    property alias replaceIncomingVisible: replace.incomingVisible

    property alias sharedBackgroundPulseOpacity: pulse.backgroundOpacity
    property alias pulseScale: pulse.scale
    property alias overlayPulsePending: pulse.overlayPending
    property alias pulseOwner: pulse.owner

    property alias overlaySessionActive: overlay.sessionActive
    property alias overlayExpandedActive: overlay.expandedActive
    property alias overlayHandoffHintEvent: overlay.handoffHintEvent
    property alias overlayHintHandoffActive: overlay.hintHandoffActive

    property alias attachedPanelRevealWidth: attached.panelRevealWidth
    property alias attachedPanelRevealHeight: attached.panelRevealHeight
    property alias attachedContentOpacity: attached.contentOpacity
    property alias pillThrowOffsetY: attached.pillThrowOffsetY
    property alias attachedRevealUseHandoffCurve: attached.revealUseHandoffCurve

    // Backward-compatibility aliases for existing `_` state references.
    property alias _phase: flow.phase
    property alias _mainDisplayEvent: flow.mainDisplayEvent
    property alias _flashSourceEvent: flow.flashSourceEvent
    property alias _lastActiveEvent: flow.lastActiveEvent

    property alias _mainTrackY: tracks.mainY
    property alias _mainTrackScale: tracks.mainScale
    property alias _mainTrackOpacity: tracks.mainOpacity
    property alias _flashTrackY: tracks.flashY
    property alias _flashTrackScale: tracks.flashScale
    property alias _flashTrackOpacity: tracks.flashOpacity

    property alias _replaceOutgoingEvent: replace.outgoingEvent
    property alias _replaceIncomingEvent: replace.incomingEvent
    property alias _replaceOutgoingY: replace.outgoingY
    property alias _replaceOutgoingOpacity: replace.outgoingOpacity
    property alias _replaceOutgoingTargetY: replace.outgoingTargetY
    property alias _replaceIncomingY: replace.incomingY
    property alias _replaceIncomingOpacity: replace.incomingOpacity
    property alias _replaceOutgoingVisible: replace.outgoingVisible
    property alias _replaceIncomingVisible: replace.incomingVisible

    property alias _sharedBackgroundPulseOpacity: pulse.backgroundOpacity
    property alias _pulseScale: pulse.scale
    property alias _overlayPulsePending: pulse.overlayPending
    property alias _pulseOwner: pulse.owner

    property alias _overlaySessionActive: overlay.sessionActive
    property alias _overlayExpandedActive: overlay.expandedActive
    property alias _overlayHandoffHintEvent: overlay.handoffHintEvent
    property alias _overlayHintHandoffActive: overlay.hintHandoffActive

    property alias _attachedPanelRevealWidth: attached.panelRevealWidth
    property alias _attachedPanelRevealHeight: attached.panelRevealHeight
    property alias _attachedContentOpacity: attached.contentOpacity
    property alias _pillThrowOffsetY: attached.pillThrowOffsetY
    property alias _attachedRevealUseHandoffCurve: attached.revealUseHandoffCurve
}
