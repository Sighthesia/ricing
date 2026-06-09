import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../../services" as Services

// Application result tile with filter-enter and filter-exit softness.
Item {
    id: delegate

    required property var modelData
    property real _filterOffset: 0
    property real _filterSoftness: 0

    width: GridView.view ? GridView.view.cellWidth : 120
    height: GridView.view ? GridView.view.cellHeight : 110
    layer.enabled: _filterSoftness > 0.01
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 12
        blur: delegate._filterSoftness * 0.35
    }

    transform: Translate { x: delegate._filterOffset }

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
