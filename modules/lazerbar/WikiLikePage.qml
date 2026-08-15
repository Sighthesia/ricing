import QtQuick

// Render a local wiki-shaped article with mixed full-width and split panels.
Item {
    id: root
    property int contentPadding: 28
    readonly property var sidebarEntries: [
        { id: "overview", label: "Overview" }, { id: "getting-started", label: "Getting started" },
        { id: "shortcuts", label: "Keyboard shortcuts" }, { id: "appearance", label: "Appearance" }
    ]
    signal sidebarSelected(string value)
    implicitWidth: 900
    implicitHeight: 700

    Item {
        anchors.fill: parent
        FullscreenSidebar { id: rail; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; entries: root.sidebarEntries; selected: "overview"; onSelectedChangedByUser: root.sidebarSelected(value) }
        Flickable {
            anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.left: rail.right
            width: parent.width - rail.width; contentWidth: width; contentHeight: article.implicitHeight + root.contentPadding * 2; clip: true
            Column {
                id: article; x: root.contentPadding; y: root.contentPadding; width: parent.width - root.contentPadding * 2; spacing: 18
                Text { text: "Home / Wiki / Overview"; color: "#FF66AA"; font.pixelSize: 12 }
                Text { text: "Afloat, in motion"; color: "white"; font.pixelSize: 30; font.bold: true }
                Rectangle { width: parent.width; height: 94; radius: 10; color: "#181A22"; border.color: "#28FFFFFF"; Text { anchors.fill: parent; anchors.margins: 18; text: "A calm desktop shell for focused work. This local article demonstrates the long-form rhythm used by the fullscreen surface."; wrapMode: Text.WordWrap; color: "#D6D1DB"; font.pixelSize: 14 } }
                Row { width: parent.width; spacing: 14; Repeater { model: ["Structure", "Motion"]; delegate: Rectangle { width: (article.width - 14) / 2; height: 120; radius: 10; color: "#15171F"; Text { anchors.fill: parent; anchors.margins: 16; text: modelData + "\n\nA focused panel with a clear hierarchy."; color: "#D6D1DB"; wrapMode: Text.WordWrap } } } }
                Rectangle { width: parent.width; height: 150; radius: 10; color: "#20212B"; Text { anchors.fill: parent; anchors.margins: 20; text: "## Notes\n\nStatic content keeps this prototype deterministic while the shared host proves route, focus, and layout behavior."; color: "#E9E4ED"; font.pixelSize: 14; wrapMode: Text.WordWrap } }
            }
        }
    }
}
