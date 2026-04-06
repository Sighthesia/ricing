import QtQuick
import qs.config
import "." as IslandParts

// Reusable animation timeline for SuperIsland state-machine transitions.
Item {
    id: root

    required property Item host
    required property QtObject state
    required property var resetReplaceLayers
    required property var completeWindowHintExit

    visible: false
    width: 0
    height: 0

    property alias pillThrowOutAnim: _attachedTimeline.pillThrowOutAnim
    property alias pillCatchAnim: _attachedTimeline.pillCatchAnim
    property alias attachedRevealAnim: _attachedTimeline.attachedRevealAnim
    property alias attachedCollapseAnim: _attachedTimeline.attachedCollapseAnim
    property alias replaceAnim: _transientTimeline.replaceAnim
    property alias departAnim: _transientTimeline.departAnim
    property alias returnAnim: _transientTimeline.returnAnim
    property alias hintEnterAnim: _transientTimeline.hintEnterAnim
    property alias hintExitAnim: _transientTimeline.hintExitAnim
    property alias sharedBackgroundPulseAnim: _pulseTimeline.sharedBackgroundPulseAnim
    property alias pulseScaleAnim: _pulseTimeline.pulseScaleAnim

    IslandParts.SuperIslandTimelineAttached {
        id: _attachedTimeline

        host: root.host
        state: root.state
        completeWindowHintExit: root.completeWindowHintExit
    }

    IslandParts.SuperIslandTimelineTransient {
        id: _transientTimeline

        host: root.host
        state: root.state
        resetReplaceLayers: root.resetReplaceLayers
        completeWindowHintExit: root.completeWindowHintExit
    }

    IslandParts.SuperIslandTimelinePulse {
        id: _pulseTimeline

        state: root.state
    }
}
