import QtQuick

// Reusable interactive row for the bar context menu.
Item {
    id: root

    property string label: ""
    property string icon: ""
    property bool highlighted: false
    property bool destructive: false

    signal clicked()

    width: parent ? parent.width : 160
    height: 32

    // Hover highlight background.
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: rowMouse.containsMouse ? "#333333" : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 8
        spacing: 8

        // Action icon.
        Text {
            text: root.icon
            color: root.destructive ? "#ff6666"
                : root.highlighted ? "#88aaff" : "#aaaaaa"
            font.pixelSize: 14
            width: 16
            horizontalAlignment: Text.AlignHCenter
        }

        // Action label.
        Text {
            text: root.label
            color: root.destructive ? "#ff6666" : "#dddddd"
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
