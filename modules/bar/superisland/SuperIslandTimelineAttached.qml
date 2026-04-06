import QtQuick
import qs.config
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

    property alias pillThrowOutAnim: _pillThrowOutAnim
    property alias pillCatchAnim: _pillCatchAnim
    property alias attachedRevealAnim: _attachedRevealAnim
    property alias attachedCollapseAnim: _attachedCollapseAnim

    SequentialAnimation {
        id: _pillThrowOutAnim

        NumberAnimation {
            target: root.state
            property: "_pillThrowOffsetY"
            to: -root.host._pillThrowLift
            duration: root.host._pillThrowLeadDuration
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root.state
            property: "_pillThrowOffsetY"
            to: root.host._pillThrowDrop
            duration: root.host._pillThrowDropDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_pillThrowOffsetY"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onStopped: TimelineCallbacks.ensureThrowReset(root.state)
        onFinished: TimelineCallbacks.ensureThrowReset(root.state)
    }

    SequentialAnimation {
        id: _pillCatchAnim

        NumberAnimation {
            target: root.state
            property: "_pillThrowOffsetY"
            to: -Math.max(3, Math.round(root.host._pillThrowLift * 1.05))
            duration: Math.max(1, Math.round(Theme.anim.highlightDuration * 0.55))
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root.state
            property: "_pillThrowOffsetY"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onStopped: TimelineCallbacks.ensureThrowReset(root.state)
        onFinished: TimelineCallbacks.ensureThrowReset(root.state)
    }

    ParallelAnimation {
        id: _attachedRevealAnim

        NumberAnimation {
            target: root.state
            property: "_attachedPanelRevealWidth"
            to: root.host._attachedPanelWidth
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_attachedPanelRevealHeight"
            to: root.host._attachedPanelHeight
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_attachedContentOpacity"
            to: 1
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        onFinished: TimelineCallbacks.ensureAttachedRevealSettled(root.state, root.host)
    }

    ParallelAnimation {
        id: _attachedCollapseAnim

        property real targetWidth: root.host._attachedRevealSeedWidth
        property real targetHeight: root.host._attachedRevealSeedHeight

        NumberAnimation {
            target: root.state
            property: "_attachedPanelRevealWidth"
            to: _attachedCollapseAnim.targetWidth
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_attachedPanelRevealHeight"
            to: _attachedCollapseAnim.targetHeight
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_attachedContentOpacity"
            to: root.state._overlaySessionActive ? 0 : 1
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        onFinished: TimelineCallbacks.maybeCompleteHintExitAfterCollapse(root.state, root.completeWindowHintExit)
    }
}
