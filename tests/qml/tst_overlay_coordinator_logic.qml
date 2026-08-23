import QtQuick
import QtTest
import "../../modules/lazerbar/OverlayCoordinatorLogic.js" as Logic
import "../../modules/lazerbar/LauncherSurfaceLogic.js" as SurfaceLogic

// Verify target validation, visual-owner classification, and the launcher
// surface mirror decisions without loading QML surfaces.
Item {
    TestCase {
        name: "OverlayCoordinatorLogic"

        function test_targetClassification() {
            compare(Logic.normalizeTarget("launcher"), "launcher")
            compare(Logic.normalizeTarget("remote"), "")
            compare(Logic.ownerFor("launcher"), "wave")
            compare(Logic.ownerFor("settings"), "settings")
            compare(Logic.ownerFor("music"), "music")
            compare(Logic.ownerFor("remote"), "")
        }

        function test_deprecatedWaveTargetsAreRejected() {
            compare(Logic.normalizeTarget("wiki"), "")
            compare(Logic.normalizeTarget("news"), "")
            compare(Logic.normalizeTarget("beatmap"), "")
            compare(Logic.ownerFor("wiki"), "")
            compare(Logic.ownerFor("news"), "")
            compare(Logic.ownerFor("beatmap"), "")
        }

        function test_ownerPairsAreDistinctOwners() {
            verify(Logic.ownerFor("launcher") !== Logic.ownerFor("settings"))
            verify(Logic.ownerFor("launcher") !== Logic.ownerFor("music"))
            verify(Logic.ownerFor("settings") !== Logic.ownerFor("music"))
        }
    }

    TestCase {
        name: "LauncherSurfaceLogic"

        function snapshot(sessionVisible, hostPhase, activeTarget, transitioning, pendingTarget) {
            return {
                sessionVisible: sessionVisible,
                hostPhase: hostPhase,
                activeTarget: activeTarget,
                transitioning: transitioning,
                pendingTarget: pendingTarget
            }
        }

        function test_openAction_hiddenSessionOpensStandaloneSession() {
            compare(SurfaceLogic.openAction(
                snapshot(false, "closed", "", false, "")), "open-session")
            // Even mid-transition a hidden session must re-open first.
            compare(SurfaceLogic.openAction(
                snapshot(false, "closing", "launcher", true, "")), "open-session")
        }

        function test_openAction_foreignOwnerSerializesThroughCoordinator() {
            compare(SurfaceLogic.openAction(
                snapshot(true, "closed", "settings", false, "")), "request-coordinated-open")
            compare(SurfaceLogic.openAction(
                snapshot(true, "closed", "music", false, "")), "request-coordinated-open")
            compare(SurfaceLogic.openAction(
                snapshot(true, "closed", "", false, "")), "request-coordinated-open")
        }

        function test_openAction_liveSurfaceRefocusesInsteadOfSecondInstance() {
            compare(SurfaceLogic.openAction(
                snapshot(true, "open", "launcher", false, "")), "refocus-search")
            compare(SurfaceLogic.openAction(
                snapshot(true, "opening", "launcher", false, "")), "refocus-search")
        }

        function test_openAction_midCloseOrDesyncedHostReopensSameInstance() {
            // Escape-style self-close with the session still alive.
            compare(SurfaceLogic.openAction(
                snapshot(true, "closing", "launcher", false, "")), "reopen-host")
            // Queued behind another owner's hand-off while still closing.
            compare(SurfaceLogic.openAction(
                snapshot(true, "closing", "launcher", true, "settings")), "reopen-host")
            // Desynced closed host with a live session recovers by reopening.
            compare(SurfaceLogic.openAction(
                snapshot(true, "closed", "launcher", false, "")), "reopen-host")
        }

        function test_closeAction_visibleSessionIsNeverHandledHere() {
            compare(SurfaceLogic.closeAction(
                snapshot(true, "open", "launcher", false, "")), "none")
        }

        function test_closeAction_idleOpenLauncherClosesThroughCoordinator() {
            compare(SurfaceLogic.closeAction(
                snapshot(false, "open", "launcher", false, "")), "request-coordinated-close")
            compare(SurfaceLogic.closeAction(
                snapshot(false, "opening", "launcher", false, "")), "request-coordinated-close")
        }

        function test_closeAction_selfClosingOrFinishedCloseIsIgnored() {
            // Escape path: the running close must not be restarted.
            compare(SurfaceLogic.closeAction(
                snapshot(false, "closing", "launcher", false, "")), "none")
            compare(SurfaceLogic.closeAction(
                snapshot(false, "closed", "launcher", false, "")), "none")
        }

        function test_closeAction_staleQueuedLauncherIsCancelled() {
            compare(SurfaceLogic.closeAction(
                snapshot(false, "closed", "settings", true, "launcher")), "cancel-stale-open")
            // Other queued targets are left to their own owners.
            compare(SurfaceLogic.closeAction(
                snapshot(false, "closed", "settings", true, "music")), "none")
        }

        function test_closeAction_otherOwnersAreUntouched() {
            compare(SurfaceLogic.closeAction(
                snapshot(false, "closed", "settings", false, "")), "none")
            compare(SurfaceLogic.closeAction(
                snapshot(false, "closed", "music", false, "")), "none")
            compare(SurfaceLogic.closeAction(
                snapshot(false, "closed", "", false, "")), "none")
        }
    }
}
