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

    property string _phase: "idle"
    property var _mainDisplayEvent: _idleEvent()
    property var _flashSourceEvent: _idleEvent()
    property var _replaceOutgoingEvent: _idleEvent()
    property var _replaceIncomingEvent: _idleEvent()
    property var _lastActiveEvent: _idleEvent()

    property real _mainTrackY: 0
    property real _mainTrackScale: 1
    property real _mainTrackOpacity: 1
    property real _flashTrackY: 0
    property real _flashTrackScale: 0.85
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
    property bool _overlayPulsePending: false
    property string _pulseOwner: ""

    property bool _overlaySessionActive: false
    property bool _overlayExpandedActive: false

    property real _attachedPanelRevealWidth: 0
    property real _attachedPanelRevealHeight: 0
    property real _attachedContentOpacity: 0
    property real _pillThrowOffsetY: 0
    property bool _attachedRevealUseHandoffCurve: false

    property var _overlayHandoffHintEvent: _idleEvent()
    property bool _overlayHintHandoffActive: false
}
