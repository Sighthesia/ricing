import QtQuick
import "../../services" as Services

// Filterable list of niri shortcuts from binds.kdl.
Item {
    id: root

    anchors.fill: parent

    property string filterText: {
        let q = Services.LauncherService.query
        return q.startsWith(">key ") ? q.slice(5) : q
    }
    property string normalizedFilterText: filterText.toLowerCase().trim()

    ListView {
        anchors.fill: parent
        anchors.margins: 8
        clip: true
        spacing: 4
        model: Services.NiriShortcutService.shortcutsModel
        delegate: ShortcutDelegate {
            readonly property bool matchesFilter: {
                const q = root.normalizedFilterText
                if (!q) return true
                return label.toLowerCase().includes(q)
                    || sequence.toLowerCase().includes(q)
                    || category.toLowerCase().includes(q)
            }

            height: matchesFilter ? 52 : 0
            opacity: matchesFilter ? 1 : 0
            x: matchesFilter ? 0 : 28
            visible: height > 1 || opacity > 0.01

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
            Behavior on x { NumberAnimation { duration: 180; easing.type: matchesFilter ? Easing.OutCubic : Easing.InCubic } }
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: matchesFilter ? Easing.OutCubic : Easing.InCubic } }
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                NumberAnimation { property: "_filterOffset"; from: 24; to: 0; duration: 200; easing.type: Easing.OutCubic }
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
                NumberAnimation { property: "_filterOffset"; to: 28; duration: 180; easing.type: Easing.InCubic }
            }
        }

        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
        }
    }

    // Status/error footer
    Services.FluidText {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 }
        text: Services.NiriShortcutService.errorText || Services.NiriShortcutService.statusText
        color: Services.NiriShortcutService.errorText ? "#ff6666" : "#aaaaaa"
        basePixelSize: 11
    }
}
