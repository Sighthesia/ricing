import QtQuick
import QtTest
import "../../modules/workspace-hint/WorkspaceHintStage.js" as Stage
import "../../modules/workspace-hint/WorkspaceHintMotion.js" as Motion
import "../../modules/workspace-hint/WorkspaceHintCapsule.js" as Capsule

Item {
    // Exercise workspace-hint stage helpers.
    TestCase {
        name: "WorkspaceHint"

        function _summary(workspaceId, workspaceIndex, iconCount) {
            var icons = []
            for (var i = 0; i < iconCount; i++)
                icons.push({ icon: "app-" + i, isFocused: i === 0 })

            return {
                workspaceId: workspaceId,
                workspaceIndex: workspaceIndex,
                icons: icons
            }
        }

        function test_workspaceDisplayLayout_prefers_nearest_neighbors() {
            const layout = Stage.workspaceDisplayLayoutForAnchor([
                _summary("ws-1", 1, 1),
                _summary("ws-2", 2, 0),
                _summary("ws-3", 3, 2),
                _summary("ws-4", 4, 1)
            ], 2)

            compare(layout.first, 0)
            compare(layout.last, 3)
            compare(layout.count, 3)
            compare(layout.hasBefore, true)
            compare(layout.hasAfter, true)
        }

        function test_workspaceDisplayLayout_omits_empty_edge_placeholders() {
            const layout = Stage.workspaceDisplayLayoutForAnchor([
                _summary("ws-1", 1, 1),
                _summary("ws-2", 2, 0)
            ], 0)

            compare(layout.first, 0)
            compare(layout.last, 0)
            compare(layout.count, 1)
            compare(layout.hasBefore, false)
            compare(layout.hasAfter, false)
        }

        function test_workspaceCapsuleForAbsolute_uses_active_windows_for_current_workspace() {
            const capsule = Stage.workspaceCapsuleForAbsolute(1, {
                visible: true,
                activeWorkspacePosition: 1,
                workspaceIndex: 2,
                currentWindowTitle: "Editor",
                windows: [
                    { icon: "editor", isFocused: true },
                    { icon: "browser", isFocused: false }
                ],
                workspaces: [
                    _summary("ws-1", 1, 1),
                    _summary("ws-2", 2, 1),
                    _summary("ws-3", 3, 1)
                ]
            })

            compare(capsule.isCurrent, true)
            compare(capsule.icons.length, 2)
            compare(capsule.currentWindowTitle, "Editor")
        }

        function test_workspaceStageCapsulesForHint_merges_current_and_target_windows() {
            const host = {
                _animatedWorkspaceAnchor: 1,
                _workspaceStageSlots: [
                    { absoluteIndex: 0, capsule: { visible: true } },
                    { absoluteIndex: 1, capsule: { visible: true } },
                    { absoluteIndex: 2, capsule: { visible: true } }
                ]
            }

            const items = Stage.workspaceStageCapsulesForHint(host, {
                visible: true,
                activeWorkspacePosition: 2,
                workspaceIndex: 3,
                windows: [{ icon: "terminal", isFocused: true }],
                workspaces: [
                    _summary("ws-1", 1, 1),
                    _summary("ws-2", 2, 1),
                    _summary("ws-3", 3, 1),
                    _summary("ws-4", 4, 1)
                ]
            }, true)

            compare(items.length, 4)
            compare(items[0].absoluteIndex, 0)
            compare(items[3].absoluteIndex, 3)
        }

        function test_workspaceStageCapsulesForHint_keeps_empty_target_current() {
            const host = {
                _animatedWorkspaceAnchor: 0,
                _workspaceStageSlots: [
                    { absoluteIndex: 0, capsule: { visible: true } }
                ]
            }

            const items = Stage.workspaceStageCapsulesForHint(host, {
                visible: true,
                activeWorkspacePosition: 1,
                workspaceIndex: 2,
                windows: [],
                workspaces: [
                    _summary("ws-1", 1, 1),
                    _summary("ws-2", 2, 0)
                ]
            }, true)

            compare(items.length, 2)
            compare(items[1].absoluteIndex, 1)
            compare(items[1].capsule.isCurrent, true)
            compare(items[1].capsule.visible, true)
            compare(items[1].capsule.icons.length, 0)
        }

        function test_workspaceStageCapsulesForHint_keeps_new_empty_target_without_summary() {
            const host = {
                _animatedWorkspaceAnchor: 0,
                _workspaceStageSlots: [
                    { absoluteIndex: 0, capsule: { visible: true } }
                ]
            }

            const items = Stage.workspaceStageCapsulesForHint(host, {
                visible: true,
                activeWorkspacePosition: 1,
                workspaceIndex: 2,
                windows: [],
                workspaces: [
                    _summary("ws-1", 1, 1)
                ]
            }, true)

            compare(items.length, 2)
            compare(items[1].absoluteIndex, 1)
            compare(items[1].capsule.isCurrent, true)
            compare(items[1].capsule.visible, true)
        }

        function test_workspaceStageSlotPosition_tracks_anchor_delta() {
            const host = {
                _animatedWorkspaceAnchor: 2,
                _overflowSlotPosition: 1.18,
                _workspaceStageSlots: [
                    { absoluteIndex: 1, capsule: { visible: true } },
                    { absoluteIndex: 2, capsule: { visible: true } }
                ]
            }

            compare(Stage.workspaceStageSlotPositionAt(host, 0), -1)
            compare(Stage.workspaceStageSlotPositionAt(host, 1), 0)
        }
    }

    // Exercise workspace-hint motion helpers.
    TestCase {
        name: "WorkspaceHintMotion"

        function test_emptyStageSlots_initializes_placeholder_slots() {
            const slots = Motion.emptyStageSlots([0, 1, 2], "workspace-slot")
            compare(slots.length, 3)
            compare(slots[0].absoluteIndex, -1)
            compare(slots[0].slotId, "workspace-slot-0")
        }

        function test_workspaceMetrics_center_slot_uses_primary_size() {
            const metrics = Motion.workspaceMetrics({
                _workspaceStageWidth: 132,
                _workspaceSideWidth: 90,
                _workspacePrimaryWidth: 132,
                _workspaceSideHeight: 28,
                _workspacePrimaryHeight: 44,
                _workspaceColumnGap: 8
            }, 0)

            compare(metrics.width, 132)
            compare(metrics.height, 44)
            compare(metrics.opacity, 1)
        }

        function test_workspaceMetrics_second_workspace_keeps_center_slot() {
            const metrics = Motion.workspaceMetrics({
                _workspaceStageWidth: 132,
                _workspaceSideWidth: 90,
                _workspacePrimaryWidth: 132,
                _workspaceSideHeight: 28,
                _workspacePrimaryHeight: 44,
                _workspaceColumnGap: 8,
                _animatedWorkspaceAnchor: 1
            }, 0)

            compare(metrics.y, 36)
        }

        function test_workspaceMetrics_neighbor_slot_uses_side_metrics() {
            const metrics = Motion.workspaceMetrics({
                _workspaceStageWidth: 132,
                _workspaceSideWidth: 90,
                _workspacePrimaryWidth: 132,
                _workspaceSideHeight: 28,
                _workspacePrimaryHeight: 40,
                _workspaceColumnGap: 8
            }, -1)

            compare(metrics.width, 90)
            compare(metrics.height, 28)
            compare(metrics.opacity, 0.5)
        }

    }

    // Exercise capsule card-width cap distribution.
    TestCase {
        name: "WorkspaceHintCapsule"

        function test_computeExpandedPrimaryWidth_uses_full_visible_content_requirement() {
            compare(Capsule.computeExpandedPrimaryWidth(320, 180, 240), 240)
        }

        function test_computeExpandedPrimaryWidth_never_exceeds_capsule_limit() {
            compare(Capsule.computeExpandedPrimaryWidth(200, 180, 240), 200)
        }

        function test_computeCardTitleWidthCap_returns_infinity_when_content_fits() {
            compare(Capsule.computeCardTitleWidthCap([40, 32], [43, 24], 160, 6), Infinity)
        }

        function test_computeCardTitleWidthCap_returns_infinity_for_zero_cards() {
            compare(Capsule.computeCardTitleWidthCap([], [], 200, 6), Infinity)
        }

        function test_computeCardTitleWidthCap_returns_zero_for_no_title_space() {
            compare(Capsule.computeCardTitleWidthCap([40, 32], [43, 24], 73, 6), 0)
        }

        function test_computeCardTitleWidthCap_distributes_remaining_space_after_small_titles() {
            compare(Capsule.computeCardTitleWidthCap([90, 90, 20], [43, 43, 24], 240, 6), 49)
        }

        function test_computeCardTitleWidthCap_caps_single_card_to_available_space() {
            compare(Capsule.computeCardTitleWidthCap([120], [43], 100, 6), 57)
        }

        function test_computeCardTitleWidthCap_keeps_exact_natural_width_when_only_one_card_overflows() {
            compare(Capsule.computeCardTitleWidthCap([20, 120], [24, 43], 180, 6), 87)
        }
    }
}
