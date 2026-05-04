import QtQuick
import qs.config
import ".." as BarParts
import "./SuperIslandStateMachineTimelineCallbacks.js" as TimelineCallbacks

// Attached-panel and pill throw/catch timeline segments.
Item {
    id: root

    required property Item host
    required property QtObject state
    required property var completeWindowHintExit

    visible: false
    width: 0
    height: 0

    property alias pillThrowOutAnim: _motion.throwOutAnim
    property alias pillCatchAnim: _motion.catchAnim
    property alias attachedRevealAnim: _motion.revealAnim
    property alias attachedCollapseAnim: _collapseController

    BarParts.AttachedExpansionMotion {
        id: _motion

        motionTarget: root.state
        throwOffsetProperty: "_pillThrowOffsetY"
        revealWidthProperty: "_attachedPanelRevealWidth"
        revealHeightProperty: "_attachedPanelRevealHeight"
        contentOpacityProperty: "_attachedContentOpacity"
        useSurfaceOpacity: false
        useSurfaceScale: false
        throwLift: root.host._pillThrowLift
        throwDrop: root.host._pillThrowDrop
        throwCatchLift: Math.max(3, Math.round(root.host._pillThrowLift * 1.05))
        revealWidthTarget: root.host._attachedPanelWidth
        revealHeightTarget: root.host._attachedPanelHeight
        collapseWidthTarget: root.host._attachedRevealSeedWidth
        collapseHeightTarget: root.host._attachedRevealSeedHeight
        revealContentOpacityTarget: 1
        collapseContentOpacityTarget: root.state._overlaySessionActive ? 0 : 1
        throwLeadDuration: root.host._pillThrowLeadDuration
        throwDropDuration: root.host._pillThrowDropDuration

        onThrowOutFinished: TimelineCallbacks.ensureThrowReset(root.state)
        onThrowOutStopped: TimelineCallbacks.ensureThrowReset(root.state)
        onCatchFinished: TimelineCallbacks.ensureThrowReset(root.state)
        onCatchStopped: TimelineCallbacks.ensureThrowReset(root.state)
        onRevealFinished: TimelineCallbacks.ensureAttachedRevealSettled(root.state, root.host)
        onCollapseFinished: {
            TimelineCallbacks.maybeCompleteHintExitAfterCollapse(root.state, root.host, root.completeWindowHintExit)
        }
    }

    QtObject {
        id: _collapseController

        property real targetWidth: NaN
        property real targetHeight: NaN
        readonly property bool running: _motion.collapseAnim.running

        function start() {
            if (root.host._debugLogging)
                TimelineCallbacks.debugWindowHintReturnLog(root.host, root.state, "attachedCollapse:start")
            _motion.targetWidth = targetWidth
            _motion.targetHeight = targetHeight
            _motion.collapseAnim.start()
        }

        function stop() {
            if (root.host._debugLogging)
                TimelineCallbacks.debugWindowHintReturnLog(root.host, root.state, "attachedCollapse:stop")
            _motion.collapseAnim.stop()
        }
    }
}
