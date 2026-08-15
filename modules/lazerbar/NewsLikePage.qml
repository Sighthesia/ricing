import QtQuick

// Render a local archive rail and a vertical editorial card rhythm.
Item {
    id: root
    readonly property var sidebarEntries: [{id: "latest", label: "Latest"}, {id: "2026", label: "2026 archive"}, {id: "2025", label: "2025 archive"}]
    signal sidebarSelected(string value)
    implicitWidth: 900
    implicitHeight: 700
    Item {
        anchors.fill: parent
        FullscreenSidebar { id: rail; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; entries: root.sidebarEntries; selected: "latest"; onSelectedChangedByUser: root.sidebarSelected(value) }
        Flickable {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.left: rail.right
            width: parent.width - rail.width
            contentWidth: width
            contentHeight: cards.implicitHeight + 56
            clip: true
            Column {
                id: cards
                x: 28
                y: 28
                width: parent.width - 56
                spacing: 14
                Text { text: "Home / News / Latest"; color: "#FF66AA"; font.pixelSize: 12 }
                Text { text: "News archive"; color: "white"; font.pixelSize: 30; font.bold: true }
                Repeater { model: [{title: "A new season of calm", meta: "Today · 4 min read"}, {title: "Designing for readable motion", meta: "Yesterday · 6 min read"}, {title: "Small surfaces, clear intent", meta: "Aug 12 · 3 min read"}]
                    delegate: Rectangle {
                        width: cards.width
                        height: 118
                        radius: 10
                        color: "#181A22"
                        border.color: "#24FFFFFF"
                        Rectangle { id: preview; width: 118; height: parent.height; radius: 10; color: index === 0 ? "#EB1C60" : "#323746" }
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: preview.width + 24
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Text { width: cards.width - preview.width - 48; text: modelData.title; elide: Text.ElideRight; color: "white"; font.pixelSize: 17; font.bold: true }
                            Text { text: modelData.meta; color: "#A9A4AE"; font.pixelSize: 12 }
                            Text { width: cards.width - preview.width - 48; text: "A quiet local preview of an editorial card."; elide: Text.ElideRight; color: "#C5C0C9" }
                        }
                    }
                }
            }
        }
    }
}
