import QtQuick
import "../../services" as Services

// Filterable clipboard list with soft search transitions.
Item {
    id: root

    anchors.fill: parent
    property string query: Services.LauncherService.query.toLowerCase().trim()
    property var filteredItems: {
        const q = root.query
        const all = Services.ClipboardService.items || []
        if (!q) return all
        return all.filter(item => {
            const preview = (item.preview || "").toLowerCase()
            const kind = item.isImage ? "image" : "text"
            return preview.includes(q) || kind.includes(q)
        })
    }

    ListView {
        anchors.fill: parent
        anchors.margins: 8
        clip: true
        spacing: 4
        model: root.filteredItems
        delegate: ClipboardDelegate {}

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                NumberAnimation { property: "_filterOffset"; from: 24; to: 0; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { property: "_filterSoftness"; from: 1; to: 0; duration: 200; easing.type: Easing.OutCubic }
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
                NumberAnimation { property: "_filterOffset"; to: 28; duration: 180; easing.type: Easing.InCubic }
                NumberAnimation { property: "_filterSoftness"; to: 1; duration: 180; easing.type: Easing.InCubic }
            }
        }

        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
        }
    }

    Component.onCompleted: Services.ClipboardService.list()
}
