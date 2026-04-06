import QtQuick
import qs.config
import "./SuperIslandStateMachineTimelineCallbacks.js" as TimelineCallbacks

// Shared background and scale pulse timeline segments.
Item {
    id: root

    required property QtObject state

    visible: false
    width: 0
    height: 0

    property alias sharedBackgroundPulseAnim: _sharedBackgroundPulseAnim
    property alias pulseScaleAnim: _pulseScaleAnim

    SequentialAnimation {
        id: _sharedBackgroundPulseAnim

        NumberAnimation {
            target: root.state
            property: "_sharedBackgroundPulseOpacity"
            from: 0
            to: 0.16
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }

        NumberAnimation {
            target: root.state
            property: "_sharedBackgroundPulseOpacity"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: TimelineCallbacks.clearPulseOwnerWhenIdle(root.state, _pulseScaleAnim.running, _sharedBackgroundPulseAnim.running)
    }

    SequentialAnimation {
        id: _pulseScaleAnim

        NumberAnimation {
            target: root.state
            property: "_pulseScale"
            from: 1
            to: 1.018
            duration: Theme.anim.pulseSpringDuration
            easing.type: Theme.anim.pulseSpringType
            easing.overshoot: Theme.anim.pulseSpringOvershoot
        }

        NumberAnimation {
            target: root.state
            property: "_pulseScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: TimelineCallbacks.clearPulseOwnerWhenIdle(root.state, _pulseScaleAnim.running, _sharedBackgroundPulseAnim.running)
    }
}
