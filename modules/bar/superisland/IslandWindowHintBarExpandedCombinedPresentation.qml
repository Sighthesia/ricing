import QtQuick
import qs.config
import "." as IslandParts

// Renders the combined bar-expanded presentation with a shared backdrop.
Item {
    id: root

    required property Item card

    readonly property real titleRowImplicitWidth: _mainPresentation.titleRowImplicitWidth
    readonly property real relocatedClockRowY: _detachedPresentation.relocatedClockRowY
    readonly property real relocatedClockCenterY: _detachedPresentation.relocatedClockCenterY

    implicitWidth: root.card._barExpandedDetachedWidth
    implicitHeight: root.card._barExpandedCombinedHeight
    width: implicitWidth
    height: implicitHeight

    // Surface owns the shared backdrop and decorative caps for the combined layout.
    IslandParts.IslandWindowHintBarExpandedSurface {
        id: _surface

        card: root.card
    }

    // Main bar-expanded presentation is the widened top lane only.
    IslandParts.IslandWindowHintBarExpandedMainPresentation {
        id: _mainPresentation

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        card: root.card
    }

    // Detached lower lane stays below the main host.
    IslandParts.IslandWindowHintBarExpandedDetachedPresentation {
        id: _detachedPresentation

        anchors.top: parent.top
        anchors.topMargin: root.card._padV + root.card._stagePadV
        anchors.horizontalCenter: parent.horizontalCenter
        card: root.card
    }
}
