import QtQuick

// Keep one settings label, description, and injected control aligned.
Item {
    id: root

    property string labelText: ""
    property string descriptionText: ""
    default property alias control: controlHost.data
    readonly property Item controlItem: controlHost.data.length > 0 ? controlHost.data[0] : null

    implicitWidth: 640
    implicitHeight: Math.max(56, descriptionText.length > 0 ? 72 : 56)
    height: implicitHeight

    // Paint the quiet grouped row surface.
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 10
        color: rowHover.hovered ? LazerTheme.settingsRowHover : LazerTheme.settingsRow

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Present the setting copy without coupling it to a service.
    Column {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            text: root.labelText
            color: LazerTheme.textPrimary
            font.pixelSize: 14
        }

        Text {
            visible: root.descriptionText.length > 0
            text: root.descriptionText
            color: LazerTheme.textMuted
            font.pixelSize: 11
        }
    }

    // Reserve the right edge for the caller-provided control.
    Item {
        id: controlHost
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }

    HoverHandler { id: rowHover }
}
