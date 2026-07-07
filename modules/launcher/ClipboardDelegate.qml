import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Clipboard result row with per-delegate filtering via height/opacity/x
// transitions.  Uses stable full-list model (no add/remove model churn).
Rectangle {
    id: delegate

    required property var modelData
    required property int index
    required property string query
    property var hoverHandler: null
    property real _filterOffset: 0

    // Expose hover state for parent preview tracking.
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool isPreviewable: modelData.isImage
        || (modelData.preview && modelData.preview.length > 80)

    readonly property bool matchesFilter: {
        if (!query) return true
        const q = query.toLowerCase().trim()
        const preview = (modelData.preview || "").toLowerCase()
        const kind = modelData.isImage ? "image" : "text"
        return preview.includes(q) || kind.includes(q)
    }

    width: ListView.view.width
    height: matchesFilter ? 48 : 0
    opacity: matchesFilter ? 1 : 0
    x: matchesFilter ? 0 : 28
    visible: height > 1 || opacity > 0.01
    radius: MenuVisuals.rowRadius
    transform: Translate { x: delegate._filterOffset }

    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
    Behavior on x { NumberAnimation { duration: 190; easing.type: matchesFilter ? Easing.OutCubic : Easing.InCubic } }
    Behavior on opacity { NumberAnimation { duration: 190; easing.type: matchesFilter ? Easing.OutCubic : Easing.InCubic } }

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
        // Notify parent list about hover state changes for preview.
        onContainsMouseChanged: {
            if (typeof delegate.hoverHandler === "function") {
                delegate.hoverHandler(delegate.modelData, delegate.index, delegate.hovered)
            }
        }
    }

    // Preview text: show [Image] for images, [empty] for blank, else truncated text
    Services.FluidText {
        anchors { left: parent.left; right: actions.left; top: parent.top; bottom: parent.bottom; leftMargin: MenuVisuals.listContentInset }
        text: modelData.isImage ? "[Image]" : (modelData.preview.length > 0 ? modelData.preview.substring(0, 80) : "[empty]")
        textFormat: Text.PlainText
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
