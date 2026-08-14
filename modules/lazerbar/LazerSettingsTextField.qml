import QtQuick

// Keep text editing isolated from persistence and expose explicit commit actions.
Item {
    id: root

    property alias text: editor.text
    property string placeholderText: ""
    property bool enabled: true
    property bool rowEnabled: true
    property string accessibleName: ""
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property bool focusVisible: editor.activeFocus
    signal textCommitted(string text)
    signal clearRequested()

    implicitWidth: 240
    implicitHeight: 38
    opacity: effectiveEnabled ? 1 : MotionTokens.disabledOpacity
    activeFocusOnTab: effectiveEnabled
    Accessible.role: Accessible.EditableText
    Accessible.name: accessibleName

    onEffectiveEnabledChanged: {
        if (!effectiveEnabled && activeFocus)
            focus = false
    }

    function commit() {
        if (!root.effectiveEnabled)
            return
        textCommitted(editor.text.trim())
    }

    function clear() {
        if (!root.effectiveEnabled)
            return
        clearRequested()
    }

    // Provide the persistent field surface and focus ring.
    Rectangle {
        anchors.fill: parent
        radius: 9
        color: fieldHover.hovered ? LazerTheme.settingsRowHover : LazerTheme.settingsRow
        border.width: editor.activeFocus ? 2 : 1
        border.color: editor.activeFocus ? LazerTheme.focusRing : LazerTheme.settingsPanelBorder
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }
    }

    TextInput {
        id: editor
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        enabled: root.effectiveEnabled
        color: LazerTheme.textPrimary
        selectionColor: LazerTheme.osuPink
        font.pixelSize: 13
        onAccepted: root.commit()
    }

    Text {
        anchors.left: editor.left
        anchors.verticalCenter: editor.verticalCenter
        visible: !editor.text && !editor.activeFocus
        text: root.placeholderText
        color: LazerTheme.textMuted
        font.pixelSize: 13
    }

    HoverHandler { id: fieldHover; enabled: root.effectiveEnabled }
    TapHandler { enabled: root.effectiveEnabled; onTapped: editor.forceActiveFocus() }
}
