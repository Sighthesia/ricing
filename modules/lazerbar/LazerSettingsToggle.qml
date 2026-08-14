import QtQuick

// Expose a service-independent, keyboard and pointer friendly boolean control.
Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property string accessibleName: ""
    signal toggled(bool checked)

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed
    readonly property bool focusVisible: activeFocus

    implicitWidth: 46
    implicitHeight: 26
    opacity: enabled ? 1 : MotionTokens.disabledOpacity
    activeFocusOnTab: enabled
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleName

    function activate() {
        if (!root.enabled)
            return
        root.checked = !root.checked
        root.toggled(root.checked)
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
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuint }
            }
        }
    }

    HoverHandler { id: hoverHandler; enabled: root.enabled }
    TapHandler { id: tapHandler; enabled: root.enabled; onTapped: root.activate() }
}
