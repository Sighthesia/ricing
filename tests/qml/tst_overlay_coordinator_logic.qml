import QtQuick
import QtTest
import "../../modules/lazerbar/OverlayCoordinatorLogic.js" as Logic
import "../../modules/lazerbar/LauncherSurfaceLogic.js" as SurfaceLogic
import "../../modules/lazerbar/WaveSurfaceLogic.js" as WaveLogic

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

        // The screen-scoped entry point asks this instead of hard-coding a
        // branch per route: the answer is the wave owner's own method name, so a
        // screen that dispatched a wave target any other way would have to
        // duplicate the mapping instead of reading it.
        function test_entryMethodNamesTheWaveOwnersOwnRequestMethod() {
            compare(Logic.entryMethodFor("launcher"), "requestOpen")
            compare(Logic.entryMethodFor("control-center"), "requestControlCenter")
            // Every other owner is dispatched by the coordinator itself, so the
            // wave owner has nothing to call: "" is the answer, not a guess.
            compare(Logic.entryMethodFor("settings"), "")
            compare(Logic.entryMethodFor("music"), "")
            compare(Logic.entryMethodFor("wiki"), "")
            compare(Logic.entryMethodFor("remote"), "")
            compare(Logic.entryMethodFor(""), "")
            compare(Logic.entryMethodFor(null), "")
        }

        // The wave owner's two registries are one contract stated twice: what the
        // coordinator will route, and what the surface will mount. A route added
        // to only one of them produces a target that either never dispatches or
        // dispatches onto a page that does not exist, and neither failure is
        // visible from the other side - so the two lists are compared here.
        function test_everyWaveTargetIsBothRoutableAndMountable() {
            var waveTargets = Logic.waveTargets
            compare(waveTargets.length, 2)
            for (var index = 0; index < waveTargets.length; index++) {
                var target = waveTargets[index]
                compare(WaveLogic.isRoute(target), true,
                    target + " is a wave target but the surface cannot mount it")
                compare(Logic.ownerFor(target), "wave")
                compare(Logic.entryMethodFor(target) !== "", true,
                    target + " is a wave target with no entry method")
            }
            // And nothing is routable as a wave route that the surface rejects.
            for (var route = 0; route < WaveLogic.routes.length; route++)
                compare(Logic.normalizeTarget(WaveLogic.routes[route]) !== "", true,
                    WaveLogic.routes[route] + " is a mounted route the coordinator cannot route")
        }

        // The screen-scoped entry asks this instead of branching per route. A
        // plain record stands in for the surface on purpose: the decision reads
        // only the presence of the named method, never the identity of the owner,
        // so a literal cannot make this pass for the wrong reason.
        function test_dispatchSendsWaveTargetsToTheOwnerAndTheRestToTheCoordinator() {
            var owner = {
                requestOpen: function() {},
                requestControlCenter: function() {}
            }
            var launcher = Logic.dispatchFor("launcher", owner)
            compare(launcher.route, "wave")
            compare(launcher.method, "requestOpen")
            var controlCenter = Logic.dispatchFor("control-center", owner)
            compare(controlCenter.route, "wave")
            compare(controlCenter.method, "requestControlCenter")

            // Settings and music have their own owners and are untouched by any of
            // this: whatever the wave owner implements, they go to the coordinator.
            compare(Logic.dispatchFor("settings", owner).route, "coordinator")
            compare(Logic.dispatchFor("music", owner).route, "coordinator")
            // An unroutable target is the coordinator's to reject, as before.
            compare(Logic.dispatchFor("wiki", owner).route, "coordinator")
        }

        // The failure this guards is silent: a wave target whose entry method the
        // owner does not implement used to fall through to the coordinator, which
        // opens the host with no session mirror, no requestedRoute and no opener.
        // The route is then on screen while every later decision - close, refocus,
        // the next open intent - still believes it is closed.
        function test_aWaveTargetTheOwnerDoesNotImplementIsRefusedNotDispatched() {
            // Drift between the route registry and the surface: the registry names
            // a method, the owner has not got it.
            var stale = { requestOpen: function() {} }
            var plan = Logic.dispatchFor("control-center", stale)
            compare(plan.route, "refuse",
                "a wave target with no entry method must not be dispatched at all")
            compare(plan.method, "requestControlCenter",
                "the refusal must still name the method that is missing")

            // No owner at all is the same refusal, not a coordinator dispatch.
            compare(Logic.dispatchFor("launcher", null).route, "refuse")
            compare(Logic.dispatchFor("launcher", undefined).route, "refuse")
            // A member of the right name that is not callable is not an entry
            // method either: it would be called as though it opened a route.
            compare(Logic.dispatchFor("launcher", { requestOpen: "nope" }).route, "refuse")
            // Spelling the same route as a non-wave target does not smuggle it past
            // the refusal either - it lands on the coordinator, which rejects it.
            compare(Logic.dispatchFor("wiki", stale).route, "coordinator")
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
