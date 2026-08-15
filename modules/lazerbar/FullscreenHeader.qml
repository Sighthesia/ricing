import QtQuick

// Keep the persistent page identity and navigation slot in one header.
Rectangle {
    id: root
    property string title: "Afloat"
    property string breadcrumb: "Home"
    property string iconText: "○"
    property alias slot: headerSlot.data
    signal closeRequested()
    height: 72
    color: "#E91D1D24"
    border.color: "#25FFFFFF"
    border.width: 1

    Row {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        Text { text: root.iconText; color: "#FF66AA"; font.pixelSize: 28; anchors.verticalCenter: parent.verticalCenter }
        Column {
            width: 220
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { text: root.breadcrumb; color: "#A9A4AE"; font.pixelSize: 11 }
            Text { text: root.title; color: "white"; font.pixelSize: 20; font.bold: true }
        }
        Item { id: headerSlot; width: Math.max(0, root.width - 380); height: parent.height }
        Text {
            text: "×"
            color: "#D7D1DB"
            font.pixelSize: 28
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
        }
    }
}
