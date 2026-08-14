import QtQuick

// Keep text editing isolated from persistence and own keyboard focus reliably.
FocusScope {
    id: root

    property string text: ""
    property string placeholderText: ""
    property bool enabled: true
    property bool rowEnabled: true
    property real availableWidth: Infinity
    property real requestedWidth: implicitWidth
    property string accessibleName: ""
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property bool focusVisible: editor.activeFocus
    readonly property Item editorItem: editor
    property bool syncingEditor: false
    property bool pendingExternalText: false
    property bool committing: false
    signal textCommitted(string text)
    signal clearRequested()

    implicitWidth: 240
    implicitHeight: 38
    width: Math.min(Math.max(0, requestedWidth), availableWidth)
    height: implicitHeight
    opacity: effectiveEnabled ? 1 : MotionTokens.disabledOpacity
    activeFocusOnTab: effectiveEnabled
    Accessible.role: Accessible.EditableText
    Accessible.name: accessibleName

    function focusEditor() {
        if (effectiveEnabled)
            editor.forceActiveFocus()
    }

    function syncEditorFromText() {
        if (syncingEditor || editor.text === root.text)
            return
        syncingEditor = true
        editor.text = root.text
        syncingEditor = false
    }

    onTextChanged: {
        if (editor.activeFocus && !committing) {
            pendingExternalText = true
            return
        }
        pendingExternalText = false
        syncEditorFromText()
    }
    Component.onCompleted: syncEditorFromText()

    onActiveFocusChanged: {
        if (activeFocus && effectiveEnabled && !editor.activeFocus)
            editor.forceActiveFocus()
    }

    onEffectiveEnabledChanged: {
        if (!effectiveEnabled) {
            if (editor.activeFocus)
                editor.focus = false
            if (activeFocus)
                focus = false
        }
    }

    onFocusChanged: {
        if (!focus && pendingExternalText) {
            pendingExternalText = false
            syncEditorFromText()
        }
    }

    function commit() {
        if (!root.effectiveEnabled)
            return
        committing = true
        textCommitted(editor.text.trim())
        committing = false
        pendingExternalText = false
        syncEditorFromText()
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
        focus: true
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
