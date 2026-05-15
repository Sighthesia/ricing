import QtQuick
import "../../services" as Services

Rectangle {
    required property var modelData

    width: ListView.view.width
    height: 48
    radius: 6
    // Highlight on hover
    color: mouseArea.containsMouse ? "#33ffffff" : "#1affffff"

    // Hover detection only; clicks handled by action areas below
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // Preview text: show [Image] for images, [empty] for blank, else truncated text
    Text {
        anchors { left: parent.left; right: actions.left; top: parent.top; bottom: parent.bottom; leftMargin: 12 }
        text: modelData.isImage ? "[Image]" : (modelData.preview.length > 0 ? modelData.preview.substring(0, 80) : "[empty]")
        color: "white"
        font.pixelSize: 13
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    // Action buttons anchored to the right
    Row {
        id: actions
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 4

        Text {
            text: "⎘"
            color: "white"
            font.pixelSize: 16
            verticalAlignment: Text.AlignVCenter
            height: 32
            MouseArea {
                anchors.fill: parent
                onClicked: { Services.ClipboardService.copyItem(modelData.id); Services.LauncherService.close() }
            }
        }

        Text {
            text: "✕"
            color: "white"
            font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
            height: 32
            MouseArea {
                anchors.fill: parent
                onClicked: Services.ClipboardService.deleteItem(modelData.id)
            }
        }
    }
}
