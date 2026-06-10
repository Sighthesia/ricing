import QtQuick
import QtQuick.Effects
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Clipboard result row with soft filter exit state.
Rectangle {
    id: delegate

    required property var modelData
    property real _filterOffset: 0
    property real _filterSoftness: 0

    width: ListView.view.width
    height: 48
    radius: MenuVisuals.rowRadius
    layer.enabled: _filterSoftness > 0.01
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 12
        blur: delegate._filterSoftness * 0.35
    }
    transform: Translate { x: delegate._filterOffset }
    // Highlight on hover
    color: mouseArea.containsMouse
        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listHoverOpacity)
        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listRestOpacity)

    // Hover detection only; clicks handled by action areas below
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // Preview text: show [Image] for images, [empty] for blank, else truncated text
    Services.FluidText {
        anchors { left: parent.left; right: actions.left; top: parent.top; bottom: parent.bottom; leftMargin: MenuVisuals.listContentInset }
        text: modelData.isImage ? "[Image]" : (modelData.preview.length > 0 ? modelData.preview.substring(0, 80) : "[empty]")
        color: Services.Color.mOnSurface
        basePixelSize: 13
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    // Action buttons anchored to the right
    Row {
        id: actions
        anchors { right: parent.right; rightMargin: MenuVisuals.contentInset; verticalCenter: parent.verticalCenter }
        spacing: MenuVisuals.smallGap

        Services.FluidText {
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

        Services.FluidText {
            text: "✕"
            color: Services.Color.mOnSurface
            basePixelSize: 14
            verticalAlignment: Text.AlignVCenter
            height: MenuVisuals.rowHeight
            MouseArea {
                anchors.fill: parent
                onClicked: Services.ClipboardService.deleteItem(modelData.id)
            }
        }
    }
}
