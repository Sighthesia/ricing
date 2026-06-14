pragma Singleton
import QtQuick

// Global ripple timeline shared by all shell surfaces.
QtObject {
    id: root

    property int token: 0
    property bool active: false
    property real progress: 1
    readonly property int duration: 1800
    readonly property real minDiameter: 16

    function trigger() {
        ++token
        progressAnimation.stop()
        progress = 0
        active = true
        progressAnimation.start()
    }

    function diameter(maxDiameter) {
        return minDiameter + Math.max(0, maxDiameter - minDiameter) * progress
    }

    function trailDiameter(maxDiameter) {
        var trailProgress = Math.max(0, progress - 0.02)
        return minDiameter + Math.max(0, maxDiameter - minDiameter) * trailProgress
    }

    function ringOpacity() {
        return active ? 0.95 * Math.max(0, 1 - progress) : 0
    }

    function glowOpacity() {
        return active ? 0.34 * Math.max(0, 1 - progress / 0.8) : 0
    }

    function trailOpacity() {
        return active ? 0.72 * Math.max(0, 1 - progress) : 0
    }

    property NumberAnimation progressAnimation: NumberAnimation {
        id: progressAnimation

        target: root
        property: "progress"
        from: 0
        to: 1
        duration: root.duration
        easing.type: Easing.OutCubic
        onStopped: root.active = false
    }
}
