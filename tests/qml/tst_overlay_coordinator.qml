import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/OverlayCoordinatorLogic.js" as CoordLogic

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

    // --- Injected service fakes ---
    //
    // The control center takes its services as injected properties, exactly as
    // the production owner edge passes Services.*. These stand in for those
    // singletons: each declares only the properties the page is documented to
    // read, so a binding that reaches for anything else resolves to undefined
    // here exactly as an absent property would in production. They are declared
    // once and never mutated, so they carry no test state and `init()` does not
    // have to reset them.
    QtObject {
        id: fakeNetwork
        property bool wifiConnected: true
        property bool wifiEnabled: true
        // The real NetworkService has no flat activeSsid: it keeps a scan map
        // keyed by SSID. This fake has that shape, so the page's derivation is
        // exercised the way production exercises it.
        property var networks: ({
            "Home": { ssid: "Home", security: "WPA2", signal: 78,
                connected: true, existing: true }
        })
        property bool ethernetConnected: false
        property string activeEthernetConnection: ""
        property bool scanningActive: false
        property bool connecting: false
        property string lastError: ""
        property int refreshCount: 0
        function refreshForOpen() { refreshCount++ }
    }

    QtObject {
        id: fakeBluetooth
        property bool bluetoothAvailable: true
        property bool enabled: true
        property bool blocked: false
        property bool scanningActive: false
        property var devices: [{ name: "Speaker" }]
        property var connectedDevices: []
        property int scanCount: 0
        function startScan() { scanCount++ }
    }

    QtObject {
        id: fakeVolume
        property real sinkVolume: 0.42
        property bool sinkMuted: false
        property var volumeWrites: []
        function setSinkVolume(value) { volumeWrites.push(value) }
        function toggleSinkMute() { sinkMuted = !sinkMuted }
    }

    QtObject {
        id: fakeMedia
        property bool hasPlayer: true
        property string title: "Night Sky"
        property string artist: "Artist"
        property bool playing: true
        property string playbackState: "playing"
        property bool canGoPrevious: true
        property bool canTogglePlayback: true
        property bool canGoNext: true
        property var actions: []
        function previous() { actions.push("previous") }
        function playPause() { actions.push("playPause") }
        function next() { actions.push("next") }
    }

    QtObject {
        id: fakeBattery
        property bool available: true
        property bool ready: true
        property int percentage: 77
        property bool charging: false
        property bool pluggedIn: true
        property string iconText: "AC"
    }

    // The notification service hands out a ListModel-shaped head plus a bounded
    // history walk, so the fake answers the same `get(i)`/`count` pair the real
    // one does rather than a plain array.
    QtObject {
        id: fakeHistory
        property int count: 0
        function get(index) { return null }
    }

    QtObject {
        id: fakeNotifications
        property int unreadCount: 2
        property var latestNotification: function() {
            return { notifId: "n1", appName: "Shell", summary: "Ready", read: false }
        }
        readonly property var historyList: fakeHistory
    }

    QtObject {
        id: fakeWeather
        property bool available: true
        property bool loading: false
        property real temperature: 21.4
        property string condition: "Clear"
        property string location: "Home"
        property double updatedAt: 1767225600000
        property bool isStale: false
        property string lastError: ""
    }

    Lazer.OverlayCoordinator {
        id: coordinator
        onOpenRequested: (owner, target) => { if (owner === "wave") launcherSurface.host.openRoute(target, null) }
        onCloseRequested: owner => { if (owner === "wave") launcherSurface.host.close() }
    }

    SignalSpy { id: openSpy; target: coordinator; signalName: "openRequested" }
    SignalSpy { id: closeSpy; target: coordinator; signalName: "closeRequested" }

    // Production-shaped launcher wiring with the embedded Quickshell-free
    // session; every open intent funnels through requestOpen / syncVisibility.
    // The services are injected here - the same owner edge the production bar
    // uses - so the route page and its sub-pages are built exactly as the shell
    // builds them, without this suite importing a Quickshell singleton.
    Lazer.LauncherSurface {
        id: launcherSurface
        anchors.fill: parent
        coordinator: coordinator
        networkService: fakeNetwork
        bluetoothService: fakeBluetooth
        volumeService: fakeVolume
        mediaService: fakeMedia
        batteryService: fakeBattery
        notificationService: fakeNotifications
        weatherService: fakeWeather
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
            // The page survives every close, so a control-center view left up by
            // the previous test would still be showing - and it is the page's own
            // flag, not fixture state, that owns it.
            if (launcherSurface.launcherPage)
                launcherSurface.launcherPage.controlCenterActive = false
            openSpy.clear()
            closeSpy.clear()
            opener.forceActiveFocus()
            s._pooledMode = ""
            s.displayPool = []
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        // Open the wave surface on the launcher and switch its content area to the
        // control center, through the rail's own dispatch.
        //
        // Returns the LAUNCHER PAGE, not the view: the page is what the tests below
        // assert against (the view flag, the hidden editor, the query), and a
        // helper that returned the view would make every one of them read a
        // property the view does not have - as undefined rather than as a failure
        // message, which is how this went wrong once already.
        //
        // It lives INSIDE the TestCase, not beside it: it uses tryCompare /
        // tryVerify, which are TestCase methods, and a helper declared at the Item
        // level has no access to them - which is a runtime "is not defined" on
        // every test that called it.
        function openControlCenterView(surfaceOpener) {
            launcherSurface.requestOpen(surfaceOpener === undefined ? opener : surfaceOpener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            var launcherPage = launcherSurface.page()
            verify(launcherPage !== null, "the launcher page must be mounted")
            launcherPage.handleSidebarSelected(launcherPage.controlCenterEntryId)
            tryVerify(function() { return launcherPage.controlCenterItem !== null }, 2000)
            // The focus hand-off is deferred one turn (a Loader builds its item
            // asynchronously, so focusing in the same turn as the flag flip would
            // target nothing). Waiting for it here is part of "the view is open",
            // and without it every caller that asserts on focus is racing the
            // timer - which reads as a flaky failure rather than a real one.
            tryVerify(function() {
                return launcherPage.controlCenterItem.activeFocus === true
            }, 800, "the view must own the keyboard once it is open")
            return launcherPage
        }

        // The view itself, once the launcher page is up.
        function controlCenterView() { return launcherSurface.page().controlCenterItem }

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

        function test_theControlCenterIsAViewInsideTheLauncherRoute() {
            launcherSurface.requestOpen(opener)

            // One owner, one route, one surface. The control center is reached
            // through the launcher page's rail, so the coordinator is not involved
            // at all after the first open - and nothing about this surface's
            // target changes when the view does.
            compare(openSpy.count, 1)
            compare(openSpy.signalArguments[0][0], "wave")
            compare(openSpy.signalArguments[0][1], "launcher")
            compare(coordinator.activeOwner, "wave")
            compare(coordinator.activeTarget, "launcher")

            tryCompare(launcherSurface.host, "phase", "open", 1600)
            var launcherPage = launcherSurface.page()
            verify(launcherPage !== null)
            openSpy.clear()
            launcherPage.handleSidebarSelected(launcherPage.controlCenterEntryId)
            tryVerify(function() { return launcherPage.controlCenterVisible }, 2000)

            compare(openSpy.count, 0,
                    "a view switch must not dispatch anything to the coordinator")
            compare(launcherSurface.host.route, "launcher",
                    "the view must not become a route")
            compare(coordinator.activeTarget, "launcher")
            verify(launcherSurface.page() === launcherPage,
                   "the launcher accessor still answers, because the route is still the launcher")

            // The view has its own focus target and the launcher's hidden editor
            // does not hold the keyboard.
            tryVerify(function() {
                return launcherPage.controlCenterItem.activeFocus === true
            }, 800, "the view must own the keyboard while it is up")
            verify(!launcherPage.searchField.activeFocus,
                   "the hidden search editor must not keep the caret")

            // Opener restoration is the launcher's existing contract, shared: a
            // view switch never touched the opener record, so the close still
            // lands back where this open began.
            keyClick(Qt.Key_Escape)
            tryVerify(function() { return launcherPage.controlCenterActive === false }, 1000)
            compare(coordinator.opener, opener,
                    "a view switch must not discard the opener record")
            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 1200)
            compare(coordinator.activeTarget, "")
            verify(opener.activeFocus)
        }

        // The coordinator has no route and no owner method for the control center.
        // Both are asserted against the registry and against this real surface,
        // because a registry entry naming a method that does not exist is a drift
        // bug between two lists that both look complete.
        function test_theCoordinatorRefusesTheControlCenterAsATarget() {
            verify(!coordinator.request("control-center", opener),
                "the control center is not a coordinator target")
            compare(openSpy.count, 0)
            compare(coordinator.activeTarget, "")
            compare(coordinator.activeOwner, "")

            compare(CoordLogic.normalizeTarget("control-center"), "")
            compare(CoordLogic.ownerFor("control-center"), "")
            compare(CoordLogic.entryMethodFor("control-center"), "",
                "no wave owner method can open a view inside a page")
        }

        // The launcher page must not claim a search field the user cannot see, and it
        // must not claim one it does not own: with the control-center view up, the
        // editor is hidden and the view holds the keyboard.
        function test_theLauncherSearchFieldNeverHoldsFocusWhileTheViewIsUp() {
            var launcherPage = openControlCenterView(opener)
            tryVerify(function() { return launcherPage.controlCenterVisible }, 500)

            verify(!launcherPage.searchField.activeFocus,
                   "the launcher search field must not hold focus behind the view")
            tryVerify(function() { return launcherPage.controlCenterItem.activeFocus }, 600,
                "the view takes the keyboard while it is on screen")
        }

        // Re-activating an ALREADY OPEN surface is a refocus, not a fresh open. So it
        // must not change what is on screen: a keybind pressed while the control
        // center is up would otherwise swap the user out of the controls they are
        // looking at, and the second press of the same key would then land on a
        // different view entirely.
        function test_aReactivationRefocusesTheViewInsteadOfReplacingIt() {
            var launcherPage = openControlCenterView(opener)

            launcherSurface.requestOpen(opener)

            compare(launcherSurface.host.route, "launcher")
            compare(coordinator.activeTarget, "launcher")
            verify(launcherSurface.page() === launcherPage,
                   "the same page instance is still mounted")
            verify(launcherPage.controlCenterActive,
                   "a refocus must not leave the view the user is looking at")
            tryVerify(function() {
                return launcherPage.controlCenterItem.activeFocus === true
            }, 600,
                "and the view keeps the keyboard: focusSearch refuses while it is up")
            verify(!launcherPage.searchField.activeFocus)
            compare(launcherSurface.requestedRoute, "launcher")
        }

        // The owner edge hands the route page the singleton instances, and the
        // page forwards the same objects to its same-surface sub-pages. Identity,
        // not shape: two service objects that happen to agree on every property
        // read today still disagree on the next scan, and the overview would
        // then describe a network the detail page is not looking at.
        function test_theControlCenterViewAndItsSubPagesShareOneServiceInstance() {
            openControlCenterView(opener)
            var page = controlCenterView()

            compare(page.networkService, fakeNetwork)
            compare(page.bluetoothService, fakeBluetooth)
            compare(page.volumeService, fakeVolume)
            compare(page.mediaService, fakeMedia)
            compare(page.batteryService, fakeBattery)
            compare(page.notificationService, fakeNotifications)
            compare(page.weatherService, fakeWeather)

            // The detail sub-page reads the same instance, not a second one.
            compare(page.networkCardData.action, "detail",
                    "the network card must be a detail hand-off for this to mean anything")
            page.openNetworkDetails()
            tryVerify(function() { return page.detailPageItem !== null }, 1000)
            compare(page.detailPageItem.networkService, fakeNetwork)
        }

        // Focus ownership across a live switch: the launcher really had the
        // caret, the view really takes it, and the caret does not survive into an
        // editor the user cannot see.
        function test_theControlCenterViewTakesFocusFromALiveLauncherSearch() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            var launcherPage = launcherSurface.page()
            tryVerify(function() { return launcherPage.searchField.activeFocus }, 600)

            launcherPage.handleSidebarSelected(launcherPage.controlCenterEntryId)
            wait(500)

            verify(!launcherPage.searchField.activeFocus,
                   "a hidden launcher editor must not keep the caret")
            // The view's own target is the view itself, so Tab can move from
            // there into the first ready card.
            tryVerify(function() { return launcherPage.controlCenterItem.activeFocus }, 600)
        }

        // A view switch is the SAME open continuing, so it must not go near the
        // coordinator: no dispatch, no close, no transition, and the surface must
        // settle exactly where it was. This is the strongest form of the "one open
        // continuing" rule - the old route hand-off spent a close and a re-open to
        // achieve what is now a property write.
        function test_aViewSwitchLeavesTheSurfaceAndTheCoordinatorUntouched() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            tryVerify(function() { return host.page() !== null }, 500)
            var launcherPage = launcherSurface.page()

            openSpy.clear()
            closeSpy.clear()
            launcherPage.handleSidebarSelected(launcherPage.controlCenterEntryId)

            // Wait for settled state rather than sampling mid-flight: the failure
            // mode is a close arriving after the switch, so an immediate assertion
            // would read a perfectly healthy surface.
            wait(600)

            compare(launcherSurface.host.phase, "open",
                    "the switch must settle open, not closed")
            compare(launcherSurface.host.route, "launcher")
            compare(coordinator.activeTarget, "launcher")
            compare(coordinator.activeOwner, "wave")
            compare(coordinator.pendingTarget, "")
            verify(!coordinator.transitioning)
            compare(closeSpy.count, 0, "a view switch must not close the surface")
            compare(openSpy.count, 0, "a view switch must not re-open the surface")
            compare(host.session().visible, true)
            verify(launcherSurface.page() === launcherPage,
                   "the launcher accessor still answers throughout")
            tryVerify(function() {
                return launcherPage.controlCenterItem.activeFocus === true
            }, 600, "the view owns the keyboard, one turn after the switch")
        }

        // A close is not always a hide, so the coordinator says which one it settled.
        // The wave owner needs the answer: a hand-off closes the surface and
        // immediately reopens it, and a caller that mirrors every close into its
        // own visible state would shut the surface it just asked for.
        function test_ownerClosedReportsWhetherTheOwnerComesBack() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            // The "reopened" answer is now UNREACHABLE, and that is a consequence
            // of this change rather than an accident of the test. It meant "this
            // owner's close was really a hand-off to another of its own targets",
            // and the wave had two targets. With one, a same-owner request is a
            // refocus (ensureOpen) or a plain toggle, never a queue - and the other
            // owners each serve a single target too. So this asserts the
            // unreachability, which is what would fail loudly if a second wave
            // route ever came back and nobody re-covered the branch.
            verify(coordinator.request("launcher", opener, true, true))
            compare(coordinator.transitioning, false,
                "a same-owner, same-target request cannot queue a hand-off")
            compare(coordinator.pendingTarget, "")

            // What is still reachable, and what the wave owner actually depends on:
            // a hand-off to another owner releases this one...
            verify(coordinator.request("settings", alternateOpener))
            compare(coordinator.ownerClosed("wave"), "released")
            compare(coordinator.activeOwner, "settings")

            // ...and a close that is not the awaited transition changes nothing.
            verify(coordinator.request("music", alternateOpener))
            compare(coordinator.ownerClosed("wave"), "ignored")
            compare(coordinator.activeOwner, "settings")
            compare(coordinator.pendingTarget, "music")
            verify(coordinator.transitioning)

            // Settle the queued hand-off with the owner that is actually closing,
            // which hands the surface to music...
            compare(coordinator.ownerClosed("settings"), "released")
            compare(coordinator.activeOwner, "music")

            // ...and music's own self-close: no queued target, so it releases and
            // restores its opener. Asked of the right owner this time - a close
            // reported by anyone else is "ignored", which is the previous leg.
            verify(coordinator.request("music", alternateOpener))
            compare(coordinator.ownerClosed("music"), "released")
            compare(coordinator.activeTarget, "")
            compare(coordinator.activeOwner, "")
            verify(alternateOpener.activeFocus)
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
        // launcher. Order matters here on purpose - view up, view down, up again,
        // then a real hide, then a plain session open - so the sticky route
        // cannot be right by accident of what ran first.
        function test_aSessionOpenAfterAViewRoundTripStillOpensTheLauncher() {
            var launcherPage = openControlCenterView(opener)
            tryVerify(function() { return launcherPage.controlCenterVisible }, 500)

            launcherPage.closeControlCenter()
            tryVerify(function() { return launcherPage.controlCenterVisible === false }, 500)
            wait(200)
            compare(launcherSurface.host.phase, "open")

            launcherPage.handleSidebarSelected(launcherPage.controlCenterEntryId)
            wait(400)
            compare(launcherSurface.host.route, "launcher")
            compare(launcherSurface.host.phase, "open")

            // A real hide. With nothing mounted, the next press leaves the view and
            // the one after that is the hide.
            keyClick(Qt.Key_Escape)
            tryVerify(function() { return launcherPage.controlCenterActive === false }, 1000)
            compare(launcherSurface.host.phase, "open",
                    "leaving the view is not a hide")
            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 1200)
            compare(host.session().visible, false)

            // A plain session open (bar key, IPC) carries no route: it must land
            // on the launcher rather than replay anything the surface has already
            // finished with.
            host.session().open()

            tryCompare(launcherSurface.host, "phase", "open", 1600)
            compare(launcherSurface.host.route, "launcher")
            compare(launcherSurface.requestedRoute, "launcher")
            compare(coordinator.activeTarget, "launcher")
            verify(host.page() !== null, "the launcher page must be mounted")
            // ...and it shows the launcher, not the view the previous open ended on.
            verify(!(host.page() && host.page().controlCenterActive),
                    "a fresh open must not inherit a view from the previous one")
            tryVerify(function() { return host.page().searchField.activeFocus }, 400)
        }

        // Focus across the view switch, in both directions. The launcher editor is
        // hidden while the view is up, so the surface would otherwise be open with
        // nowhere to type - and coming back, the editor would have to reclaim the
        // keyboard from a view that is no longer on screen.
        function test_theViewSwitchHandsFocusBothWays() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            tryVerify(function() { return host.page().searchField.activeFocus }, 400)

            var launcherPage = launcherSurface.page()
            launcherPage.handleSidebarSelected(launcherPage.controlCenterEntryId)
            tryVerify(function() { return launcherPage.controlCenterItem !== null }, 2000)

            tryVerify(function() {
                return launcherPage.controlCenterItem.activeFocus === true
            }, 800, "the view must own the keyboard while it is on screen")
            verify(!launcherPage.searchField.activeFocus,
                   "and the hidden editor must not keep it")
            compare(launcherSurface.host.phase, "open")
            verify(launcherSurface.page() === launcherPage,
                   "the launcher accessor still answers: the route is unchanged")

            // And back again: the launcher's own search is its focus target.
            launcherPage.closeControlCenter()
            tryVerify(function() { return launcherPage.controlCenterActive === false }, 1000)
            tryVerify(function() { return host.page().searchField.activeFocus }, 800)
            verify(!(launcherPage.controlCenterItem
                        && launcherPage.controlCenterItem.activeFocus),
                   "the hidden view must not keep the caret")
        }

        function test_theLauncherRouteStaysTheDefaultAfterAViewRoundTrip() {
            openControlCenterView(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            keyClick(Qt.Key_Escape)
            tryVerify(function() { return launcherSurface.page().controlCenterActive === false }, 1000)
            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 1200)

            launcherSurface.requestOpen(opener)

            tryCompare(launcherSurface.host, "route", "launcher", 1600)
            verify(launcherSurface.page() !== null)
            verify(launcherSurface.activePage() === launcherSurface.page(),
                   "the active page is the launcher page on the launcher route")
            compare(launcherSurface.requestedRoute, "launcher")
        }

        // Back precedence, end to end through the real owner stack.
