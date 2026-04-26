import QtQuick
import qs.config
import qs.services
import "." as IslandParts

// Renders the detached bar-expanded presentation with workspace and clock lanes.
Item {
    id: root

    required property Item card

    implicitWidth: root.card._barExpandedDetachedWidth
    implicitHeight: root.card._barExpandedDetachedContentHeight
    width: implicitWidth
    height: implicitHeight

    // Inner column keeps the workspace strip and relocated clock centered.
    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: parent.height
        spacing: root.card._rowGap

        // Workspace overview stays in the lower wide rectangle.
        Item {
            width: parent.width
            height: Math.max(0, parent.height - root.card._rowGap - root.card._barExpandedDetachedClockHeight)

            // Workspace stage is shared with the default presentation.
            IslandParts.IslandWindowHintWorkspaceStage {
                anchors.horizontalCenter: parent.horizontalCenter
                card: root.card
            }
        }

        // Relocated clock fades into the detached lane instead of swapping abruptly.
        Item {
            width: parent.width
            height: root.card._barExpandedDetachedClockHeight
            opacity: root.card.relocatedClockOpacity
            y: root.card.relocatedClockOffsetY

            // Fade the relocated clock in as it reaches the lower lane.
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: Theme.anim.highlightType
                }
            }

            // Match the relocation movement to the shared reveal timing.
            Behavior on y {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }

            // Idle clock remains centered inside the relocated row.
            IslandParts.IslandIdleClockCard {
                anchors.centerIn: parent

                currentTime: root.card.currentTime
                hasPendingEvents: SuperIslandService.hasPendingEvents
                cardHeight: root.card._barExpandedDetachedClockHeight
            }
        }
    }
}
