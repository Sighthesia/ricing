import QtQuick

// Present one keyboard-accessible menu action.
Rectangle {
    id: root
    property string label: ""
    property string shortcut: ""
    property bool enabled: true
    property bool current: false
    signal triggered

    implicitWidth: 220
    implicitHeight: 36
    radius: 7
    color: current ? "#18FFFFFF" : "transparent"
    opacity: enabled ? 1 : MotionTokens.disabledOpacity
    activeFocusOnTab: enabled

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12
        Text { width: parent.width - shortcutText.width - 12; anchors.verticalCenter: parent.verticalCenter; text: root.label; color: LazerTheme.textPrimary; elide: Text.ElideRight }
        Text { id: shortcutText; anchors.verticalCenter: parent.verticalCenter; text: root.shortcut; color: root.current ? LazerTheme.textMuted : "#85818A"; font.pixelSize: 11 }
    }
    Keys.onReturnPressed: root.triggered()
    Keys.onEnterPressed: root.triggered()
    Keys.onSpacePressed: root.triggered()
    TapHandler { enabled: root.enabled; onTapped: root.triggered() }
    HoverHandler { id: hover; enabled: root.enabled; onHoveredChanged: if (hovered) root.forceActiveFocus() }
    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
}
