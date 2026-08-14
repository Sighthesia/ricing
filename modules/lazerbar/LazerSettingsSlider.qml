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
    readonly property bool trackFillBehaviorEnabled: !MotionTokens.reducedMotion
    readonly property real displayValue: normalized(value)
    readonly property string displayText: Number(displayValue).toLocaleString(Qt.locale(), 'f', 0) + suffix
    readonly property bool focusVisible: activeFocus
    signal valueModified(real value)

    implicitWidth: 180
    implicitHeight: 36
    focus: true
    activeFocusOnTab: true
    opacity: effectiveEnabled ? 1 : MotionTokens.disabledOpacity
    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName

    function normalized(candidate) {
        var low = Math.min(Number(from), Number(to))
        var high = Math.max(Number(from), Number(to))
        var step = Number(stepSize)
        if (!isFinite(step) || step <= 0)
            step = 1
        var number = Number(candidate)
        if (!isFinite(number))
            number = low
        var clamped = Math.max(low, Math.min(high, number))
        return Math.max(low, Math.min(high, low + Math.round((clamped - low) / step) * step))
    }

    function setValue(candidate) {
        var next = normalized(candidate)
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
    TapHandler {
        id: tapHandler
        enabled: root.effectiveEnabled
        onTapped: point => {
            if (root.width <= 0 || root.from === root.to)
                return
            var fraction = Math.max(0, Math.min(1, point.position.x / root.width))
            if (root.to < root.from)
                fraction = 1 - fraction
            root.setValue(root.from + (root.to - root.from) * fraction)
        }
    }
}
