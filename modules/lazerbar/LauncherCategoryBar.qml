import QtQuick

// Category lens for the launcher: one chip per category of the active mode
// plus the unfiltered "All" chip, ordered by the mode taxonomy. It sits
// between the search rail and the results, so the lens reads as part of the
// query surface rather than a separate panel.
//
// The rail never scrolls itself: interactive stays off, so a wheel gesture
// always scrolls the result list below and a drag never competes with text
// selection. Off-screen chips are only reached by keyboard focus, which
// nudges contentX manually.
Item {
    id: root

    property var chips: []
    property string selected: ""
    readonly property int chipSpacing: 6
    // Chip-row inset from the rail edges. Writable so the hosting page can
    // flush the first chip against its own edge: the rail chrome's content
    // column already starts at the sidebar, so it overrides this to 0.
    property int railPadding: 12
    signal chipSelected(string id)

    implicitHeight: 26
    height: implicitHeight

    function chipAt(index) {
        return chipRepeater.itemAt(index)
    }

    function indexOfChip(id) {
        for (var i = 0; i < chips.length; i++)
            if (chips[i].id === id)
                return i
        return -1
    }

    // Keyboard browsing skips empty chips: they are not focusable, so moving
    // by arrow should land on the next one the user could Tab to. Wraps
    // around so the rail is a loop rather than a dead end.
    function focusSibling(fromIndex, direction) {
        var count = chipRepeater.count
        if (count <= 0)
            return
        var step = direction < 0 ? -1 : 1
        for (var hop = 1; hop <= count; hop++) {
            var index = (fromIndex + step * hop + count * count) % count
            var candidate = chipRepeater.itemAt(index)
            if (candidate && candidate.interactive) {
                candidate.forceActiveFocus()
                ensureVisible(candidate)
                return
            }
        }
    }

    // Manual scroll: with interactive off the Flickable refuses to be driven,
    // so focus moving past the rail edges nudges contentX here.
    function ensureVisible(item) {
        if (!item)
            return
        var left = item.x + item.parent.x - railPadding
        var right = left + item.width
        if (left < rail.contentX) {
            rail.contentX = Math.max(0, left)
        } else if (right > rail.contentX + rail.width) {
            var maximumX = Math.max(0, rail.contentWidth - rail.width)
            rail.contentX = Math.max(0, Math.min(maximumX, right - rail.width))
        }
    }

    function activate(index) {
        var chip = chipRepeater.itemAt(index)
        if (!chip || !chip.interactive)
            return
        chip.activate()
    }

    // Horizontal viewport over the chip row; content width rides the row so a
    // category leaving the taxonomy cannot leave a stale gap behind.
    Flickable {
        id: rail
        anchors.fill: parent
        contentWidth: chipRow.x + chipRow.width
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        clip: true

        Row {
            id: chipRow
            x: root.railPadding
            y: 0
            height: rail.height
            spacing: root.chipSpacing

            Repeater {
                id: chipRepeater
                model: root.chips

                delegate: LauncherCategoryChip {
                    required property int index
                    required property var modelData
                    height: rail.height
                    label: modelData.label
                    count: modelData.count
                    selected: root.selected === modelData.id
                    onActivated: root.chipSelected(modelData.id)
                    onMoveRequested: direction => root.focusSibling(index, direction)
                }
            }
        }
    }
}