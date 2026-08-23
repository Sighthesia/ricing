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
            openSpy.clear()
            closeSpy.clear()
            opener.forceActiveFocus()
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
            wait(60)
            verify(!host.page().searchField.activeFocus)

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
