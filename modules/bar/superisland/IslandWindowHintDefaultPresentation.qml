import QtQuick
import qs.config
import "." as IslandParts

// Renders the default two-row window-hint presentation.
Item {
    id: root

    required property Item card

    implicitWidth: Math.max(root.card._workspaceStageWidth, root.card._titleStageWidth)
    implicitHeight: root.card._workspaceVisibleStageHeight + root.card._rowGap + root.card._titleStageHeight
    width: implicitWidth
    height: implicitHeight

    // Default stack keeps the workspace and title lanes separate.
    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: root.card._rowGap

        // Lower overview lane stays centered in the upper half.
        Item {
            width: parent.width
            height: root.card._workspaceVisibleStageHeight

            // Workspace stage is reused from the shared clipped stage component.
            IslandParts.IslandWindowHintWorkspaceStage {
                anchors.horizontalCenter: parent.horizontalCenter
                card: root.card
            }
        }

        // Title lane keeps the capsule row aligned with the workspace lane.
        Item {
            width: parent.width
            height: root.card._titleStageHeight

            // Title stage restores the original slot-driven title motion.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.card._titleStageWidth
                height: parent.height
                clip: true

                // Title slot delegates preserve the original centered-stage behavior.
                Repeater {
                    model: root.card._persistentStageSlotIndices

                    // Each title capsule reads motion state from the shared host card.
                    delegate: IslandParts.IslandTitleStageCapsule {
                        required property int modelData

                        host: root.card
                        capsule: root.card._titleStageCapsuleAt(modelData)
                        slotPosition: root.card._titleStageSlotPositionAt(modelData)
                        hiddenForMotion: false
                    }
                }
            }
        }
    }
}
