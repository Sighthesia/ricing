import QtQuick

// Render a dense local beatmap catalogue without implementing search or filters.
Item {
    id: root
    readonly property var sidebarEntries: [{id: "featured", label: "Featured"}, {id: "recent", label: "Recently played"}, {id: "favorites", label: "Favorites"}]
    signal sidebarSelected(string value)
    implicitWidth: 900; implicitHeight: 700
    Item { anchors.fill: parent
        FullscreenSidebar { id: rail; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; entries: root.sidebarEntries; selected: "featured"; onSelectedChangedByUser: root.sidebarSelected(value) }
        Flickable { anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.left: rail.right; width: parent.width - rail.width; contentWidth: width; contentHeight: gridColumn.implicitHeight + 56; clip: true
            Column { id: gridColumn; x: 28; y: 28; width: parent.width - 56; spacing: 14
                Text { text: "Home / Beatmaps"; color: "#FF66AA"; font.pixelSize: 12 }
                Text { text: "Beatmap library"; color: "white"; font.pixelSize: 30; font.bold: true }
                Row { width: parent.width; spacing: 8; Repeater { model: ["Search beatmaps", "All modes", "Sort: recent"]; delegate: Rectangle { width: 150; height: 36; radius: 7; color: "#20222D"; border.color: "#35FFFFFF"; Text { anchors.centerIn: parent; text: modelData; color: "#B8B4BC"; font.pixelSize: 12 } } } }
                Grid { columns: 2; columnSpacing: 12; rowSpacing: 12; Repeater { model: ["Midnight Drive", "Neon Memory", "Paper Planes", "Quiet Signal", "Afterglow", "Blue Hour"]; delegate: Rectangle { width: (gridColumn.width - 12) / 2; height: 92; radius: 8; color: "#171922"; border.color: "#22FFFFFF"; Text { anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: modelData + "\nLocal preview · 4:32"; color: "#EDE8F0"; font.pixelSize: 13 } } } }
            }
        }
    }
}