//
// The view is a step of the OPEN the user is already in, so back has exactly one
// meaning while it is up: leave the view. The four-step order - detail sub-page,
// the view itself, then the launcher's query, then the surface close - belongs to
// the page, and this walks it as a real key-press sequence rather than calling the
// pieces, because the ORDER is the contract and each press belongs to a different
// owner.
function test_escapeWalksBackFromTheViewToThePreviousLauncherViewThenCloses() {
            // Open the surface and TYPE first, while the launcher editor still owns
            // the keyboard. With the view up the editor is hidden and a keystroke
            // goes to the control center's own controls instead - correct, and it
            // would leave the query empty, so the last leg below would have nothing
            // real to clear and the whole sequence would pass for the wrong reason.
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            var launcherPage = launcherSurface.page()
            tryVerify(function() { return launcherPage.searchField.activeFocus }, 600)
            keyClick(Qt.Key_H)
            tryCompare(host.session(), "query", "h")

            launcherPage.handleSidebarSelected(launcherPage.controlCenterEntryId)
            tryVerify(function() { return launcherPage.controlCenterVisible }, 2000)

            // Leg 1: a detail sub-page consumes the press, and the view stays up.
            var view = controlCenterView()
            tryVerify(function() { return view.activeFocus === true }, 600,
                "the view must own the keyboard before the walk starts")
            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage === "network-detail" }, 1000)
            keyClick(Qt.Key_Escape)
            tryVerify(function() { return view.activeSubPage === "" }, 1000)
            verify(launcherPage.controlCenterActive,
                "popping a detail page must not leave the view")
            compare(host.session().query, "h", "and it must not touch the query")

            // Leg 2: the view itself. Same surface, still open, query intact.
            keyClick(Qt.Key_Escape)
            tryVerify(function() { return launcherPage.controlCenterActive === false }, 1000)
            compare(launcherSurface.host.phase, "open",
                "leaving the view is not a hide")
            compare(launcherSurface.host.route, "launcher")
            compare(host.session().query, "h",
                "leaving the view must show the query the user left behind")

            // Leg 3: typed text clears, back to the bare prefix for the mode.
            keyClick(Qt.Key_Escape)
            tryCompare(host.session(), "query", "")
            compare(launcherSurface.host.phase, "open")

            // Leg 4: nothing left, so the press closes the surface and restores
            // the opener this open began from.
            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 1200)
            compare(coordinator.activeTarget, "")
            tryVerify(function() { return opener.activeFocus })
        }

        // The opener record must outlive a view switch.
