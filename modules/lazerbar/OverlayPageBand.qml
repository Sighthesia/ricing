import QtQuick

// Band 2 of the overlay's three-block stack: the page bar.
//
// On osu! wiki this is the row that carries the page's own name (主页) under the
// masthead, and it is a LIGHTER plane than both the masthead above and the
// content below — the middle step of the ladder. Here the same row does double
// duty: the page name on the left (the active section's label, or whatever the
// route names its current page) and the section tabs on the right that switch
// it. That is why the vertical rail could go: its job was the same switch, and
// a mode switch reads as a page switch precisely because the row above already
// declares itself to be a page row.
//
// With no entries the whole band collapses to zero height and the content
// column rises to sit under band 1, so a route with no sections (the control
// center) does not reserve an empty strip.
Item {
    id: root

    property string pageLabel: ""
    property var entries: []
    property string selected: ""
    signal sectionSelected(string id)

    readonly property bool shown: entries.length > 0
    implicitHeight: 44
    height: shown ? implicitHeight : 0
    visible: shown
    objectName: "overlayPageBand"

    function entryIndex() {
        for (var i = 0; i < entries.length; i++)
            if (entries[i].id === selected)
                return i
        return -1
    }

    function tabAt(index) {
        return tabRepeater.itemAt(index)
    }

    function activate(index) {
        var tab = tabRepeater.itemAt(index)
        if (tab && tab.interactive)
            tab.activate()
    }

    // Keyboard browsing walks the whole row and wraps, so Right at the last tab
    // lands on the first rather than dead-ending against the band edge.
    function focusSibling(fromIndex, direction) {
        var count = tabRepeater.count
        if (count <= 0)
            return
        var step = direction < 0 ? -1 : 1
        for (var hop = 1; hop <= count; hop++) {
            var index = (fromIndex + step * hop + count * count) % count
            var candidate = tabRepeater.itemAt(index)
            if (candidate && candidate.interactive) {
                candidate.forceActiveFocus()
                ensureVisible(candidate)
                return
            }
        }
    }

    // Manual scroll: with interactive off the Flickable refuses to be driven, so
    // focus moving past the band's edges nudges contentX here. Same contract as
    // the launcher category rail — a wheel over the band belongs to the list.
    function ensureVisible(item) {
        if (!item)
            return
        var left = item.x + item.parent.x - edgePadding
        var right = left + item.width
        if (left < rail.contentX) {
            rail.contentX = Math.max(0, left)
        } else if (right > rail.contentX + rail.width) {
            var maximumX = Math.max(0, rail.contentWidth - rail.width)
            rail.contentX = Math.max(0, Math.min(maximumX, right - rail.width))
        }
    }

    readonly property int edgePadding: 16
    readonly property int tabSpacing: 4

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: LazerTheme.overlaySectionSurface
    }

    // Page name: the wiki's 主页, in the overlay accent so the row reads as
    // "you are on this page" rather than as another tab.
    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.edgePadding
        anchors.right: rail.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: root.pageLabel !== ""
        text: root.pageLabel
        elide: Text.ElideRight
        color: LazerTheme.settingsAccent
        font.pixelSize: 15
        font.bold: true
    }

    // Section tabs, right-aligned against the band's own edge.
    //
    // The viewport's width is sized from the ROW only. Deriving it from the
    // row's x instead would close a loop — the row is right-aligned against the
    // viewport, so the viewport would be reading back the position it decides —
    // and a bound like that resolves to garbage rather than to an error: every
    // tab lands on the same x and the band shows the labels stacked on top of
    // one another.
    Flickable {
        id: rail
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Math.min(parent.width * 0.6, tabRow.width + root.edgePadding * 2)
        contentWidth: tabRow.x + tabRow.width
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        clip: true

        Row {
            id: tabRow
            x: Math.max(root.edgePadding, rail.width - (tabRow.width + root.edgePadding))
            y: 0
            height: rail.height
            spacing: root.tabSpacing

            Repeater {
                id: tabRepeater
                model: root.entries

                delegate: OverlaySectionTab {
                    required property int index
                    required property var modelData
                    height: rail.height
                    label: modelData.label
                    iconSource: modelData.icon || ""
                    selected: root.selected === modelData.id
                    onActivated: root.sectionSelected(modelData.id)
                    onMoveRequested: direction => root.focusSibling(index, direction)
                }
            }
        }
    }
}