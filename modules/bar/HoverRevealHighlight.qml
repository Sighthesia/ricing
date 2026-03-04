import QtQuick
import qs.config

// Wipe-reveal background for hover highlights.
// Enter: background expands left→right (width 0 → full).
// Exit:  background sweeps away left→right (x: 0 → full, then hidden).
//
// Usage:
//   HoverRevealHighlight {
//     anchors.fill: parent
//     hovered: someMouseArea.containsMouse
//     highlightColor: Colors.surface
//     highlightOpacity: 0.5
//     radius: Theme.cornerRadius - 4
//   }
Item {
    id: root

    property bool hovered: false
    property color highlightColor: Colors.highlight
    property real highlightOpacity: 0.12
    property real radius: 0
    // Enter uses moveDuration (slower, deliberate reveal);
    // exit uses highlightDuration (quick sweep-out). Can be overridden per-instance.
    property int enterDuration: Theme.anim.moveDuration
    property int exitDuration: Theme.anim.highlightDuration

    // Clip prevents the bar from overflowing the item bounds during animation.
    clip: true

    Rectangle {
        id: bar
        height: parent.height
        x: 0
        width: 0
        radius: root.radius
        color: root.highlightColor
        opacity: root.highlightOpacity
    }

    onHoveredChanged: {
        if (hovered) {
            // Cancel any ongoing exit, reset to left edge, then reveal.
            exitAnim.stop()
            bar.x = 0
            bar.width = 0
            enterAnim.restart()
        } else {
            // Cancel enter at current width, snap to full-width, then wipe away.
            enterAnim.stop()
            bar.x = 0
            bar.width = root.width
            exitAnim.restart()
        }
    }

    // Expand left→right by growing width.
    NumberAnimation {
        id: enterAnim
        target: bar
        property: "width"
        from: 0
        to: root.width
        duration: root.enterDuration
        easing.type: Easing.OutCubic
    }

    // Sweep away left→right by advancing x until the bar leaves the clip region.
    NumberAnimation {
        id: exitAnim
        target: bar
        property: "x"
        from: 0
        to: root.width
        duration: root.exitDuration
        easing.type: Easing.InCubic
        onFinished: {
            // Reset to idle state for the next enter cycle.
            bar.x = 0
            bar.width = 0
        }
    }
}
