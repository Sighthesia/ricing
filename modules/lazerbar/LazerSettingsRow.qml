import QtQuick

// Keep one settings label, description, and injected control aligned.
Item {
    id: root

    property string labelText: ""
    property string descriptionText: ""
    property bool enabled: true
    readonly property bool contentEnabled: enabled
    default property alias control: controlHost.data
    readonly property Item controlItem: controlHost.data.length > 0 ? controlHost.data[0] : null

    implicitWidth: 640
    readonly property real textRegionWidth: textColumn.width
    readonly property real controlRegionLeft: controlHost.x
    implicitHeight: Math.max(56, textColumn.implicitHeight + 24)
    height: implicitHeight
    opacity: root.enabled ? 1 : MotionTokens.disabledOpacity

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
        id: textColumn
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: controlHost.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            id: labelItem
            text: root.labelText
            width: parent.width
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Text {
            id: descriptionItem
            visible: root.descriptionText.length > 0
            text: root.descriptionText
            width: parent.width
            color: LazerTheme.textMuted
            font.pixelSize: 11
            elide: Text.ElideRight
            wrapMode: Text.WordWrap
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

    HoverHandler { id: rowHover; enabled: root.enabled }

    readonly property Item labelTextItem: labelItem
    readonly property Item descriptionTextItem: descriptionItem
}
