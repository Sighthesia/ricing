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
            compare(Logic.normalizeTarget("control-center"), "control-center")
            compare(Logic.normalizeTarget("remote"), "")
            compare(Logic.ownerFor("launcher"), "wave")
            compare(Logic.ownerFor("control-center"), "wave")
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

        // The same snapshot plus the route the caller asked for. An absent
        // requestedRoute means "launcher", which is what every launcher-only
        // caller and test above relies on.
        function routeSnapshot(sessionVisible, hostPhase, activeTarget, transitioning, pendingTarget, requestedRoute) {
            var state = snapshot(sessionVisible, hostPhase, activeTarget, transitioning, pendingTarget)
            state.requestedRoute = requestedRoute
            return state
        }

        function test_openAction_followsTheRequestedRouteNotAHardCodedLauncher() {
            // The control center is a sibling route on the same wave owner, so
            // every decision has to read the requested route: a launcher-only
            // comparison would send a control-center open back down the launcher
            // path and refocus a search field that is not on screen.
            compare(SurfaceLogic.openAction(
                routeSnapshot(true, "closed", "", false, "", "control-center")),
                "request-coordinated-open")
            compare(SurfaceLogic.openAction(
                routeSnapshot(true, "closed", "control-center", false, "", "launcher")),
                "request-coordinated-open")
            compare(SurfaceLogic.openAction(
                routeSnapshot(true, "open", "control-center", false, "", "control-center")),
                "refocus-search")
            compare(SurfaceLogic.openAction(
                routeSnapshot(true, "closing", "control-center", false, "", "control-center")),
                "reopen-host")
        }

        function test_closeAction_cancelsAndClosesOnTheRequestedRoute() {
            compare(SurfaceLogic.closeAction(
                routeSnapshot(false, "open", "control-center", false, "", "control-center")),
                "request-coordinated-close")
            compare(SurfaceLogic.closeAction(
                routeSnapshot(false, "closed", "settings", true, "control-center", "control-center")),
                "cancel-stale-open")
            // A stale queued launcher must not be cancelled by a control-center
            // hide: they are different routes with different owners' work at stake.
            compare(SurfaceLogic.closeAction(
                routeSnapshot(false, "closed", "settings", true, "launcher", "control-center")),
                "none")
            // And the launcher default is unchanged for a launcher snapshot.
            compare(SurfaceLogic.closeAction(
                snapshot(false, "open", "launcher", false, "")),
                "request-coordinated-close")
        }

        function test_anAbsentRequestedRouteMeansLauncher() {
            compare(SurfaceLogic.openAction(
                routeSnapshot(true, "open", "launcher", false, "", "")),
                "refocus-search")
            compare(SurfaceLogic.closeAction(
                routeSnapshot(false, "open", "launcher", false, "", undefined)),
                "request-coordinated-close")
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
