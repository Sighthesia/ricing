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
    property string accessibleName: ""
    readonly property string displayText: Number(value).toLocaleString(Qt.locale(), 'f', 0) + suffix
    readonly property bool focusVisible: activeFocus
    readonly property real effectiveScale: MotionTokens.reducedMotion ? 1 : (hoverHandler.hovered ? MotionTokens.hoverScale : 1)
    signal valueModified(real value)

    implicitWidth: 180
    implicitHeight: 36
    focus: true
    activeFocusOnTab: true
    opacity: enabled ? 1 : MotionTokens.disabledOpacity
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
        if (next === value)
            return
        value = next
        valueModified(next)
    }

    function increase() { if (enabled) setValue(value + stepSize) }
    function decrease() { if (enabled) setValue(value - stepSize) }

    onValueChanged: {
        var next = normalized(value)
        if (next !== value) {
            value = next
            return
        }
    }

    Keys.onPressed: event => {
        if (!root.enabled)
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
            width: parent.width * ((root.value - root.from) / Math.max(1, root.to - root.from))
            height: parent.height
            radius: 2
            color: LazerTheme.osuPink
            Behavior on width { NumberAnimation { duration: MotionTokens.fast } }
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

    HoverHandler { id: hoverHandler; enabled: root.enabled }
    TapHandler {
        id: tapHandler
        enabled: root.enabled
        onTapped: point => root.setValue(root.from + (root.to - root.from) * point.position.x / root.width)
    }
}
