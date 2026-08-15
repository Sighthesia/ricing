import QtQuick
import "OsuOverlayPalette.js" as Palettes

// Reproduce the osu Wiki silhouette with minimal representative article content.
Rectangle {
    id: root
    readonly property string pageKind: "wiki"
    readonly property string paletteKind: "orange"
    readonly property var palette: Palettes.forRoute("wiki")
    readonly property var sidebarEntries: [
        { id: "overview", label: "Overview" }, { id: "guides", label: "Guides" },
        { id: "gameplay", label: "Gameplay" }, { id: "community", label: "Community" }
    ]
    readonly property int sidebarItemCount: sidebarEntries.length
    readonly property int sampleItemCount: 3
    property string selected: "overview"
    color: palette.body

    FullscreenSidebar { id: rail; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; entries: root.sidebarEntries; selected: root.selected; palette: root.palette; railWidth: Math.max(176, Math.min(240, root.width * 0.22)); onSelectedChangedByUser: value => root.selected = value }
    Flickable {
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: rail.right; anchors.right: parent.right
        contentWidth: width; contentHeight: article.implicitHeight + 72; clip: true
        Column {
            id: article; x: 42; y: 34; width: parent.width - 84; spacing: 18
            Text { text: "Welcome to the osu! wiki"; color: root.palette.text; font.pixelSize: 28; font.bold: true }
            Rectangle { width: parent.width; height: 3; color: root.palette.accent }
            Text { width: parent.width; text: "A compact knowledge base for play, creation, and community. This local sample preserves the original reading rhythm without reproducing full articles."; color: root.palette.muted; font.pixelSize: 15; wrapMode: Text.WordWrap; lineHeight: 1.35 }
            Text { text: "Getting started"; color: root.palette.accent; font.pixelSize: 21; font.bold: true }
            Text { width: parent.width; text: "Choose a topic from the left navigation. Links, headings, and article measure follow the osu overlay hierarchy."; color: root.palette.text; font.pixelSize: 14; wrapMode: Text.WordWrap; lineHeight: 1.35 }
            Text { text: "Gameplay and creation"; color: root.palette.accent; font.pixelSize: 21; font.bold: true }
            Text { width: parent.width; text: "Representative text is intentionally brief; layout and interface identity are the deliverable."; color: root.palette.text; font.pixelSize: 14; wrapMode: Text.WordWrap }
        }
    }
}
