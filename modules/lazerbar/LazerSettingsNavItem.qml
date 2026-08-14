import QtQuick

// Represent one keyboard-accessible settings category in the rail.
Item {
    id: root

    property string label: ""
    property bool selected: false
    property bool interactive: true
    property string category: "appearance"
    signal activated
    signal moveRequested(int direction)

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
        color: root.selected ? LazerTheme.settingsSelected : (hoverHandler.hovered ? LazerTheme.settingsRowHover : "transparent")
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

    // Capture pointer hover and activation without a competing visual parent.
    HoverHandler { id: hoverHandler; enabled: root.interactive }
    TapHandler {
        id: tapHandler
        enabled: root.interactive
        onTapped: { root.forceActiveFocus(); root.activated() }
    }

    Keys.onPressed: event => {
        if (!root.interactive)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activated()
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            root.moveRequested(event.key === Qt.Key_Down ? 1 : -1)
            event.accepted = true
        }
    }
}
