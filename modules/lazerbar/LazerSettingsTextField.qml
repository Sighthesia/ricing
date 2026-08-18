import QtQuick

// Keep text editing isolated from persistence and own keyboard focus reliably.
// Uses osu's outlined surface and commits on Enter or focus loss, deduplicated
// against the last committed text so focus changes do not double-save.
FocusScope {
    id: root

    property string text: ""
    property string placeholderText: ""
    property bool enabled: true
    property bool rowEnabled: true
    property real availableWidth: Infinity
    property real requestedWidth: implicitWidth
    property string accessibleName: ""
    property bool fillWidth: true
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property real effectiveAvailableWidth: isFinite(Number(availableWidth)) ? Math.max(0, Number(availableWidth)) : Infinity
    readonly property bool focusVisible: editor.activeFocus
    readonly property bool hovered: fieldHover.hovered
    readonly property Item editorItem: editor
    readonly property Item surfaceItem: fieldSurface
    property bool syncingEditor: false
    property bool pendingExternalText: false
    property bool committing: false
    property string lastCommittedText: ""
    signal textCommitted(string text)
    signal clearRequested()

    implicitWidth: 240
    implicitHeight: 38
    width: Math.min(Math.max(0, isFinite(Number(requestedWidth)) ? Number(requestedWidth) : implicitWidth), effectiveAvailableWidth)
    height: implicitHeight
    opacity: effectiveEnabled ? 1 : LazerTheme.settingsDisabledAlpha
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
    Component.onCompleted: {
        syncEditorFromText()
        lastCommittedText = editor.text.trim()
    }

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
            if (pendingExternalText) {
                pendingExternalText = false
                syncEditorFromText()
            }
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
        var trimmed = editor.text.trim()
        if (trimmed === root.lastCommittedText)
            return
        committing = true
        root.lastCommittedText = trimmed
        textCommitted(trimmed)
        committing = false
        pendingExternalText = false
        syncEditorFromText()
    }

    function clear() {
        if (!root.effectiveEnabled)
            return
        clearRequested()
    }

    // Provide the outlined field surface and focus ring.
    Rectangle {
        id: fieldSurface
        anchors.fill: parent
        radius: LazerTheme.settingsControlRadius
        color: "transparent"
        border.width: editor.activeFocus ? 2 : 1
        border.color: editor.activeFocus ? LazerTheme.focusRing : "#33FFFFFF"
        Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }
        Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }
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
        onActiveFocusChanged: {
            if (!activeFocus) {
                if (root.pendingExternalText) {
                    root.pendingExternalText = false
                    root.syncEditorFromText()
                }
                root.commit()
            }
        }
    }

    Text {
        anchors.left: editor.left
        anchors.verticalCenter: editor.verticalCenter
        visible: !editor.text && !editor.activeFocus
        text: root.placeholderText
        color: LazerTheme.textMuted
        font.pixelSize: 13
    }

    // Keep hover state local to the editable surface so its parent row can
    // observe it without changing the text field's input boundary.
    HoverHandler {
        id: fieldHover
        enabled: root.effectiveEnabled
    }
    TapHandler {
        enabled: root.effectiveEnabled
        onTapped: {
            editor.forceActiveFocus()
        }
    }
}
