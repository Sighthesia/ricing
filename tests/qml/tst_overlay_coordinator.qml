import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Exercise mutual exclusion, pending transitions, final focus restoration,
// and the direct launcher opener path through the generic wave shell.
Item {
    id: host
    width: 1000
    height: 700

    Item { id: opener; objectName: "opener"; focus: true }
    Item { id: alternateOpener; objectName: "alternate-opener" }

    Lazer.OverlayCoordinator {
        id: coordinator
        onOpenRequested: (owner, target) => { if (owner === "wave") launcherHost.openRoute(target, null) }
        onCloseRequested: owner => { if (owner === "wave") launcherHost.close() }
    }

    SignalSpy { id: openSpy; target: coordinator; signalName: "openRequested" }
    SignalSpy { id: closeSpy; target: coordinator; signalName: "closeRequested" }

    // Production-shaped launcher wiring: the standalone session owns visibility,
    // the coordinator serializes ownership, and the generic shell renders it.
    Lazer.WaveSurfaceHost {
        id: launcherHost
        anchors.fill: parent
        title: page() ? page().title : "Launcher"
        description: page() ? page().description : ""
        breadcrumb: "osu! / " + (page() ? page().title : "Launcher")
        sidebarEntries: page() ? page().sidebarEntries : []
        activeSidebarId: page() ? page().activeMode : "apps"
        contentComponent: launcherPageComponent

        onSidebarSelected: id => { if (page()) page().handleModeSelected(id) }
        onClosed: {
            coordinator.ownerClosed("wave")
            if (session() && session().visible)
                session().close()
        }
    }

    Component {
        id: launcherPageComponent
        Lazer.LauncherPage { }
    }

    // Mirror of the top-bar service sync: session visibility drives the surface.
    Connections {
        target: session()
        function onVisibleChanged() { host.syncLauncherSurface() }
    }

    function page() { return launcherHost.contentItem }
    function session() { return launcherHost.contentItem ? launcherHost.contentItem.session : null }

    // Launcher activation goes through the standalone open path and records its
    // opener Item so focus can be restored after close.
    function requestLauncher(openerItem) {
        if (!session())
            return false
        if (session().visible) {
            if (coordinator.activeTarget === "launcher") {
                page().focusSearch()
                return true
            }
            return coordinator.request("launcher", openerItem, true, true)
        }
        pendingOpener = openerItem || null
        session().open()
        return true
    }

    function syncLauncherSurface() {
        if (!session())
            return
        if (session().visible) {
            coordinator.request("launcher", pendingOpener, true, true)
            // Opening grabs surface focus; land typing in the live search session.
            Qt.callLater(function() { if (host.page()) host.page().focusSearch() })
        } else if (coordinator.activeTarget === "launcher") {
            coordinator.request("launcher")
        } else if (coordinator.transitioning && coordinator.pendingTarget === "launcher") {
            coordinator.pendingTarget = ""
        }
        pendingOpener = null
    }

    property var pendingOpener: null

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
            if (launcherHost.phase !== "closed")
                launcherHost.finishClose()
            var s = host.session()
            s._refreshToken++
            s.visible = false
            s.query = ""
            s.results = []
            s.loading = false
            s.error = ""
            s.selectedIndex = -1
            s._adapters = ({})
            host.pendingOpener = null
            openSpy.clear()
            closeSpy.clear()
            opener.forceActiveFocus()
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_launcherActivationOpensThroughWaveOwnerAndFocusesSearch() {
            verify(host.requestLauncher(opener))
            compare(openSpy.count, 1)
            compare(openSpy.signalArguments[0][0], "wave")
            compare(openSpy.signalArguments[0][1], "launcher")
            compare(coordinator.activeTarget, "launcher")
            compare(coordinator.activeOwner, "wave")
            verify(host.session().visible)

            tryCompare(launcherHost, "phase", "open", 1600)
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
            verify(host.requestLauncher(opener))
            tryCompare(launcherHost, "phase", "open", 1600)

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
            verify(host.requestLauncher(opener))
            tryCompare(launcherHost, "phase", "open", 1600)

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
            verify(host.requestLauncher(opener))
            tryCompare(launcherHost, "phase", "open", 1600)

            coordinator.ownerClosed("wave")
            compare(coordinator.activeTarget, "")
            compare(coordinator.activeOwner, "")
            verify(opener.activeFocus)
        }

        function test_alreadyOpenActivationRefocusesCurrentSearchSession() {
            verify(host.requestLauncher(opener))
            tryVerify(function() { return host.page().searchField.activeFocus }, 300)

            keyClick(Qt.Key_F)
            tryCompare(host.session(), "query", "f")
            host.forceActiveFocus()
            verify(!host.page().searchField.activeFocus)

            verify(host.requestLauncher(alternateOpener))

            // Same live instance: no second open, query preserved, search refocused.
            compare(openSpy.count, 1)
            tryCompare(host.session(), "query", "f")
            compare(coordinator.activeTarget, "launcher")
            tryVerify(function() { return host.page().searchField.activeFocus }, 300)
        }

        function test_serviceToggleClosesSurfaceThroughCoordinatorAndRestoresOpener() {
            verify(host.requestLauncher(opener))
            tryCompare(launcherHost, "phase", "open", 1600)

            host.session().toggle()

            compare(closeSpy.count, 1)
            compare(closeSpy.signalArguments[0][0], "wave")
            tryCompare(launcherHost, "phase", "closed", 800)
            compare(host.session().visible, false)
            compare(coordinator.activeTarget, "")
            verify(opener.activeFocus)
        }

        function test_escapeClosesThroughTheShellHandOffAndRestoresOpener() {
            verify(host.requestLauncher(opener))
            tryVerify(function() { return host.page().searchField.activeFocus }, 300)

            keyClick(Qt.Key_Escape)

            tryCompare(launcherHost, "phase", "closed", 800)
            compare(host.session().visible, false)
            compare(coordinator.activeTarget, "")
            verify(opener.activeFocus)
        }
    }
}