//
// The record is what the final close restores focus FROM. A switch that named no
        // opener would leave it standing anyway - but a switch that went through
        // the coordinator would have reset it, and the surface would then close
        // onto whatever focus the hidden editor happened to leave.
        function test_aViewSwitchKeepsTheOpenerForTheFinalClose() {
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            var launcherPage = launcherSurface.page()
            launcherPage.handleSidebarSelected(launcherPage.controlCenterEntryId)
            tryVerify(function() { return launcherPage.controlCenterVisible }, 2000)

            compare(coordinator.opener, opener,
                    "a view switch must not replace the opener record")
            compare(launcherSurface.host.route, "launcher")

            keyClick(Qt.Key_Escape)
            tryVerify(function() { return launcherPage.controlCenterActive === false }, 1000)
            compare(launcherSurface.host.phase, "open")
            compare(coordinator.opener, opener,
                    "leaving the view must not discard the opener record")

            // Focus is on the editor that came back, so the assertion below cannot
            // be satisfied by an opener that never lost focus in the first place.
            tryVerify(function() { return launcherPage.searchField.activeFocus }, 600)
            verify(!opener.activeFocus,
                    "the opener must not hold focus while the surface is open")

            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 1200)
            compare(coordinator.activeTarget, "")
            compare(coordinator.opener, null,
                    "a restored opener is consumed, never left behind for the next open")
            // verify, not tryVerify: the close has already settled, so a missed
            // focus restore is a wrong value rather than a slow one - and a
            // tryVerify here would swallow the reason it failed.
            verify(opener.activeFocus,
                    "the opener this open was made with must regain focus")
        }

        // The other half of the same rule: a switch must not INVENT an opener. An
        // IPC or keyboard open has none to restore, so the record stays empty and
        // the close restores nothing, rather than focusing a control nobody
        // pressed.
        function test_aViewSwitchInventsNoOpenerForAnOpenThatHadNone() {
            // The production IPC shape: no opener at all. LauncherService.open()
            // is what a keybind and `afloat-ipc` reach, and neither names one.
            host.session().open()
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            compare(coordinator.opener, null,
                    "an open that named no opener must record none")

            var launcherPage = launcherSurface.page()
            launcherPage.handleSidebarSelected(launcherPage.controlCenterEntryId)
            tryVerify(function() { return launcherPage.controlCenterVisible }, 2000)
            compare(coordinator.opener, null,
                    "a view switch must not record an opener")

            keyClick(Qt.Key_Escape)
            tryVerify(function() { return launcherPage.controlCenterActive === false }, 1000)
            compare(launcherSurface.host.phase, "open")

            // ...and the close restores nothing, rather than focusing a control
            // nobody pressed.
            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 1200)
            compare(coordinator.activeTarget, "")
            verify(!opener.activeFocus && !alternateOpener.activeFocus,
                    "no open named an opener, so no opener may be restored")
        }

