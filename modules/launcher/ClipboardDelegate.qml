import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

Rectangle {
    required property var modelData

    width: ListView.view.width
    height: 48
    radius: MenuVisuals.rowRadius
    // Highlight on hover
    color: mouseArea.containsMouse
        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.2)
        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.1)

    // Hover detection only; clicks handled by action areas below
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // Preview text: show [Image] for images, [empty] for blank, else truncated text
    Text {
        anchors { left: parent.left; right: actions.left; top: parent.top; bottom: parent.bottom; leftMargin: MenuVisuals.listContentInset }
        text: modelData.isImage ? "[Image]" : (modelData.preview.length > 0 ? modelData.preview.substring(0, 80) : "[empty]")
        color: Services.Color.mOnSurface
        font.pixelSize: 13
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    // Action buttons anchored to the right
    Row {
        id: actions
        anchors { right: parent.right; rightMargin: MenuVisuals.contentInset; verticalCenter: parent.verticalCenter }
        spacing: MenuVisuals.smallGap

        Text {
            text: "⎘"
            color: Services.Color.mOnSurface
            font.pixelSize: MenuVisuals.actionIconSize
            verticalAlignment: Text.AlignVCenter
            height: MenuVisuals.rowHeight
            MouseArea {
                anchors.fill: parent
                onClicked: { Services.ClipboardService.copyItem(modelData.id); Services.LauncherService.close() }
            }
        }

        Text {
            text: "✕"
            color: Services.Color.mOnSurface
            font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
            height: MenuVisuals.rowHeight
            MouseArea {
                anchors.fill: parent
                onClicked: Services.ClipboardService.deleteItem(modelData.id)
            }
        }
    }
}
