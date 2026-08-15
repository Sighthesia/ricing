import QtQuick
import "OsuOverlayPalette.js" as Palettes

// Reproduce the osu Beatmap Listing filter band and dense result-card grid.
Rectangle {
    id: root
    readonly property string pageKind: "beatmap"
    readonly property string paletteKind: "blue"
    readonly property var palette: Palettes.forRoute("beatmap")
    readonly property var sidebarEntries: [{id:"featured",label:"Featured"},{id:"ranked",label:"Ranked"},{id:"favourites",label:"Favourites"}]
    readonly property var beatmaps: ["Midnight Drive","Neon Memory","Paper Planes","Quiet Signal","Afterglow","Blue Hour"]
    readonly property int sidebarItemCount: sidebarEntries.length
    readonly property int sampleItemCount: beatmaps.length
    property string selected: "featured"
    color: palette.body

    FullscreenSidebar { id: rail; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; entries: root.sidebarEntries; selected: root.selected; palette: root.palette; railWidth: Math.max(176, Math.min(220, root.width * 0.2)); onSelectedChangedByUser: value => root.selected = value }
    Flickable {
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: rail.right; anchors.right: parent.right
        contentWidth: width; contentHeight: content.implicitHeight + 54; clip: true
        Column {
            id: content; x: 28; y: 24; width: parent.width - 56; spacing: 14
            Row { spacing: 8; Repeater { model: ["Search beatmaps", "All modes", "Sort: recent"]; delegate: Rectangle { required property string modelData; width: 154; height: 38; radius: 3; color: filterHover.hovered ? root.palette.light3 : root.palette.sidebar; Text { anchors.centerIn: parent; text: modelData; color: root.palette.text; font.pixelSize: 12 } HoverHandler { id: filterHover } Behavior on color { ColorAnimation { duration: MotionTokens.fast } } } } }
            Grid { id: grid; columns: root.width < 900 ? 1 : 2; columnSpacing: 10; rowSpacing: 10
                Repeater { model: root.beatmaps; delegate: Rectangle { required property string modelData; required property int index; width: grid.columns === 1 ? content.width : (content.width - 10) / 2; height: 104; radius: 4; color: cardHover.hovered ? root.palette.dark4 : root.palette.sidebar
                    Rectangle { width: 112; height: parent.height; color: index % 2 ? root.palette.light3 : root.palette.dark4 }
                    Column { x: 128; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 144; spacing: 4
                        Text { width: parent.width; text: modelData; color: root.palette.text; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
                        Text { text: "local preview  |  4:32"; color: root.palette.muted; font.pixelSize: 11 }
                        Text { text: "3.8 stars"; color: root.palette.accent; font.pixelSize: 11; font.bold: true }
                    }
                    HoverHandler { id: cardHover }
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                } }
            }
        }
    }
}
