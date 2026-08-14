import QtQuick

// Represent one keyboard-accessible settings category in the rail.
Item {
    id: root

    property string label: ""
    property bool selected: false
    property bool interactive: true
    property int index: 0
    signal activated

    implicitWidth: 184
    implicitHeight: 44
    enabled: root.interactive
    activeFocusOnTab: root.interactive
    Accessible.role: Accessible.ListItem
    Accessible.name: root.label

    // Paint the selected category surface without owning the shared indicator.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 12
        color: root.selected ? LazerTheme.settingsSelected : (mouse.containsMouse ? LazerTheme.settingsRowHover : "transparent")
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Keep category text aligned inside the rail capsule.
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.selected ? LazerTheme.textPrimary : LazerTheme.textMuted
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Capture pointer and keyboard activation through one interactive item.
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        onClicked: root.activated()
    }

    Keys.onPressed: event => {
        if (!root.interactive)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activated()
            event.accepted = true
        }
    }
}
