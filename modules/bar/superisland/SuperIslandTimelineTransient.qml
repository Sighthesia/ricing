import QtQuick
import qs.config
import "./SuperIslandStateMachineTimelineCallbacks.js" as TimelineCallbacks

// Main transient enter/replace/return timeline segments.
Item {
    id: root

    required property Item host
    required property QtObject state
    required property var resetReplaceLayers
    required property var completeWindowHintExit

    visible: false
    width: 0
    height: 0

    property alias replaceAnim: _replaceAnim
    property alias departAnim: _departAnim
    property alias returnAnim: _returnAnim
    property alias hintEnterAnim: _hintEnterAnim
    property alias hintExitAnim: _hintExitAnim

    ParallelAnimation {
        id: _replaceAnim

        SequentialAnimation {
            PauseAnimation {
                duration: root.host._replaceDelay
            }

            ParallelAnimation {
                NumberAnimation {
                    target: root.state
                    property: "_replaceIncomingY"
                    to: root.host._mainTrackCenterY
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }

                NumberAnimation {
                    target: root.state
                    property: "_replaceIncomingOpacity"
                    to: 1
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
        }

        NumberAnimation {
            target: root.state
            property: "_replaceOutgoingY"
            to: root.state._replaceOutgoingTargetY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_replaceOutgoingOpacity"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: TimelineCallbacks.finishReplace(root.state, root.host, root.resetReplaceLayers)
    }

    ParallelAnimation {
        id: _departAnim

        NumberAnimation {
            target: root.state
            property: "_mainTrackY"
            to: root.host._mainTrackCenterY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackOpacity"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackY"
            to: root.host._flashStripY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackScale"
            to: root.host._flashScale
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackOpacity"
            to: 0.6
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: TimelineCallbacks.maybeEnterHold(root.state)
    }

    ParallelAnimation {
        id: _returnAnim

        NumberAnimation {
            target: root.state
            property: "_mainTrackY"
            to: root.host._mainTrackEnterY
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackScale"
            to: 0.92
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackOpacity"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackY"
            to: root.host._returnTrackCenterY
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackScale"
            to: 1
            duration: Theme.anim.springDuration
            easing.type: Theme.anim.springType
            easing.overshoot: Theme.anim.springOvershoot
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackOpacity"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: TimelineCallbacks.finishReturn(root.state, root.host)
    }

    ParallelAnimation {
        id: _hintEnterAnim

        NumberAnimation {
            target: root.state
            property: "_mainTrackY"
            to: root.host._isFullHintEventType(root.state._attachedHintEvent.type)
                ? root.host._mainTrackCenterY
                : root.host._windowHintEntryMeta.mainRole.targetY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackScale"
            to: root.host._isFullHintEventType(root.state._attachedHintEvent.type) ? 1 : root.host._flashScale
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_mainTrackOpacity"
            to: root.host._isFullHintEventType(root.state._attachedHintEvent.type) ? 1 : 0.6
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackY"
            to: root.host._windowHintEntryMeta.flashRole.targetY
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackOpacity"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    ParallelAnimation {
        id: _hintExitAnim

        NumberAnimation {
            target: root.state
            property: "_mainTrackY"
            to: root.host._mainTrackCenterY
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackY"
            to: root.host._hintTrackY - Theme.barWidget.contentPaddingV * 3
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackScale"
            to: 0.96
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root.state
            property: "_flashTrackOpacity"
            to: 0
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: TimelineCallbacks.maybeCompleteHintExit(root.state, root.host, root.completeWindowHintExit)
    }
}
