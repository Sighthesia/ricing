import QtQuick

// Provide a clamped numeric setting with consistent keyboard and pointer input.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string suffix: ""
    property bool enabled: true
    property bool rowEnabled: true
    property string accessibleName: ""
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property real displayValue: normalized(value)
    readonly property string displayText: Number(displayValue).toLocaleString(Qt.locale(), 'f', 0) + suffix
    readonly property bool focusVisible: activeFocus
    signal valueModified(real value)

    implicitWidth: 180
    implicitHeight: 36
    focus: true
    activeFocusOnTab: effectiveEnabled
    opacity: effectiveEnabled ? 1 : MotionTokens.disabledOpacity
    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName

    function normalized(candidate) {
        var start = Number(from)
        var end = Number(to)
        var low = Math.min(start, end)
        var high = Math.max(start, end)
        var step = Number(stepSize)
        if (!isFinite(step) || step <= 0)
            step = 1
        var number = Number(candidate)
        if (!isFinite(number))
            number = start
        var clamped = Math.max(low, Math.min(high, number))
        if (start === end)
            return start
        var direction = end >= start ? 1 : -1
        var steps = Math.round((clamped - start) / (step * direction))
        return Math.max(low, Math.min(high, start + steps * step * direction))
    }

    function setValue(candidate) {
        var next = normalized(candidate)
        if (next === displayValue)
            return
        valueModified(next)
    }

    function increase() { if (effectiveEnabled) setValue(displayValue + stepSize) }
    function decrease() { if (effectiveEnabled) setValue(displayValue - stepSize) }

    Keys.onPressed: event => {
        if (!root.effectiveEnabled)
            return
        if (event.key === Qt.Key_Left) {
            decrease()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            increase()
            event.accepted = true
        }
    }

    onEffectiveEnabledChanged: {
        if (!effectiveEnabled && activeFocus)
            focus = false
    }

    // Show the persistent track and thumb while animating only visual state.
    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: valueLabel.left
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: LazerTheme.settingsRowHover

        Rectangle {
            width: parent.width * root.normalizedFraction
            height: parent.height
            radius: 2
            color: LazerTheme.osuPink
            Behavior on width {
                id: fillBehavior
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast }
            }
        }
    }

    Text {
        id: valueLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        horizontalAlignment: Text.AlignRight
        text: root.displayText
        color: LazerTheme.textPrimary
        font.pixelSize: 13
    }

    readonly property real normalizedFraction: {
        var low = Math.min(Number(from), Number(to))
        var high = Math.max(Number(from), Number(to))
        if (high === low)
            return 0
        var fraction = (displayValue - low) / (high - low)
        return to < from ? 1 - fraction : fraction
    }

    HoverHandler { id: hoverHandler; enabled: root.effectiveEnabled }
    // Map pointer positions in the track, excluding the value label.
    TapHandler {
        id: trackTapHandler
        parent: track
        enabled: root.effectiveEnabled
        onTapped: point => {
            if (track.width <= 0 || root.from === root.to)
                return
            var fraction = Math.max(0, Math.min(1, point.position.x / track.width))
            if (root.to < root.from)
                fraction = 1 - fraction
            root.setValue(root.from + (root.to - root.from) * fraction)
        }
    }

    readonly property Item trackItem: track
    readonly property bool trackTapEnabled: trackTapHandler.enabled
    readonly property bool trackFillBehaviorEnabled: fillBehavior.enabled
}
