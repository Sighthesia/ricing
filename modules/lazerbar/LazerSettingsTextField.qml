import QtQuick

// Keep text editing isolated from persistence and expose explicit commit actions.
Item {
    id: root

    property alias text: editor.text
    property string placeholderText: ""
    property bool enabled: true
    property string accessibleName: ""
    readonly property bool focusVisible: editor.activeFocus
    signal textCommitted(string text)
    signal clearRequested()

    implicitWidth: 240
    implicitHeight: 38
    opacity: enabled ? 1 : MotionTokens.disabledOpacity
    activeFocusOnTab: enabled
    Accessible.role: Accessible.EditableText
    Accessible.name: accessibleName

    function commit() {
        if (!root.enabled)
            return
        editor.text = editor.text.trim()
        textCommitted(editor.text)
    }

    function clear() {
        if (!root.enabled)
            return
        editor.text = ""
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
        enabled: root.enabled
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

    HoverHandler { id: fieldHover; enabled: root.enabled }
    TapHandler { enabled: root.enabled; onTapped: editor.forceActiveFocus() }
}
