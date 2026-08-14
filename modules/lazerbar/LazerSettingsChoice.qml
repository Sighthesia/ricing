import QtQuick

// Offer documented enum values through a compact, persistent choice control.
Item {
    id: root

    property var model: []
    property string currentValue: ""
    property bool enabled: true
    property string accessibleName: ""
    readonly property bool focusVisible: activeFocus
    signal valueSelected(string value)

    implicitWidth: 190
    implicitHeight: 36
    activeFocusOnTab: enabled
    opacity: enabled ? 1 : MotionTokens.disabledOpacity
    Accessible.role: Accessible.ComboBox
    Accessible.name: accessibleName

    function validValue(candidate) {
        for (var i = 0; i < model.length; i++)
            if (String(model[i].value) === String(candidate))
                return true
        return false
    }

    function selectValue(candidate) {
        if (!enabled || !validValue(candidate) || String(candidate) === currentValue)
            return
        currentValue = String(candidate)
        valueSelected(currentValue)
    }

    function selectNext(delta) {
        var index = -1
        for (var i = 0; i < model.length; i++)
            if (String(model[i].value) === currentValue) index = i
        if (index < 0 || model.length === 0) return
        selectValue(model[(index + delta + model.length) % model.length].value)
    }

    Keys.onLeftPressed: event => { selectNext(-1); event.accepted = true }
    Keys.onRightPressed: event => { selectNext(1); event.accepted = true }

    // Keep one highlighted choice label and indicator visible at all times.
    Rectangle {
        anchors.fill: parent
        radius: 9
        color: choiceHover.hovered ? LazerTheme.settingsRowHover : LazerTheme.settingsRow
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? LazerTheme.focusRing : LazerTheme.settingsPanelBorder
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentValue
            color: LazerTheme.textPrimary
            elide: Text.ElideRight
        }
        Text { id: chevron; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: LazerTheme.textMuted; font.pixelSize: 18 }
    }

    HoverHandler { id: choiceHover; enabled: root.enabled }
    TapHandler {
        enabled: root.enabled
        onTapped: root.selectNext(1)
    }
}
