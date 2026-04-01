import QtQuick
import qs.config

// Shared surface for bar-styled context menus.
Rectangle {
    id: root

    property real contentMargin: 0
    default property alias content: contentItem.data

    color: Colors.surface
    radius: Theme.cornerRadius
    border.color: Colors.border
    border.width: 1

    // Content slot.
    Item {
        id: contentItem

        anchors.fill: parent
        anchors.margins: root.contentMargin
    }
}
