import QtQuick

// Expose a service-independent, keyboard and pointer friendly boolean control
// rendered as osu's fixed 50x15 Nub with fill/border morph, not a moving thumb.
Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property bool rowEnabled: true
    property real availableWidth: Infinity
    property real requestedWidth: implicitWidth
    property string accessibleName: ""
    property bool fillWidth: false
    signal toggled(bool checked)

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed
    readonly property bool focusVisible: activeFocus
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property real effectiveAvailableWidth: isFinite(Number(availableWidth)) ? Math.max(0, Number(availableWidth)) : Infinity
    readonly property bool hoverHandlerEnabled: hoverHandler.enabled
    readonly property Item nubItem: nub
    readonly property bool nubMorphEnabled: nub.morphBehaviorEnabled

    implicitWidth: 50
    implicitHeight: 15
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

    // Delegate all checked/hover/focus/disabled visuals to the shared nub.
    LazerSettingsNub {
        id: nub
        anchors.centerIn: parent
        checked: root.checked
        hovered: root.hovered
        pressed: root.pressed
        focused: root.focusVisible
        enabled: root.effectiveEnabled
    }

    HoverHandler { id: hoverHandler; enabled: root.effectiveEnabled }
    TapHandler { id: tapHandler; enabled: root.effectiveEnabled; onTapped: root.activate() }
}