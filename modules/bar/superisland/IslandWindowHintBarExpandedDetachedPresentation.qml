import QtQuick
import qs.config
import qs.services
import "." as IslandParts

// Renders the detached bar-expanded presentation with workspace and clock lanes.
Item {
    id: root

    required property Item card
    property bool sharedClockActive: false

    readonly property real _visibleContentHeight: Math.max(0, Math.min(root.height, root.card.height - root.y))
    readonly property real _revealProgress:
        root.height > 0
            ? Math.max(0, Math.min(1, root._visibleContentHeight / root.height))
            : 1
    readonly property real _contentTravel:
        (1 - root._revealProgress) * (root.card._workspaceVisibleStageHeight + root.card._rowGap)
    readonly property real relocatedClockRowY: _contentMotionLayer.y + _clockRow.y

    implicitWidth: root.card._barExpandedDetachedWidth
    implicitHeight: root.card._barExpandedDetachedContentHeight
    width: implicitWidth
    height: implicitHeight

    // Shared motion layer lets workspace content travel with the reveal instead of only being clipped.
    Item {
        id: _contentMotionLayer

        x: 0
        y: -root._contentTravel
        width: parent.width
        height: parent.height

        // Workspace overview stays in the lower wide rectangle.
        Item {
            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, parent.height - root.card._rowGap - root.card._barExpandedDetachedClockHeight)

            // Workspace stage is shared with the default presentation.
            IslandParts.IslandWindowHintWorkspaceStage {
                anchors.horizontalCenter: parent.horizontalCenter
                card: root.card
            }
        }

        // Detached clock row remains as a geometry target for the shared moving clock.
        Item {
            id: _clockRow

            x: 0
            y: root.card._workspaceVisibleStageHeight + root.card._rowGap + root.card.relocatedClockOffsetY
            width: parent.width
            height: root.card._barExpandedDetachedClockHeight
        }
    }
}
