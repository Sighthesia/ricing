import QtQuick

// Owns pulse and rebound helpers shared across SuperIsland strategies.
Item {
    id: root

    required property Item host
    required property QtObject state
    required property Item machine
    required property Item timeline

    visible: false
    width: 0
    height: 0

    function cancelSharedBackgroundPulse() {
        root.machine.logPulse("cancelSharedBackgroundPulse")
        root.timeline.sharedBackgroundPulseAnim.stop()
        root.timeline.pulseScaleAnim.stop()
        root.state._sharedBackgroundPulseOpacity = 0
        root.state._pulseScale = 1
        root.state._pulseOwner = ""
    }

    function triggerSharedBackgroundPulse(owner) {
        const resolvedOwner = owner || "general"
        root.machine.logPulse("triggerSharedBackgroundPulse owner=" + resolvedOwner)
        cancelSharedBackgroundPulse()
        root.state._pulseOwner = resolvedOwner
        root.timeline.sharedBackgroundPulseAnim.start()
        root.timeline.pulseScaleAnim.start()
    }

    function triggerEdgeReboundScale() {
        root.timeline.pulseScaleAnim.stop()
        root.state._pulseScale = 1
        root.timeline.pulseScaleAnim.start()
    }
}
