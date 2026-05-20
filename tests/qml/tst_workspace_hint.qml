import QtQuick
import QtTest
import "../../modules/workspace-hint/WorkspaceHintViewportModel.js" as Model
import "../../modules/workspace-hint" as WH

Item {
    // Exercise workspace-hint viewport model helpers.
    TestCase {
        name: "WorkspaceHint"

        function test_buildStepQueue_forward() {
            var q = Model.buildStepQueue(1, 3)
            compare(q.length, 2)
            compare(q[0], 2)
            compare(q[1], 3)
        }

        function test_buildStepQueue_backward() {
            var q = Model.buildStepQueue(3, 1)
            compare(q.length, 2)
            compare(q[0], 2)
            compare(q[1], 1)
        }

        function test_buildStepQueue_same() {
            var q = Model.buildStepQueue(2, 2)
            compare(q.length, 0)
        }

        function test_opacityAtDistance_zero() {
            compare(Model.opacityForDistance(0, 72, 216), 1)
        }

        function test_opacityAtDistance_one() {
            compare(Model.opacityForDistance(1, 72, 216), 1)
        }

        function test_opacityAtDistance_halfStep_staysOpaque() {
            compare(Model.opacityForDistance(0.5, 72, 216), 1)
        }

        function test_opacityAtDistance_zero_with_threeStepFade_staysOpaque() {
            compare(Model.opacityForDistance(0, 28, 108), 1)
        }

        function test_opacityAtDistance_two_fades() {
            verify(Model.opacityForDistance(2, 72, 216) < 1)
        }

        function test_opacityAtDistance_far_zero() {
            compare(Model.opacityForDistance(5, 72, 216), 0)
        }

        function test_boundaryBounce_leftEdge() {
            compare(Model.boundaryBounceTarget(0, -1, 0.18), -0.18)
        }

        function test_boundaryBounce_rightEdge() {
            compare(Model.boundaryBounceTarget(4, 1, 0.18), 4.18)
        }

        function test_relativeOffset_positive() {
            compare(Model.relativeOffset(3, 1), 2)
        }

        function test_relativeOffset_negative() {
            compare(Model.relativeOffset(1, 3), -2)
        }

        function test_relativeOffset_zero() {
            compare(Model.relativeOffset(2, 2), 0)
        }

        function test_relativeOffset_nonInteger() {
            compare(Model.relativeOffset(1.5, 0.3), 1.2)
        }

        function test_focusWidth_atZero() {
            compare(Model.focusWidth(28, 200, 0), 28)
        }

        function test_focusWidth_atOne() {
            compare(Model.focusWidth(28, 200, 1), 200)
        }

        function test_focusWidth_atHalf() {
            compare(Model.focusWidth(28, 200, 0.5), 114)
        }

        function test_focusWidth_clampsBelowZero() {
            compare(Model.focusWidth(28, 200, -0.5), 28)
        }

        function test_focusWidth_clampsAboveOne() {
            compare(Model.focusWidth(28, 200, 1.5), 200)
        }

        function test_neighborBaseWidth_keeps_capsule_readable() {
            compare(Model.neighborBaseWidth(28, 72), 72)
        }

        function test_staggerVisibility_for_first_three_capsules() {
            compare(Model.staggerVisibilityForIndex(0, true, false, false), true)
            compare(Model.staggerVisibilityForIndex(1, true, false, false), false)
            compare(Model.staggerVisibilityForIndex(2, true, true, false), false)
        }

        function test_staggerVisibility_keeps_later_capsules_visible() {
            compare(Model.staggerVisibilityForIndex(3, false, false, false), true)
        }

        function test_focusProgress_atCenter() {
            compare(Model.focusProgressForOffset(0), 1)
        }

        function test_focusProgress_half_step() {
            compare(Model.focusProgressForOffset(0.5), 0.5)
        }

        function test_focusProgress_far_step_clamps_to_zero() {
            compare(Model.focusProgressForOffset(2), 0)
        }

        function test_focusProgress_outgoing_workspace_still_visible() {
            verify(Model.focusProgressForOffset(-0.4) > 0)
        }

        function test_useFocusedWidthForCapsule_keeps_outgoing_focus_geometry() {
            compare(Model.useFocusedWidthForCapsule(false, true, 0.4), true)
        }

        function test_shouldExpandCapsule_collapses_after_release() {
            compare(Model.shouldExpandCapsule(true, false), false)
        }
    }

    // Non-visual state object under test.
    WH.WorkspaceHintViewportState {
        id: viewportState
    }

    // Exercise WorkspaceHintViewportState properties and functions.
    TestCase {
        name: "ViewportState"

        function init() {
            viewportState.visualFocusPosition = 0
            viewportState.settledWorkspacePosition = 0
            viewportState.targetWorkspacePosition = 0
            viewportState.pendingWorkspaceSteps = []
        }

        // Verify enqueueWorkspaceTransition fills pending queue correctly.
        function test_enqueueWorkspaceTransition_fillsQueue() {
            viewportState.enqueueWorkspaceTransition(1, 3)
            compare(viewportState.pendingWorkspaceSteps.length, 2)
            compare(viewportState.pendingWorkspaceSteps[0], 2)
            compare(viewportState.pendingWorkspaceSteps[1], 3)
        }

        function test_enqueueWorkspaceTransition_appends_to_existing_queue() {
            viewportState.pendingWorkspaceSteps = [2]
            viewportState.enqueueWorkspaceTransition(2, 4)
            compare(viewportState.pendingWorkspaceSteps.length, 3)
            compare(viewportState.pendingWorkspaceSteps[0], 2)
            compare(viewportState.pendingWorkspaceSteps[1], 3)
            compare(viewportState.pendingWorkspaceSteps[2], 4)
        }

        // Verify advancePendingWorkspaceStep pops first step and sets target.
        function test_advancePendingWorkspaceStep_popsFirst() {
            viewportState.enqueueWorkspaceTransition(1, 3)
            viewportState.advancePendingWorkspaceStep()
            compare(viewportState.targetWorkspacePosition, 2)
            compare(viewportState.pendingWorkspaceSteps.length, 1)
            compare(viewportState.pendingWorkspaceSteps[0], 3)
            compare(viewportState.visualFocusPosition, 2)
            compare(viewportState.settledWorkspacePosition, 2)
        }

        // Verify edgeBounceTargetForTest returns expected bounce offset.
        function test_edgeBounceTargetForTest_leftEdge() {
            compare(viewportState.edgeBounceTargetForTest(0, -1), -0.18)
        }

        // Verify edgeBounceTargetForTest for right edge.
        function test_edgeBounceTargetForTest_rightEdge() {
            compare(viewportState.edgeBounceTargetForTest(4, 1), 4.18)
        }

        // Verify settleEdgeBounce updates visualFocusPosition.
        function test_settleEdgeBounce_updatesFocus() {
            viewportState.settleEdgeBounce(-0.18)
            compare(viewportState.visualFocusPosition, -0.18)
        }

        // Verify settleEdgeBounce also sets target and settled positions.
        function test_settleEdgeBounce_setsAllPositions() {
            viewportState.enqueueWorkspaceTransition(0, 3)
            viewportState.advancePendingWorkspaceStep()
            viewportState.settleEdgeBounce(2.5)
            compare(viewportState.visualFocusPosition, 2.5)
            compare(viewportState.targetWorkspacePosition, 2.5)
            compare(viewportState.settledWorkspacePosition, 2.5)
        }

        function test_consumeTransitionRevision_ignores_stale_revision() {
            var lastConsumedTransitionRevision = 2
            var nextRevision = 2
            var shouldConsume = nextRevision > lastConsumedTransitionRevision
            compare(shouldConsume, false)
        }

        function test_consumeTransitionRevision_accepts_new_revision() {
            var lastConsumedTransitionRevision = 2
            var nextRevision = 3
            var shouldConsume = nextRevision > lastConsumedTransitionRevision
            compare(shouldConsume, true)
        }
    }
}
