import QtQuick
import qs.config

// Shared divider for bar-styled context menus.
Item {
    id: root

    property real horizontalInset: 4

    // Divider stroke.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.horizontalInset
        anchors.rightMargin: root.horizontalInset
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Colors.border
        opacity: 0.5
    }
}
