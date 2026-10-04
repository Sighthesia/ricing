import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Exercise mutual exclusion, pending transitions, final focus restoration,
// and the direct launcher opener path by instantiating the real production
// stack: OverlayCoordinator plus LauncherSurface (wave shell + launcher page
// + session mirror), so the harness cannot drift from the mounted wiring.
Item {
    id: host
    width: 1000
    height: 700

    Item { id: opener; objectName: "opener"; focus: true }
    Item { id: alternateOpener; objectName: "alternate-opener" }

    Lazer.OverlayCoordinator {
        id: coordinator
        onOpenRequested: (owner, target) => { if (owner === "wave") launcherSurface.host.openRoute(target, null) }
        onCloseRequested: owner => { if (owner === "wave") launcherSurface.host.close() }
    }

    SignalSpy { id: openSpy; target: coordinator; signalName: "openRequested" }
    SignalSpy { id: closeSpy; target: coordinator; signalName: "closeRequested" }

    // Production-shaped launcher wiring with the embedded Quickshell-free
    // session; every open intent funnels through requestOpen / syncVisibility.
    Lazer.LauncherSurface {
        id: launcherSurface
        anchors.fill: parent
        coordinator: coordinator
    }

    function page() { return launcherSurface.page() }
    function session() { return launcherSurface.session }

    TestCase {
        name: "OverlayCoordinator"
        when: windowShown

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = true
            coordinator.activeTarget = ""
            coordinator.activeOwner = ""
            coordinator.pendingTarget = ""
            coordinator.transitioning = false
            coordinator.opener = null
            coordinator._closingOwner = ""
            if (launcherSurface.host.phase !== "closed")
                launcherSurface.host.finishClose()
            var s = host.session()
            s._refreshToken++
            s.visible = false
            s.query = ""
            s.results = []
            s.loading = false
            s.error = ""
            s.selectedIndex = -1
            s._adapters = ({})
            launcherSurface.pendingOpener = null
            launcherSurface.requestedRoute = "launcher"
            openSpy.clear()
            closeSpy.clear()
            opener.forceActiveFocus()
            s._pooledMode = ""
            s.displayPool = []
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_launcherActivationOpensThroughWaveOwnerAndFocusesSearch() {
            launcherSurface.requestOpen(opener)
            compare(openSpy.count, 1)
            compare(openSpy.signalArguments[0][0], "wave")
            compare(openSpy.signalArguments[0][1], "launcher")
            compare(coordinator.activeTarget, "launcher")
            compare(coordinator.activeOwner, "wave")
            verify(host.session().visible)

            tryCompare(launcherSurface.host, "phase", "open", 1600)
            tryVerify(function() { return host.page().searchField.activeFocus }, 300)
        }

        function test_controlCenterIsASiblingRouteOnTheSameWaveOwner() {
            launcherSurface.requestControlCenter(opener)

            // One owner, one dispatch: the control center is a route on the wave
            // surface, not a second overlay or a second coordinator.
            compare(openSpy.count, 1)
            compare(openSpy.signalArguments[0][0], "wave")
            compare(openSpy.signalArguments[0][1], "control-center")
            compare(coordinator.activeOwner, "wave")
            compare(coordinator.activeTarget, "control-center")

            tryCompare(launcherSurface.host, "phase", "open", 1600)
            compare(launcherSurface.host.route, "control-center")
            verify(launcherSurface.activePage() !== null,
                   "the control center must own a page on the shared surface")
            compare(launcherSurface.activePage().objectName, "controlCenterPage",
                    "the route must mount its own page, not the launcher's")
            verify(launcherSurface.page() === null,
                   "the launcher accessor must not answer for another route")

            // The route's own focus target is used, and the launcher's search
            // field is not: the launcher page is not even mounted here, so a
            // hard-coded focusSearch would either no-op or, once the launcher
            // comes back, steal focus from a control center that never had it.
            tryCompare(launcherSurface.activePage(), "focusDefaultCount", 1, 500)
            verify(launcherSurface.page() === null)

            // Opener restoration is the launcher's existing contract, shared.
            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 800)
            compare(coordinator.activeTarget, "")
            verify(opener.activeFocus)
        }

        // The launcher <-> control-center hand-off is one wave owner being
        // handed a sibling route, not two overlays serializing. It must land
        // open: a close that only happens to share its completion signal with a
        // genuine hide would shut the surface the user just asked for.
        function test_aSiblingRouteHandOffLeavesTheSurfaceOpen() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            tryVerify(function() { return host.page() !== null }, 500)

            launcherSurface.requestControlCenter(opener)

            // Wait for settled state rather than sampling mid-flight: the
            // failure mode is a close arriving after the open, so an
            // immediate assertion would read a perfectly healthy surface.
            wait(600)

            compare(launcherSurface.host.phase, "open",
                    "the hand-off must settle open, not closed")
            compare(launcherSurface.host.route, "control-center")
            compare(coordinator.activeTarget, "control-center")
            compare(coordinator.activeOwner, "wave")
            compare(coordinator.pendingTarget, "")
            verify(!coordinator.transitioning)
            compare(closeSpy.count, 1,
                    "one close for the hand-off; the re-open must not close again")
            compare(openSpy.count, 2)
            compare(host.session().visible, true,
                    "the session stays visible across a same-owner route hand-off")
            verify(launcherSurface.page() === null)
            tryVerify(function() {
                return launcherSurface.activePage()
                        && launcherSurface.activePage().focusDefaultCount === 1
            }, 500)
        }

        // A close is not always a hide, so the coordinator says which one it settled.
        // The wave owner needs the answer: it serves several routes, and a
        // sibling-route hand-off closes the surface and immediately reopens it.
        function test_ownerClosedReportsWhetherTheOwnerComesBack() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            // Queued sibling route: this owner is about to be reopened, so it
            // must not be treated as gone.
            verify(coordinator.request("control-center", opener, true, true))
            compare(coordinator.ownerClosed("wave"), "reopened")
            compare(coordinator.activeOwner, "wave")
            compare(coordinator.activeTarget, "control-center")
            compare(coordinator.pendingTarget, "")

            // Queued other owner: it takes the transition and this owner is
            // released, even though the wave surface is genuinely closing.
            verify(coordinator.request("settings", alternateOpener))
            compare(coordinator.ownerClosed("wave"), "released")
            compare(coordinator.activeOwner, "settings")

            // A close that is not the awaited transition changes nothing.
            verify(coordinator.request("music", alternateOpener))
            compare(coordinator.ownerClosed("wave"), "ignored")
            compare(coordinator.activeOwner, "settings")
            compare(coordinator.pendingTarget, "music")
            verify(coordinator.transitioning)
        }

        // The counterpart guard: a hand-off to *another* owner really does end
        // this surface, so its session mirror must be hidden. The fix above
        // skips the mirror only when the coordinator hands this same owner
        // straight back, and this is what a "skip it whenever something is
        // transitioning" version of that would break.
        function test_aHandOffToAnotherOwnerStillReleasesTheWaveAndHidesTheSession() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            verify(coordinator.request("settings", alternateOpener))

            tryCompare(launcherSurface.host, "phase", "closed", 1200)
            compare(coordinator.activeOwner, "settings")
            compare(coordinator.activeTarget, "settings")
            compare(host.session().visible, false,
                    "the wave's mirror is hidden when another owner takes over")
        }

        // The route the surface just finished with is not an intent the next session
        // open may inherit: the session names no route, so it means the
        // launcher. Order matters here on purpose - control center, then
        // launcher, then control center again, then a plain session open - so
        // the sticky route cannot be right by accident of what ran first.
        function test_aSessionOpenAfterAControlCenterHandOffStillOpensTheLauncher() {
            launcherSurface.requestControlCenter(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "route", "launcher", 2000)
            wait(600)
            compare(launcherSurface.host.phase, "open")

            launcherSurface.requestControlCenter(opener)
            wait(600)
            compare(launcherSurface.host.route, "control-center")
            compare(launcherSurface.host.phase, "open")

            // A real hide: the control center goes away the way a user closes
            // it, which is the only moment the surface is allowed to forget it.
            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 1200)
            compare(host.session().visible, false)

            // A plain session open (bar key, IPC) carries no route: it must land
            // on the launcher rather than replay the control-center intent the
            // surface has already finished with.
            host.session().open()

            tryCompare(launcherSurface.host, "phase", "open", 1600)
            compare(launcherSurface.host.route, "launcher")
            compare(launcherSurface.requestedRoute, "launcher")
            compare(coordinator.activeTarget, "launcher")
            verify(host.page() !== null, "the launcher page must be mounted")
            tryVerify(function() { return host.page().searchField.activeFocus }, 400)
        }

        // Route swap focus: a cross-fade swap never fires `opened()`, so the
        // newly mounted page has to be given its own focus target by the swap
        // completing, or the surface reopens onto a page nobody can type into.
        function test_aRouteSwapHandsFocusToTheNewlyMountedPage() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            tryVerify(function() { return host.page().searchField.activeFocus }, 400)

            verify(launcherSurface.host.openRoute("control-center", null))
            tryCompare(launcherSurface.host, "route", "control-center", 2000)

            tryCompare(launcherSurface.activePage(), "focusDefaultCount", 1, 800)
            compare(launcherSurface.host.phase, "open")
            verify(launcherSurface.page() === null)

            // And back again: the launcher's own search is its focus target.
            verify(launcherSurface.host.openRoute("launcher", null))
            tryCompare(launcherSurface.host, "route", "launcher", 2000)
            tryVerify(function() { return host.page().searchField.activeFocus }, 800)
        }

        function test_launcherIsStillTheDefaultRouteAfterAControlCenterOpen() {
            launcherSurface.requestControlCenter(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            launcherSurface.requestOpen(opener)

            tryCompare(launcherSurface.host, "route", "launcher", 1600)
            verify(launcherSurface.page() !== null)
            verify(launcherSurface.activePage() === launcherSurface.page(),
                   "the active page is the launcher page on the launcher route")
        }

        function test_deprecatedWaveTargetsAreRejectedEverywhere() {
            verify(!coordinator.request("wiki", opener))
            verify(!coordinator.request("news", opener))
            verify(!coordinator.request("beatmap", opener))
            compare(openSpy.count, 0)
            compare(closeSpy.count, 0)
            compare(coordinator.activeTarget, "")
        }

        function test_crossOwnerSwitchFromLauncherToSettingsPreservesOwnership() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            verify(coordinator.request("settings", alternateOpener))
            compare(closeSpy.count, 1)
            compare(closeSpy.signalArguments[0][0], "wave")
            compare(coordinator.pendingTarget, "settings")
            verify(coordinator.transitioning)

            coordinator.ownerClosed("wave")
            compare(openSpy.count, 2)
            compare(openSpy.signalArguments[1][0], "settings")
            compare(openSpy.signalArguments[1][1], "settings")
            compare(coordinator.activeOwner, "settings")

            verify(coordinator.request("settings", alternateOpener))
            compare(closeSpy.count, 2)
            coordinator.ownerClosed("settings")
            compare(coordinator.activeTarget, "")
            compare(coordinator.activeOwner, "")
            verify(alternateOpener.activeFocus)
            compare(coordinator.opener, null)
        }

        function test_musicOwnerStillTogglesIndependently() {
            verify(coordinator.request("music", alternateOpener))
            compare(openSpy.signalArguments[0][0], "music")
            verify(coordinator.request("music", alternateOpener))
            compare(closeSpy.count, 1)
            compare(closeSpy.signalArguments[0][0], "music")
            coordinator.ownerClosed("music")
            compare(coordinator.activeTarget, "")
            verify(alternateOpener.activeFocus)
        }

        function test_pendingTargetCanBeReplacedWhileClosing() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            coordinator.request("settings", opener)
            verify(coordinator.transitioning)
            compare(coordinator.pendingTarget, "settings")

            coordinator.request("music", alternateOpener)
            compare(coordinator.pendingTarget, "music")
            coordinator.ownerClosed("music")
            verify(coordinator.transitioning)
            compare(openSpy.count, 1)

            coordinator.ownerClosed("wave")
            compare(openSpy.count, 2)
            compare(openSpy.signalArguments[1][0], "music")
            compare(openSpy.signalArguments[1][1], "music")
            compare(coordinator.opener, alternateOpener)
        }

        function test_activeOwnerMayCloseItselfAndRestoresOpener() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            coordinator.ownerClosed("wave")
            compare(coordinator.activeTarget, "")
            compare(coordinator.activeOwner, "")
            verify(opener.activeFocus)
        }

        function test_alreadyOpenActivationRefocusesCurrentSearchSession() {
            launcherSurface.requestOpen(opener)
            tryVerify(function() { return host.page().searchField.activeFocus }, 300)

            keyClick(Qt.Key_F)
            tryCompare(host.session(), "query", "f")
            host.forceActiveFocus()
            verify(!host.page().searchField.activeFocus)

            launcherSurface.requestOpen(alternateOpener)

            // Same live instance: no second open, query preserved, search refocused.
            compare(openSpy.count, 1)
            tryCompare(host.session(), "query", "f")
            compare(coordinator.activeTarget, "launcher")
            tryVerify(function() { return host.page().searchField.activeFocus }, 300)
        }

        function test_serviceToggleClosesSurfaceThroughCoordinatorAndRestoresOpener() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            host.session().toggle()

            compare(closeSpy.count, 1)
            compare(closeSpy.signalArguments[0][0], "wave")
            tryCompare(launcherSurface.host, "phase", "closed", 800)
            compare(host.session().visible, false)
            compare(coordinator.activeTarget, "")
            verify(opener.activeFocus)
        }

        function test_escapeClosesThroughTheShellHandOffAndRestoresOpener() {
            launcherSurface.requestOpen(opener)
            tryVerify(function() { return host.page().searchField.activeFocus }, 300)

            keyClick(Qt.Key_Escape)

            tryCompare(launcherSurface.host, "phase", "closed", 800)
            compare(host.session().visible, false)
            compare(coordinator.activeTarget, "")
            verify(opener.activeFocus)
        }

        function test_queuedLauncherAfterSettingsFocusesOnlyOnceActuallyOpen() {
            // Settings owns the coordinator first.
            verify(coordinator.request("settings", alternateOpener))
            compare(openSpy.signalArguments[0][0], "settings")

            // An IPC-style open while settings is active queues behind its close.
            host.session().open()

            compare(coordinator.transitioning, true)
            compare(coordinator.pendingTarget, "launcher")
            // Yield so any premature focus attempt would have run by now;
            // focus must stay out of the not-yet-opened surface.
            //
            // Nothing is built before the launcher's first open - that is what
            // keeps its delegate tree off the startup path, and
            // tst_lazer_wave_host pins it. From the first open on the page is
            // retained across closes, so the guarantee here is that a surface
            // which has not opened takes no focus, not that it has no page.
            wait(60)
            compare(launcherSurface.host.phase, "closed")
            var queuedPage = host.page()
            if (queuedPage)
                verify(!queuedPage.searchField.activeFocus,
                       "a queued launcher must not take focus before it opens")

            coordinator.ownerClosed("settings")

            compare(openSpy.signalArguments[1][0], "wave")
            compare(openSpy.signalArguments[1][1], "launcher")
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            // Search lands only after the wave actually opened.
            tryVerify(function() { return host.page().searchField.activeFocus }, 300)
        }

        function test_reopenDuringCloseRecallsSameInstanceAndRefocuses() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            keyClick(Qt.Key_Escape)
            compare(launcherSurface.host.phase, "closing")
            compare(coordinator.activeTarget, "launcher")

            // Newest open intent arrives while the close animation still runs.
            launcherSurface.requestOpen(alternateOpener)

            tryCompare(launcherSurface.host, "phase", "open", 1600)
            compare(coordinator.activeTarget, "launcher")
            verify(host.session().visible)
            compare(closeSpy.count, 0)
            tryVerify(function() { return host.page().searchField.activeFocus }, 300)

            // The recalled request owns focus restoration from here on.
            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 800)
            tryVerify(function() { return alternateOpener.activeFocus })
        }

        function test_rapidToggleDuringCloseRestoresLauncher() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            keyClick(Qt.Key_Escape)
            compare(launcherSurface.host.phase, "closing")

            // Hide intent mid-close: no animation restart, close keeps running.
            host.session().toggle()
            compare(host.session().visible, false)
            compare(launcherSurface.host.phase, "closing")

            // The newest toggle wins: the very same instance is recalled.
            host.session().toggle()
            compare(host.session().visible, true)

            tryCompare(launcherSurface.host, "phase", "open", 1600)
            verify(host.session().visible)
            tryVerify(function() { return host.page().searchField.activeFocus }, 300)
        }

        function test_launcherRecallCancelsQueuedHandOffToSettings() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            // Start a serialized switch away to settings...
            verify(coordinator.request("settings", alternateOpener))
            verify(coordinator.transitioning)
            compare(coordinator.pendingTarget, "settings")
            compare(launcherSurface.host.phase, "closing")

            // ...then recall the launcher before the close finishes: latest wins.
            launcherSurface.requestOpen(alternateOpener)

            verify(!coordinator.transitioning)
            compare(coordinator.pendingTarget, "")
            compare(coordinator.activeTarget, "launcher")
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            verify(host.session().visible)

            for (var i = 0; i < openSpy.count; i++)
                verify(openSpy.signalArguments[i][0] !== "settings",
                       "superseded settings hand-off must never dispatch")
        }

        function test_staleQueuedLauncherIsCancelledWhenSessionHides() {
            verify(coordinator.request("settings", alternateOpener))

            host.session().open()
            compare(coordinator.pendingTarget, "launcher")

            host.session().close()

            compare(coordinator.pendingTarget, "")
            verify(coordinator.transitioning)
            coordinator.ownerClosed("settings")
            compare(coordinator.activeTarget, "")
            compare(openSpy.count, 1)
        }
    }
}
