import QtQuick
import qs.config
import "." as IslandParts

// Renders the animated workspace stage shared by the window-hint layouts.
Item {
    id: root

    required property Item card

    width: root.card._workspaceStageWidth
    height: root.card._workspaceStageHeight

    // Workspace stage stays centered within the available presentation slot.
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: parent.height
        y: -root.card._workspaceLeadingTrim + root.card._workspaceSingleSideOffset
        clip: true

        // Each slot keeps its animated capsule alive inside the clipped stage.
        Repeater {
            model: root.card._persistentStageSlotIndices

            // Workspace capsule delegates read all motion state from the host card.
            delegate: IslandParts.IslandWorkspaceStageCapsule {
                required property int modelData

                host: root.card
                focusIndexPair: root.card._workspaceFocusIndexPair
                capsule: root.card._workspaceStageCapsuleAt(modelData)
                absoluteIndex: root.card._workspaceStageAbsoluteIndexAt(modelData)
                slotPosition: root.card._workspaceStageSlotPositionAt(modelData)
                hiddenForMotion: false
            }
        }
    }
}
