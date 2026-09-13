import QtQuick
import QtTest
import "../../modules/bar/widgets/WorkspacesWheel.js" as WheelLogic

Item {
    TestCase {
        name: "WorkspacesWheel"

        function makeWorkspaces() {
            return [
                { wsId: "1", idx: 1, isActive: false },
                { wsId: "2", idx: 2, isActive: true },
                { wsId: "3", idx: 3, isActive: false },
            ]
        }

        function makeWindows() {
            return [
                { winId: "a", workspaceId: "2", colIdx: 0, rowIdx: 0 },
                { winId: "b", workspaceId: "2", colIdx: 1, rowIdx: 0 },
                { winId: "c", workspaceId: "2", colIdx: 2, rowIdx: 0 },
                { winId: "z", workspaceId: "1", colIdx: 0, rowIdx: 0 },
            ]
        }

        function test_forward_steps_to_next_window_first() {
            var step = WheelLogic.resolveWheelStep(makeWorkspaces(), makeWindows(), "a", 1)
            compare(step.kind, "window")
            compare(step.winId, "b")
        }

        function test_forward_at_last_window_crosses_to_next_workspace() {
            var step = WheelLogic.resolveWheelStep(makeWorkspaces(), makeWindows(), "c", 1)
            compare(step.kind, "workspace")
            compare(step.idx, 3)
        }

        function test_backward_steps_to_previous_window_first() {
            var step = WheelLogic.resolveWheelStep(makeWorkspaces(), makeWindows(), "c", -1)
            compare(step.kind, "window")
            compare(step.winId, "b")
        }

        function test_backward_at_first_window_crosses_to_prev_workspace() {
            var step = WheelLogic.resolveWheelStep(makeWorkspaces(), makeWindows(), "a", -1)
            compare(step.kind, "workspace")
            compare(step.idx, 1)
        }

        function test_empty_workspace_scrolls_straight_to_neighbor() {
            var workspaces = [
                { wsId: "1", idx: 1, isActive: true },
                { wsId: "2", idx: 2, isActive: false },
            ]
            var step = WheelLogic.resolveWheelStep(workspaces, [], "", 1)
            compare(step.kind, "workspace")
            compare(step.idx, 2)
        }

        function test_at_edge_with_no_neighbor_is_noop() {
            var workspaces = [
                { wsId: "1", idx: 1, isActive: false },
                { wsId: "2", idx: 2, isActive: true },
            ]
            var windows = [{ winId: "a", workspaceId: "2", colIdx: 0, rowIdx: 0 }]
            var step = WheelLogic.resolveWheelStep(workspaces, windows, "a", 1)
            verify(step === null, "last workspace + last window must not wrap")
        }

        function test_unknown_focus_lands_inside_workspace_first() {
            var forward = WheelLogic.resolveWheelStep(makeWorkspaces(), makeWindows(), "", 1)
            compare(forward.kind, "window")
            compare(forward.winId, "a")
            var backward = WheelLogic.resolveWheelStep(makeWorkspaces(), makeWindows(), "", -1)
            compare(backward.kind, "window")
            compare(backward.winId, "c")
        }

        function test_direction_prefers_vertical_then_horizontal() {
            compare(WheelLogic.directionFromDeltas(120, 0, 0, 0), -1)
            compare(WheelLogic.directionFromDeltas(-120, 0, 0, 0), 1)
            compare(WheelLogic.directionFromDeltas(0, 120, 0, 0), -1)
            compare(WheelLogic.directionFromDeltas(0, -120, 0, 0), 1)
            compare(WheelLogic.directionFromDeltas(0, 0, 0, 0), 0)
        }
    }
}
