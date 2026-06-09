import QtQuick
import QtTest
import "../../services" as Services

Item {
    // Verify WindowHintService transition metadata.
    // Requires Quickshell runtime; run only in full environment.
    TestCase {
        name: "WindowHintServiceTransitions"

        function test_empty_hint_exposes_transition_metadata() {
            const hint = Services.WindowHintService._emptyHint()
            compare(hint.previousActiveWorkspacePosition, -1)
            compare(hint.workspaceTransitionRevision, 0)
        }

        function test_build_hint_tracks_previous_workspace_position() {
            const originalActiveWorkspace = Services.WindowHintService._activeWorkspace
            const originalActiveWorkspacePosition = Services.WindowHintService._activeWorkspacePosition
            const originalWorkspaceWindows = Services.WindowHintService._workspaceWindows
            const originalWorkspaceSummaries = Services.WindowHintService._workspaceSummaries
            const originalRevision = Services.WindowHintService._revision
            const originalTransitionRevision = Services.WindowHintService._workspaceTransitionRevision
            const originalLastPosition = Services.WindowHintService._lastActiveWorkspacePosition

            Services.WindowHintService._revision = 0
            Services.WindowHintService._workspaceTransitionRevision = 0
            Services.WindowHintService._lastActiveWorkspacePosition = 1
            Services.WindowHintService._activeWorkspace = function() {
                return { wsId: "ws-2", idx: 3, name: "Workspace 3" }
            }
            Services.WindowHintService._activeWorkspacePosition = function() { return 2 }
            Services.WindowHintService._workspaceWindows = function() { return [] }
            Services.WindowHintService._workspaceSummaries = function() { return [] }

            try {
                const hint = Services.WindowHintService._buildHint(true)
                compare(hint.previousActiveWorkspacePosition, 1)
                compare(hint.activeWorkspacePosition, 2)
                compare(hint.workspaceTransitionRevision, 1)
            } finally {
                Services.WindowHintService._activeWorkspace = originalActiveWorkspace
                Services.WindowHintService._activeWorkspacePosition = originalActiveWorkspacePosition
                Services.WindowHintService._workspaceWindows = originalWorkspaceWindows
                Services.WindowHintService._workspaceSummaries = originalWorkspaceSummaries
                Services.WindowHintService._revision = originalRevision
                Services.WindowHintService._workspaceTransitionRevision = originalTransitionRevision
                Services.WindowHintService._lastActiveWorkspacePosition = originalLastPosition
            }
        }

        function test_refresh_hint_commits_empty_active_workspace() {
            const originalBuildHint = Services.WindowHintService._buildHint
            const originalActiveHint = Services.WindowHintService.activeHint
            const originalHintHeld = Services.WindowHintService.hintHeld

            Services.WindowHintService.hintHeld = true
            Services.WindowHintService.activeHint = {
                visible: true,
                workspaceId: "ws-1",
                workspaceIndex: 1,
                activeWorkspacePosition: 0,
                windows: [{ windowId: "win-1" }],
                workspaces: []
            }
            Services.WindowHintService._buildHint = function() {
                return {
                    visible: true,
                    workspaceId: "ws-2",
                    workspaceIndex: 2,
                    activeWorkspacePosition: 1,
                    windows: [],
                    workspaces: []
                }
            }

            try {
                Services.WindowHintService._refreshHint()
                compare(Services.WindowHintService.activeHint.workspaceId, "ws-2")
                compare(Services.WindowHintService.activeHint.windows.length, 0)
            } finally {
                Services.WindowHintService._buildHint = originalBuildHint
                Services.WindowHintService.activeHint = originalActiveHint
                Services.WindowHintService.hintHeld = originalHintHeld
            }
        }
    }
}
