import QtQuick
import Quickshell.Widgets
import "../../services" as Services

Item {
    required property var modelData
    width: GridView.view ? GridView.view.cellWidth : 120
    height: GridView.view ? GridView.view.cellHeight : 110

    // Hover highlight background
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: mouseArea.containsMouse ? "#22ffffff" : "transparent"
    }

    Column {
        anchors.centerIn: parent
        spacing: 6

        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "image://icon/" + (modelData.icon || "application-x-executable")
            implicitSize: 48
        }

        Text {
            text: modelData.name
            color: "white"
            font.pixelSize: 12
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            width: (GridView.view ? GridView.view.cellWidth : 120) - 16
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            modelData.execute();
            Services.LauncherService.close();
        }
    }
}
