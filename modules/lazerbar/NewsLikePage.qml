import QtQuick
import "OsuOverlayPalette.js" as Palettes

// Reproduce the osu News archive and article-list proportions with sparse samples.
Rectangle {
    id: root
    readonly property string pageKind: "news"
    readonly property string paletteKind: "purple"
    readonly property var palette: Palettes.forRoute("news")
    readonly property var sidebarEntries: [{id:"latest",label:"Latest"},{id:"2026",label:"2026"},{id:"2025",label:"2025"}]
    readonly property var posts: [
        {date:"15 AUG 2026",title:"A new rhythm for the desktop",summary:"A short local preview showing osu news hierarchy."},
        {date:"08 AUG 2026",title:"Community spotlight",summary:"Cover, date, title, and summary retain their source proportions."},
        {date:"01 AUG 2026",title:"Development update",summary:"Content remains deliberately minimal and deterministic."}
    ]
    readonly property int sidebarItemCount: sidebarEntries.length
    readonly property int sampleItemCount: posts.length
    property string selected: "latest"
    color: palette.body

    FullscreenSidebar { id: rail; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; entries: root.sidebarEntries; selected: root.selected; palette: root.palette; railWidth: Math.max(176, Math.min(230, root.width * 0.21)); onSelectedChangedByUser: value => root.selected = value }
    Flickable {
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: rail.right; anchors.right: parent.right
        contentWidth: width; contentHeight: list.implicitHeight + 60; clip: true
        Column {
            id: list; x: 34; y: 28; width: parent.width - 68; spacing: 12
            Text { text: "Latest news"; color: root.palette.text; font.pixelSize: 26; font.bold: true }
            Repeater {
                model: root.posts
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width; height: 126; radius: 3; color: index % 2 ? root.palette.sidebar : root.palette.dark3
                    Rectangle { width: 176; height: parent.height; color: index === 0 ? root.palette.light3 : root.palette.dark4; Text { anchors.centerIn: parent; text: "osu!"; color: root.palette.text; font.pixelSize: 25; font.bold: true } }
                    Column { x: 198; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 222; spacing: 5
                        Text { text: modelData.date; color: root.palette.accent; font.pixelSize: 10; font.bold: true }
                        Text { width: parent.width; text: modelData.title; color: root.palette.text; font.pixelSize: 18; font.bold: true; elide: Text.ElideRight }
                        Text { width: parent.width; text: modelData.summary; color: root.palette.muted; font.pixelSize: 13; wrapMode: Text.WordWrap }
                    }
                }
            }
        }
    }
}
