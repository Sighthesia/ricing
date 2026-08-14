import QtQuick

// Expose a service-independent, keyboard and pointer friendly boolean control.
Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property bool rowEnabled: true
    property real availableWidth: Infinity
    property string accessibleName: ""
    signal toggled(bool checked)

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed
    readonly property bool focusVisible: activeFocus
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property bool hoverHandlerEnabled: hoverHandler.enabled
    readonly property bool thumbBehaviorEnabled: thumbBehavior.enabled

    implicitWidth: 46
    implicitHeight: 26
    width: Math.min(implicitWidth, availableWidth)
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

    // Draw one persistent switch body and thumb across state changes.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? LazerTheme.osuPink : LazerTheme.settingsRowHover
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? LazerTheme.focusRing : LazerTheme.settingsPanelBorder

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }

        Rectangle {
            id: thumb
            width: 20
            height: 20
            x: root.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            radius: width / 2
            color: LazerTheme.textPrimary

            Behavior on x {
                id: thumbBehavior
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuint }
            }
        }
    }

    HoverHandler { id: hoverHandler; enabled: root.effectiveEnabled }
    TapHandler { id: tapHandler; enabled: root.effectiveEnabled; onTapped: root.activate() }
}
