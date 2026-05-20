import QtQuick
import "WorkspaceHintViewportModel.js" as Model

// Non-visual state holder for workspace viewport transitions.
QtObject {
    // Current interpolated visual position across workspaces.
    property real visualFocusPosition: 0

    // Animated visual position consumed by the viewport renderer.
    property real animatedVisualFocusPosition: 0

    // Last settled workspace position (after animation completes).
    property real settledWorkspacePosition: 0

    // Position the viewport is animating toward.
    property real targetWorkspacePosition: 0

    // Steps queued for the current transition (one per workspace hop).
    property var pendingWorkspaceSteps: []

    // Fill the pending queue with each intermediate position between from and to.
    function enqueueWorkspaceTransition(fromPosition, toPosition) {
        pendingWorkspaceSteps = pendingWorkspaceSteps.concat(Model.buildStepQueue(fromPosition, toPosition))
    }

    // Pop the first queued step and advance targetWorkspacePosition.
    function advancePendingWorkspaceStep() {
        if (pendingWorkspaceSteps.length === 0) return
        var first = pendingWorkspaceSteps[0]
        pendingWorkspaceSteps = pendingWorkspaceSteps.slice(1)
        targetWorkspacePosition = first
        visualFocusPosition = first
        settledWorkspacePosition = first
    }

    // Compute a bounce-back target for boundary tests (amplitude 0.18).
    function edgeBounceTargetForTest(edgePosition, direction) {
        return Model.boundaryBounceTarget(edgePosition, direction, 0.18)
    }

    // Snap the visual focus to a settled legal position and update all position trackers.
    function settleEdgeBounce(legalPosition) {
        visualFocusPosition = legalPosition
        animatedVisualFocusPosition = legalPosition
        targetWorkspacePosition = legalPosition
        settledWorkspacePosition = legalPosition
    }

    // Keep the rendered focus path continuous when the logical target changes.
    Behavior on animatedVisualFocusPosition {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    onVisualFocusPositionChanged: animatedVisualFocusPosition = visualFocusPosition
}
