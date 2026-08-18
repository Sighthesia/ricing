import QtQuick

// Expose a keyboard and pointer friendly 44x20 settings capsule.
Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property bool rowEnabled: true
    property real availableWidth: Infinity
    property real requestedWidth: implicitWidth
    property string accessibleName: ""
    property bool fillWidth: false
    readonly property string rowPresentation: "inline"
    signal toggled(bool checked)

    readonly property bool pressed: tapHandler.pressed
    readonly property bool focusVisible: activeFocus
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property real effectiveAvailableWidth: isFinite(Number(availableWidth)) ? Math.max(0, Number(availableWidth)) : Infinity
    readonly property Item nubItem: capsule
    readonly property bool nubMorphEnabled: false

    implicitWidth: 44
    implicitHeight: 20
    width: Math.min(Math.max(0, isFinite(Number(requestedWidth)) ? Number(requestedWidth) : implicitWidth), effectiveAvailableWidth)
    height: implicitHeight
    opacity: effectiveEnabled ? 1 : MotionTokens.disabledOpacity
    activeFocusOnTab: effectiveEnabled
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleName

    onEffectiveEnabledChanged: {
        if (!effectiveEnabled && activeFocus)
            focus = false
    }

    function activate() {
        if (!root.effectiveEnabled)
            return
        root.toggled(!root.checked)
    }

    Keys.onSpacePressed: event => { activate(); event.accepted = true }
    Keys.onReturnPressed: event => { activate(); event.accepted = true }

    // Paint the full capsule as the state indicator without a moving thumb.
    Rectangle {
        id: capsule
        anchors.fill: parent
        radius: 10
        color: root.checked ? LazerTheme.settingsAccent : LazerTheme.settingsToggleOff
        border.width: root.focusVisible ? 2 : 0
        border.color: LazerTheme.focusRing
        scale: root.pressed ? MotionTokens.pressScale : 1

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }
        Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
    }

    TapHandler { id: tapHandler; enabled: root.effectiveEnabled; onTapped: root.activate() }
}