// The view is not session state, so it must not survive the close that ended
        // the open showing it. The page itself is retained, so without this a
        // reopen would land on the control center - which no open asked for.
function test_theViewDoesNotSurviveAClose() {
            var launcherPage = openControlCenterView(opener)
            tryVerify(function() { return launcherPage.controlCenterVisible }, 500)

            // Open a DETAIL sub-page before leaving. The view is retained, so a
            // sub-page left mounted would be what the next open lands on: the user
            // would reopen into the network list with no visible way back to the
            // overview except that list's own back press.
            var view = controlCenterView()
            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage === "network-detail" }, 1000)

            // Two presses: the first pops the sub-page, the second leaves the view,
            // the third closes. All three are the real sequence.
            keyClick(Qt.Key_Escape)
            tryVerify(function() { return view.activeSubPage === "" }, 1000)
            keyClick(Qt.Key_Escape)
            tryVerify(function() { return launcherPage.controlCenterActive === false }, 1000)
            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 1200)

            // The page is still there, and so is the built view - only the flag died.
            verify(host.page() !== null, "the launcher page is retained across a close")
            compare(launcherSurface.requestedRoute, "launcher")
            verify(launcherSurface.page().controlCenterBuilt,
                    "the view stays constructed; it is only off screen")

            // ...and it was taken back to its OVERVIEW on the way out, not left
            // holding whatever sub-page was mounted when the surface closed.
            verify(launcherSurface.page().controlCenterItem.activeSubPage === "",
                    "leaving the view must pop any detail sub-page it was holding")

            // ...so a fresh open starts on the launcher.
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            verify(!host.page().controlCenterActive,
                    "a fresh open must not inherit a view from the previous one")
            tryVerify(function() { return host.page().searchField.activeFocus }, 600)
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

        // The screen-scoped entry refuses a wave target whose entry method this
        // surface does not implement, because the alternative - handing it to the
        // coordinator - opens the host with no session mirror, no requestedRoute
        // and no opener. So the target registry and this surface must agree, and
        // the only way to know that for the real object is to ask it.
        function test_everyWaveTargetResolvesToAMethodOnThisSurface() {
            var waveTargets = CoordLogic.waveTargets
            verify(waveTargets.length > 0, "the wave target registry must not be empty")
            for (var index = 0; index < waveTargets.length; index++) {
                var target = waveTargets[index]
                var plan = CoordLogic.dispatchFor(target, launcherSurface)
                compare(plan.route, "wave",
                    target + " must dispatch to this surface, which has no '" + plan.method + "'")
                compare(typeof launcherSurface[plan.method], "function")
            }

            // The control center is no longer a target, so the screen scope must
            // not be holding a method for it. This is the drift assertion in the
            // direction that matters: a registry that no longer names it AND a
            // surface that still implements it is a live method nothing can reach.
            verify(launcherSurface.requestControlCenter === undefined,
                "the surface must not keep a control-center entry method")
            verify(launcherSurface.requestControlCenterFromLauncher === undefined)
            verify(launcherSurface.returnToDefaultRoute === undefined)

            // The other owners are untouched by the wave registry: neither of their
            // targets may reach a method on this surface.
            compare(CoordLogic.dispatchFor("settings", launcherSurface).route, "coordinator")
            compare(CoordLogic.dispatchFor("music", launcherSurface).route, "coordinator")
        }

        // --- Acceptance: the control center coexists with settings and music ---
        //
        // One walk through all three owners, because the parts that only fail are
        // the seams BETWEEN them: a surface that took the view and did not give
        // the ownership back strands the next open, and one that gave it back to
        // the LAUNCHER's default instead of to itself looks fine until the user
        // notices they landed somewhere they did not ask for.
        //
        // Acceptance 8 ("the settings center remains the destination for
        // long-lived configuration") is the settings leg: a settings request from
        // the control center must be dispatched to the settings OWNER, never into
        // the wave surface as a control-center category.

        function test_theControlCenterCoexistsWithSettingsAndMusicAndComesBackOnItsOwnRoute() {
            var launcherPage = openControlCenterView(opener)
            tryVerify(function() { return launcherPage.controlCenterVisible }, 500)
            compare(coordinator.activeOwner, "wave")

            // --- Leg 1: settings takes the surface from the wave ---
            verify(coordinator.request("settings", alternateOpener))
            compare(coordinator.pendingTarget, "settings")
            verify(coordinator.transitioning)
            tryCompare(launcherSurface.host, "phase", "closed", 1600)
            compare(coordinator.activeOwner, "settings",
                "settings keeps its own owner; the control center is not a settings category")
            compare(coordinator.activeTarget, "settings")
            compare(host.session().visible, false,
                "the wave's mirror is hidden once another owner owns the surface")
            compare(launcherSurface.requestedRoute, "launcher",
                "a genuine close drops the sticky route")

            // No wave open was dispatched for the settings target: the two
            // owners stay serialized instead of racing for one surface. The
            // dispatch that DOES happen is ("settings", "settings") - the
            // settings owner serving its own target.
            for (var i = 0; i < openSpy.count; i++) {
                var dispatchedOwner = openSpy.signalArguments[i][0]
                var dispatchedTarget = openSpy.signalArguments[i][1]
                verify(!(dispatchedTarget === "settings" && dispatchedOwner !== "settings"),
                    "a settings target was dispatched to the wrong owner: " + dispatchedOwner)
            }

            // --- Leg 2: music takes over from settings ---
            verify(coordinator.request("music", alternateOpener))
            compare(coordinator.pendingTarget, "music")
            compare(coordinator.ownerClosed("settings"), "released")
            compare(coordinator.activeOwner, "music")
            compare(coordinator.activeTarget, "music")
            compare(openSpy.signalArguments[openSpy.count - 1][0], "music")
            compare(launcherSurface.host.phase, "closed",
                "the wave owner must stay released while another owner owns the surface")

            // Music closes and releases itself on its own terms, restoring its own
            // opener - the control center must not be caught in that release.
            coordinator.ownerClosed("music")
            compare(coordinator.activeOwner, "")
            compare(coordinator.activeTarget, "")
            verify(alternateOpener.activeFocus)

            // --- Leg 3: back to the wave, with its view ---
            launcherSurface.requestOpen(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            compare(coordinator.activeOwner, "wave")
            compare(coordinator.activeTarget, "launcher")
            compare(launcherSurface.host.route, "launcher",
                "returning must land on the launcher route")
            compare(host.session().visible, true,
                "the session mirror comes back with the wave owner")
            var backPage = launcherSurface.page()
            verify(backPage !== null)

            // The rail opens the view again through the same dispatch the user
            // used before, and the view is the retained instance - the close did
            // not tear down a screen of cards to hand it back.
            backPage.handleSidebarSelected(backPage.controlCenterEntryId)
            tryVerify(function() { return backPage.controlCenterVisible }, 2000)
            verify(backPage.controlCenterItem === launcherPage.controlCenterItem,
                "the view must be the same retained instance, not a rebuild")
            tryVerify(function() { return backPage.controlCenterItem.activeFocus }, 800,
                "the view takes the keyboard on the way back, not the hidden editor")
            verify(!backPage.searchField.activeFocus)

            for (var j = 0; j < openSpy.count; j++) {
                var owner = openSpy.signalArguments[j][0]
                verify(owner === "wave" || owner === "music" || owner === "settings",
                    "no unknown owner was ever dispatched: " + owner)
            }
        }

        // The other direction of the same seam: the coordinator toggling the wave
        // owner while its control-center view is up, and coming back to the
        // retained page afterwards. And a genuine user close must leave nothing
        // behind - the next plain open is the launcher, not a replay of the view
        // the previous open ended on.
        function test_theViewAndTheLauncherShareOneOwnerInBothDirections() {
            var launcherPage = openControlCenterView(opener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)

            // The launcher route re-requested while the view is up. With one
            // wave route there is no sibling to hand off to, so this is the
            // owner's own toggle: the surface closes. What matters here is that it
            // closes THROUGH the coordinator and releases cleanly, rather than
            // leaving the owner holding a surface it has already shut.
            verify(coordinator.request("launcher", alternateOpener))
            verify(coordinator.transitioning)
            compare(coordinator.pendingTarget, "")
            compare(coordinator.ownerClosed("wave"), "released")
            tryCompare(launcherSurface.host, "phase", "closed", 1600)
            compare(coordinator.activeOwner, "",
                "a closed wave surface must leave the owner released")
            compare(coordinator.activeTarget, "")

            // Reopening restores the retained page AND the retained view, rather
            // than building a second screen of cards.
            launcherSurface.requestOpen(alternateOpener)
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            compare(coordinator.activeOwner, "wave")
            verify(launcherSurface.page() !== null)
            verify(launcherSurface.activePage() === launcherSurface.page())
            verify(launcherPage.controlCenterBuilt,
                "the page and its view are retained, not rebuilt")
            verify(launcherSurface.page() === launcherPage,
                "the same page instance came back")

            // A genuine user close must leave nothing behind: the next plain open
            // is the launcher, not a replay of the control center.
            keyClick(Qt.Key_Escape)
            tryCompare(launcherSurface.host, "phase", "closed", 1200)
            compare(coordinator.activeTarget, "")

            host.session().open()
            tryCompare(launcherSurface.host, "phase", "open", 1600)
            compare(launcherSurface.host.route, "launcher",
                "a session open carries no route, so it must not inherit the view")
            verify(!launcherSurface.page().controlCenterActive,
                "and it must show the launcher, not the control center")
        }
    }
}
