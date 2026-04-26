import QtQuick
import qs.config
import "." as IslandParts

// Renders the bar-expanded main presentation with the title row only.
Item {
    id: root

    required property Item card

    readonly property real titleRowImplicitWidth: _titleCapsuleRow.implicitWidth

    implicitWidth: root.card._barExpandedMainWidth
    implicitHeight: Theme.barHeight
    width: implicitWidth
    height: implicitHeight

    // Title capsules are centered inside the widened top host.
    IslandParts.IslandWindowHintTitleCapsuleRow {
        id: _titleCapsuleRow

        anchors.centerIn: parent
        card: root.card
        revealProgress: root.card.titleCapsuleRevealProgress
    }
}
