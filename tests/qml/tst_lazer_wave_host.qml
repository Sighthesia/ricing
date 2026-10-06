import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/WaveSurfaceLogic.js" as Logic

// The wave host builds its route page on the first open and keeps it.
//
// A launcher open costs a whole screen of row delegates, and tearing them down
// when the surface closes meant every open rebuilt the chrome, the rows, their
// shaped text and their icons from nothing - the hitch the user feels on the
// second, third and fourth open. Nothing is built at shell startup either way:
// the page is cold until the first open asks for it.
//
// The host is the shared owner for every route, so it selects the page by route
// name instead of holding one fixed component, and route-local back comes from
// whichever page is mounted. The wave registers exactly ONE route in production
// now - the launcher page, which owns the control center as a view inside its
// content area - so the cross-fade tests below drive a second route through the
// module's own extension seam. That is what the seam is for, and keeping the
// swap covered is what stops the machinery from rotting untested behind a
// one-route registry.
//
// Each test owns its own host, because retention is a one-way latch: a shared
// instance would let the first open decide what the next test sees.
Item {
    id: testRoot
    width: 900
    height: 700

    // The swap's completion signal. A cross-fade never emits `opened()`, so
    // this is the only thing that tells a caller the new page is mounted and
    // can be handed its own focus target.
    SignalSpy { id: swapSpy; signalName: "routeSwapped" }

    // A second route name, used only by the cross-fade tests. Registered through
    // the module's own `registerRoute` extension seam rather than by editing the
    // production list, which is exactly what that seam exists to avoid.
    readonly property string secondRoute: "inspector"

    function createHost() {
        var host = hostComponent.createObject(testRoot)
        host.width = testRoot.width
        host.height = testRoot.height
        swapSpy.target = host
        swapSpy.clear()
        return host
    }

    // Route pages distinguishable by name, so a route swap is provable rather
    // than inferred: a fixed component would make both routes look identical.
    Component {
        id: launcherRoutePage
        Item { objectName: "launcherPage" }
    }
    Component {
        id: inspectorRoutePage
        Item { objectName: "inspectorPage" }
    }
    // A page that owns a route-local back step, like a same-surface detail page.
    Component {
        id: backAwareRoutePage
        Item {
            id: backPage
            objectName: "backAwarePage"
            property bool canGoBack: false
            property int backPresses: 0
            function handleBack() {
                backPage.backPresses++
                backPage.canGoBack = false
                return true
            }
        }
    }
    // A page that advertises a back step but cannot take the press: the flag
    // without the handler that makes it actionable.
    Component {
        id: backlessRoutePage
        Item {
            id: backlessPage
            objectName: "backlessPage"
            property bool canGoBack: false
            property int backPresses: 0
        }
    }
    // A page whose handler refuses every press: it publishes the contract, then
    // declines to act on it. The control center's overview answers like this.
    Component {
        id: decliningRoutePage
        Item {
            id: decliningPage
            objectName: "decliningPage"
            property bool canGoBack: false
            property int backPresses: 0
            function handleBack() {
                decliningPage.backPresses++
                return false
            }
        }
    }

    // The REAL launcher page, mounted through the real host, so the control
    // center can be reached the way production reaches it: as a view inside the
    // page's own content area.
    //
    // A stub would prove the host honours `canGoBack`, which is already covered
    // above; what it cannot prove is that the real control center and its own
    // sub-pages stay on ONE host route and ONE surface. LauncherPage is a plain
    // Item with no Quickshell import, so it loads here.
    Component {
        id: realLauncherPage
        Lazer.LauncherPage {}
    }

    Component {
        id: hostComponent
        Lazer.WaveSurfaceHost {
            contentComponent: Component {
                Item { objectName: "routePage" }
            }
            routeComponents: ({
                "launcher": launcherRoutePage,
                "inspector": inspectorRoutePage
            })
        }
    }

    TestCase {
        name: "LazerWaveHost"
        when: windowShown

        function initTestCase() {
            // The cross-fade tests need a second route name, and the registry is
            // the module's shared state - so it is registered once here through
            // the extension seam rather than edited into the production list.
            Logic.registerRoute(testRoot.secondRoute)
        }

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = true
            wait(30)
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_nothingIsBuiltBeforeTheFirstOpen() {
            // The shell must not pay for a launcher nobody has opened.
            var host = testRoot.createHost()
            verify(host.contentItem === null,
                   "a route page must not exist before the first open")
            verify(host.routeRetained === false)
            host.destroy()
        }

        function test_idlePrewarmBuildsThePageWithoutOpeningTheSurface() {
            var host = testRoot.createHost()
            host.prewarmRoute()
            tryVerify(function() { return host.contentItem !== null }, 2000)
            compare(host.phase, "closed")
            verify(host.visible === false)
            verify(host.interactive === false)
            verify(host.routeRetained)
            host.destroy()
        }

        function test_thePageSurvivesTheClose() {
            var host = testRoot.createHost()
            verify(host.openRoute("launcher"), "the route must be accepted")
            tryVerify(function() { return host.contentItem !== null }, 2000)
            var page = host.contentItem

            host.close()
            tryVerify(function() { return host.phase === "closed" }, 3000)

            // Closed, invisible, and still the same object: the next open finds
            // its rows already built instead of building them again.
            verify(host.contentItem === page,
                   "the route page must survive a close")
            verify(host.visible === false,
                   "a closed surface stays invisible so it takes no input")
            host.destroy()
        }

        function test_aReopenReusesTheSamePage() {
            var host = testRoot.createHost()
            verify(host.openRoute("launcher"), "the route must be accepted")
            tryVerify(function() { return host.contentItem !== null }, 2000)
            var page = host.contentItem

            host.close()
            tryVerify(function() { return host.phase === "closed" }, 3000)
            verify(host.openRoute("launcher"), "the route must reopen")
            tryVerify(function() { return host.contentItem !== null }, 2000)

            verify(host.contentItem === page,
                   "a reopen must reuse the page it already built")
            host.destroy()
        }

        function test_inputIsOnlyLiveWhileOpen() {
            var host = testRoot.createHost()
            verify(host.interactive === false,
                   "a closed surface must not claim input")
            verify(host.openRoute("launcher"))
            tryVerify(function() { return host.interactive === true }, 2000)
            host.close()
            tryVerify(function() { return host.interactive === false }, 3000)
            host.destroy()
        }

        // The production registry holds the launcher and nothing else. Asserted
        // here as well as in the logic test because this is the file that mounts
        // the real page: a control-center entry surviving in either place would
        // be a second surface for content that is now a view.
        function test_theHostServesTheLauncherRouteOnly() {
            verify(hostRouteComponent("launcher"),
                   "the launcher must be registered as the wave's route")
            verify(hostRouteComponent("control-center") === undefined,
                   "the control center must not be registered as a route")

            var host = testRoot.createHost()
            // The name is refused, and a refused route leaves the surface closed
            // rather than half-opening it.
            verify(!host.openRoute("control-center"))
            compare(host.phase, "closed")
            verify(host.contentItem === null,
                   "a refused route must not build a page")
            host.destroy()
        }

        function hostRouteComponent(route) {
            var components = ({ "launcher": launcherRoutePage,
                "inspector": inspectorRoutePage })
            return components[route]
        }

        function test_aRouteSwapReplacesThePageAndKeepsTheSurfaceOpen() {
            var host = testRoot.createHost()
            verify(host.openRoute("launcher"))
            tryCompare(host, "phase", "open", 2000)
            compare(host.contentItem.objectName, "launcherPage")

            verify(host.openRoute(testRoot.secondRoute))

            // The swap crosses over inside the same owner: no close, no second
            // window, one Loader that swapped its component.
            tryCompare(host, "route", testRoot.secondRoute, 2000)
            compare(host.phase, "open")
            compare(host.contentItem.objectName, "inspectorPage")
            host.destroy()
        }

        // The swap completion is announced once, naming the route that is actually
        // mounted. It is observed on the cross-fade sequence rather than on its
        // last step: a nested animation's own `onFinished` is never emitted, so
        // a handler there would look right and silently never run.
        function test_aRouteSwapAnnouncesItsCompletionOnce() {
            var host = testRoot.createHost()
            verify(host.openRoute("launcher"))
            tryCompare(host, "phase", "open", 2000)

            verify(host.openRoute(testRoot.secondRoute))

            // Not at the route flip: the announcement is the end of the fade.
            compare(swapSpy.count, 0, "the swap is still crossing over")
            tryCompare(swapSpy, "count", 1, 2000)
            compare(swapSpy.signalArguments[0][0], testRoot.secondRoute)
            compare(host.loadedRoute, testRoot.secondRoute)
            wait(200)
            compare(swapSpy.count, 1, "one swap, one announcement")
            host.destroy()
        }

        // A swap cut short by a close never completes, so it must not announce a
        // route the surface never finished showing. Deterministic rather than
        // timed: no animation tick can elapse inside one JS turn, so the close
        // lands while the cross-fade is still queued.
        function test_aSwapInterruptedByACloseAnnouncesNothing() {
            var host = testRoot.createHost()
            verify(host.openRoute("launcher"))
            tryCompare(host, "phase", "open", 2000)

            verify(host.openRoute(testRoot.secondRoute))
            host.close()

            tryCompare(host, "phase", "closed", 3000)
            compare(swapSpy.count, 0, "an abandoned swap is not a completion")
            compare(host.route, "")
            host.destroy()
        }

        function test_aReopenOfTheSameRouteKeepsTheSamePage() {
            var host = testRoot.createHost()
            verify(host.openRoute(testRoot.secondRoute))
            tryVerify(function() { return host.contentItem !== null }, 2000)
            var page = host.contentItem
            host.close()
            tryCompare(host, "phase", "closed", 3000)
            verify(host.openRoute(testRoot.secondRoute))
            tryVerify(function() { return host.interactive === true }, 2000)
            verify(host.contentItem === page,
                   "the same route must not rebuild its page")
            host.destroy()
        }

        // The route page, not the host or a caller, decides whether a back press
        // belongs to the page: that is what lets a same-surface detail page pop
        // instead of the whole wave closing.
        function test_escapeIsDelegatedToTheMountedPageWhenItCanGoBack() {
            var host = testRoot.createHost()
            host.routeComponents = ({ "launcher": backAwareRoutePage })
            verify(host.openRoute("launcher"))
            tryCompare(host, "phase", "open", 2000)
            var page = host.contentItem
            page.canGoBack = true
            tryVerify(function() { return host.canGoBack === true }, 500)

            verify(host.handleEscape())

            compare(page.backPresses, 1, "the page must consume the back press")
            compare(host.phase, "open", "a page-local back must not close the surface")
            tryVerify(function() { return host.canGoBack === false }, 500)

            // With nothing left to go back to, the next press closes.
            verify(host.handleEscape())
            compare(host.phase, "closing")
            host.destroy()
        }

        function test_aRouteWithoutTheContractClosesOnEscape() {
            var host = testRoot.createHost()
            verify(host.openRoute(testRoot.secondRoute))
            tryVerify(function() { return host.contentItem !== null }, 2000)
            compare(host.canGoBack, false,
                    "a page that publishes no back state offers none")
            verify(host.handleEscape())
            compare(host.phase, "closing")
            host.destroy()
        }

        // Page back is a contract, not a flag. A page that says it can go back
        // while publishing no handleBack() would take every Escape press for
        // itself and do nothing with it, so the surface could never be closed
        // again - a one-way door behind a normal-looking close button.
        function test_aPageAdvertisingBackWithNoHandlerCannotWedgeTheSurface() {
            var host = testRoot.createHost()
            host.routeComponents = ({ "launcher": backlessRoutePage })
            verify(host.openRoute("launcher"))
            tryCompare(host, "phase", "open", 2000)
            var page = host.contentItem
            page.canGoBack = true
            tryVerify(function() { return page.canGoBack === true }, 500)

            compare(host.canGoBack, false,
                    "back needs a callable handler, not just a published flag")
            verify(host.handleEscape())
            compare(host.phase, "closing",
                    "Escape must still close a page that cannot handle back")
            tryCompare(host, "phase", "closed", 2000)
            host.destroy()
        }

        // The mirror image: the contract is complete, the page just declines
        // the press. Reporting back as still available would send the next
        // Escape to the same refusal, so the decline falls through to the
        // close instead of wedging the surface one press at a time.
        function test_aPageThatDeclinesThePressFallsThroughToClose() {
            var host = testRoot.createHost()
            host.routeComponents = ({ "launcher": decliningRoutePage })
            verify(host.openRoute("launcher"))
            tryCompare(host, "phase", "open", 2000)
            var page = host.contentItem
            page.canGoBack = true
            tryVerify(function() { return host.canGoBack === true }, 500)

            verify(host.handleEscape())
            compare(page.backPresses, 1, "the page must be asked first")
            compare(host.phase, "closing",
                    "a declined back press closes rather than repeating forever")
            tryCompare(host, "phase", "closed", 2000)
            host.destroy()
        }

        // A manual back flag on a host with no contract page is still the
        // host's own answer: clearing it keeps the surface open for the next
        // press. The handler requirement must not eat this pre-existing path.
        function test_manualBackFlagStillClearsWithoutClosing() {
            var host = testRoot.createHost()
            verify(host.openRoute("launcher"))
            tryCompare(host, "phase", "open", 2000)
            host.pageCanGoBack = true
            tryVerify(function() { return host.canGoBack === true }, 500)

            verify(host.handleEscape())
            verify(!host.pageCanGoBack, "the manual claim is cleared")
            compare(host.phase, "open", "clearing a manual claim is not a close")
            host.destroy()
        }

        // --- The control center as a view, through the real host ---
        //
        // The network and Bluetooth details are SUB-PAGES of the control-center
        // VIEW, which is itself inside the launcher page. So the host never sees
        // a swap: the route stays "launcher", the host's own Loader keeps the
        // same page object, and the page swaps what its content area shows
        // inside itself. Asserting the route is unchanged is what proves there is
        // no second surface.

        // Fakes for the two cards whose details are sub-pages. They have to exist
        // because the overview gates its detail request on the module's own
        // readiness answer: with no service at all the network card is
        // `unavailable`, its action is `none`, and openNetworkDetails() correctly
        // does nothing - which would make every test below pass for the wrong
        // reason.
        //
        // Declared with ONLY the properties the overview reads, so a binding that
        // reaches for anything else resolves to undefined here exactly as it does
        // in production.
        QtObject {
            id: readyNetwork
            property bool wifiConnected: true
            property bool wifiEnabled: true
            // Two networks, because the one that needs a password is never the
            // connected one: a secured row is only reachable by tapping it.
            property var networks: ({
                "Home": { ssid: "Home", security: "WPA2", signal: 78,
                    connected: true, existing: true },
                "Neighbour 5G": { ssid: "Neighbour 5G", security: "WPA2",
                    signal: 55, connected: false, existing: false }
            })
            property bool ethernetConnected: false
            property string activeEthernetConnection: ""
            property bool scanningActive: false
            property bool connecting: false
            property string connectingTo: ""
            property string lastError: ""

            function setWifiEnabled(value) { wifiEnabled = value }
            function refreshForOpen() {}
            function requestScan(rescan, clearError) {}
            function connect(ssid, password, isHidden, securityKey) {}
            function disconnect(ssid) {}
            function needsPasswordFor(ssid) { return ssid === "Neighbour 5G" }
            function isCredentialFailure(message) { return false }
        }

        QtObject {
            id: readyBluetooth
            property bool bluetoothAvailable: true
            property bool enabled: true
            property bool blocked: false
            property bool scanningActive: false
            property var devices: null
            property var connectedDevices: []
            property bool onAdapter: true

            property var _devices: ({ values: [] })
            property var devices2: _devices
            function setBluetoothEnabled(value) { enabled = value }
            function startScan() {}
            function deviceKey(device) { return device == null ? "" : device.address }
            function getDeviceIcon(device) { return "bluetooth" }
            function getSignalPercent(device) { return null }
            function isDeviceBusy(device) { return false }
            function canPair(device) { return false }
            function canConnect(device) { return false }
            function canDisconnect(device) { return false }
        }

        // Mount the real launcher page on the real host and open its control
        // center view. The services are assigned through the PAGE, which is where
        // they are forwarded from in production - so a page that dropped the
        // forwarding would leave the cards unready here rather than only in a
        // unit test of the page alone.
        function openControlCenterView() {
            var host = testRoot.createHost()
            host.routeComponents = ({ "launcher": realLauncherPage })
            verify(host.openRoute("launcher"))
            tryCompare(host, "phase", "open", 2000)
            tryVerify(function() { return host.contentItem !== null }, 2000)
            var page = host.contentItem
            page.networkService = readyNetwork
            page.bluetoothService = readyBluetooth
            // Through the rail's own dispatch, not a direct flag write: the entry
            // point is what the shared sidebar calls, so using it is what makes
            // this an integration claim rather than a unit claim in a trench coat.
            page.handleSidebarSelected(page.controlCenterEntryId)
            tryVerify(function() { return page.controlCenterVisible }, 2000,
                "the rail's control-center entry must open the view")
            var view = page.controlCenterItem
            tryVerify(function() { return view.controlCardCount === 4 }, 2000)
            compare(view.networkCardData.action, "detail",
                "the fixture must present a card that can request its detail page")
            return host
        }

        function test_theControlCenterIsAViewInsideTheLauncherRoute() {
            var host = openControlCenterView()
            var page = host.contentItem

            compare(host.route, "launcher",
                "the control center is not a sibling route")
            compare(host.loadedRoute, "launcher")
            verify(host.contentItem === page,
                "opening the view must not replace the host's page")
            verify(host.routeRetained === true)
            compare(host.phase, "open",
                "opening the view must not close or reopen the surface")
            host.destroy()
        }

        function test_aCardOpensItsDetailPageInsideTheSameRouteAndSurface() {
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem

            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage === "network-detail" }, 1000)

            // One route, one page, one surface: the host's Loader never swapped
            // anything and the mounted page is still the same object.
            compare(host.route, "launcher",
                "a detail page is not a sibling route")
            compare(host.loadedRoute, "launcher")
            verify(host.contentItem === page,
                "the detail page must mount inside the existing route page")
            verify(host.routeRetained === true)
            compare(host.phase, "open",
                "opening a detail page must not close or reopen the surface")
            host.destroy()
        }

        // While a sub-page is up, the PAGE claims back for itself - the host
        // reads the page, not the view. `canGoBack` and a callable `handleBack()`
        // are both halves of that contract, and the host's own computed answer is
        // what a real Escape press consults.
        function test_pageBackIsOfferedWhileTheDetailPageIsActive() {
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem

            compare(host.canGoBack, true,
                "the view itself is offered back, so the view can be dismissed")
            compare(view.canGoBack, false,
                "the overview itself has nothing to pop")

            view.openBluetoothDetails()
            tryVerify(function() { return view.activeSubPage === "bluetooth-detail" }, 1000)
            compare(view.canGoBack, true,
                "a mounted detail page must claim back inside the view, not the page")

            // Popping the detail page returns the claim to the view, which then
            // offers the press again for the step it DOES own: leaving the view.
            view.handleBack()
            tryVerify(function() { return view.activeSubPage === "" }, 1000)
            compare(view.canGoBack, false,
                "the overview declines, so its owner is offered the press")
            compare(host.canGoBack, true,
                "the page still owns the next step, so the host must keep asking it")
            host.destroy()
        }

        // The headline behaviour, end to end through the real host: Escape inside
        // a detail page returns to the control-center overview instead of closing
        // the Wave surface.
        function test_escapeReturnsFromTheDetailPageToTheControlCenterView() {
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem
            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage === "network-detail" }, 1000)

            verify(host.handleEscape(), "the press must be consumed")
            compare(host.phase, "open",
                "a detail-page back must not close the wave surface")
            compare(host.route, "launcher")

            // With the sub-page gone, the next press leaves the view - still
            // without closing the surface.
            verify(host.handleEscape())
            tryVerify(function() { return page.controlCenterActive === false }, 1000,
                "the second press must leave the control-center view")
            compare(host.phase, "open")
            compare(host.route, "launcher")
            host.destroy()
        }

        // Back and forth on the same surface: no window, no coordinator, no route
        // swap, and the same page object throughout.
        function test_bothDetailPagesRoundTripInsideTheSameRoute() {
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem

            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage === "network-detail" }, 1000)
            verify(view.handleBack())
            tryVerify(function() { return view.activeSubPage === "" }, 500)

            view.openBluetoothDetails()
            tryVerify(function() { return view.activeSubPage === "bluetooth-detail" }, 1000)
            verify(host.handleEscape())
            tryVerify(function() { return view.activeSubPage === "" }, 1000)
            compare(host.phase, "open")
            verify(host.contentItem === page)
            host.destroy()
        }

        // Escape inside the password prompt is the PROMPT's back, not the page's.
        //
        // A prompt is the one sub-page element that takes focus of its own, so it
        // is the one place where a key press has two possible owners: the field,
        // and the host further up the chain whose Escape handling pops the whole
        // detail page. A user dismissing a half-typed secret has to land back on
        // the network list, not be thrown out of Network with the half-typed
        // secret - so the field claims the press, and this pins what that claim
        // buys.
        //
        // Asserted with a real key press at a really focused field: calling
        // cancelPassword() directly would pass even if the press carried on to
        // the host, because the contract is where the press ENDS, not what the
        // field does with it.
        function test_escapeInsideThePasswordPromptCancelsItAndKeepsTheDetailPage() {
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem
            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage === "network-detail" }, 1000)
            var detail = view.detailPageItem
            verify(detail !== null, "the network detail sub-page must be mounted")

            detail.activateNetwork("Neighbour 5G")
            tryVerify(function() { return detail.passwordSsid === "Neighbour 5G" }, 1000)
            detail.password = "hunter2"
            tryVerify(function() { return detail.passwordItem.activeFocus === true }, 1000,
                "an open prompt must own the caret, or the press never reaches it")

            keyPress(Qt.Key_Escape)
            keyRelease(Qt.Key_Escape)

            tryCompare(detail, "passwordSsid", "", 1000)
            compare(detail.password, "", "a dismissed secret must not linger in the page")
            compare(detail.passwordItem.activeFocus, false,
                "the dismissed field must hand focus back")
            compare(view.activeSubPage, "network-detail",
                "the prompt's back press must not pop the whole detail page")
            compare(host.route, "launcher")
            compare(host.phase, "open",
                "the wave surface must stay open: this press was never its own")
            verify(host.contentItem === page, "no route swap may have happened")
            host.destroy()
        }

        // ...and once the prompt is gone the page's own back press is unchanged:
        // the next Escape returns to the control-center overview, the one after
        // that leaves the view. Consuming the field's Escape must not have
        // consumed the view's.
        function test_pageBackIsUnchangedOnceThePasswordPromptIsDismissed() {
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem
            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage === "network-detail" }, 1000)
            var detail = view.detailPageItem

            detail.activateNetwork("Neighbour 5G")
            tryVerify(function() { return detail.passwordSsid === "Neighbour 5G" }, 1000)
            // Wait for the prompt's own focus hand-off before pressing, so this
            // test presses Escape where the user does: at the field.
            tryVerify(function() { return detail.passwordItem.activeFocus === true }, 1000)
            keyPress(Qt.Key_Escape)
            keyRelease(Qt.Key_Escape)
            tryCompare(detail, "passwordSsid", "", 1000)
            compare(detail.passwordItem.activeFocus, false,
                "the dismissed field is not where the caret is any more")
            // Focus is handed to the page through its own entry point, the way the
            // route asks for it - so the next press is a PAGE-level one, and it is
            // pressed for real rather than faked through the host.
            detail.focusDefault()
            tryVerify(function() { return detail.activeFocus === true }, 1000)
            keyPress(Qt.Key_Escape)
            keyRelease(Qt.Key_Escape)
            tryCompare(view, "activeSubPage", "", 1000)

            compare(host.phase, "open",
                "the detail page's own back still spares the surface")
            compare(host.route, "launcher")

            verify(host.handleEscape())
            tryVerify(function() { return page.controlCenterActive === false }, 1000,
                "the overview's back leaves the view, it does not close the surface")
            compare(host.phase, "open")
            host.destroy()
        }

        // The brief's acceptance case, with the press delivered as a KEY rather
        // than as a call.
        //
        // `handleEscape()` is the host's own function, so calling it proves only
        // that it works when called. A real press has to travel through the host's
        // `Keys.onEscapePressed` with the mounted detail page in the focus chain -
        // which is exactly where a page-local claim would intercept it, and
        // exactly what the password-prompt test above depends on being narrow.
        //
        // The claim asserted after the press is the host's COMPUTED `canGoBack`,
        // not its manual `pageCanGoBack` flag: a contract page owns that answer
        // outright, so the manual flag is never written and would be vacuously
        // false. `canGoBack` is what `handleEscape()` actually consults.
        function test_detailEscapeReturnsBeforeSurfaceClose() {
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem

            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage === "network-detail" }, 1000)
            verify(host.canGoBack, "the mounted sub-page must be offered back first")
            // Focus somewhere INSIDE the host's own subtree, not on the host itself:
            // the mounted detail page took it, which is exactly the chain a real
            // press travels. Asserting `host.activeFocus` would be wrong now that a
            // real launcher page (and a real sub-page inside it) owns the caret -
            // and it would be a vacuous pass on any page that held no focus at all.
            tryVerify(function() {
                var owner = Window.window ? Window.window.activeFocusItem : null
                for (var p = owner; p; p = p.parent)
                    if (p === host)
                        return true
                return false
            }, 1000, "the press must reach the surface the way a user's would")

            keyClick(Qt.Key_Escape)

            tryVerify(function() { return view.activeSubPage === "" }, 1000)
            compare(host.route, "launcher",
                "a detail back returns to the control-center overview")
            verify(host.visible, "the surface must still be on screen")
            compare(host.phase, "open")
            verify(host.contentItem === page, "the overview is restored, not rebuilt")

            // The press that returned must not have cost the surface its own
            // close: the next one leaves the view, and only a third would go on
            // to the query and then the surface.
            keyClick(Qt.Key_Escape)
            tryVerify(function() { return page.controlCenterActive === false }, 1000)
            compare(host.phase, "open")
            compare(page.canGoBack, false,
                "with no view up and no query typed, the page offers no back")
            host.destroy()
        }

        // "Entering a detail page retains the overview snapshot for immediate back
        // navigation" - asserted as IDENTITY plus geometry, not as "the overview
        // still shows the same values".
        //
        // The weaker reading is also true of a page that tore itself down and
        // rebuilt from the same services one turn later, which is the cost the
        // retention exists to avoid. So this pins that the card and the calendar
        // are the SAME objects before and after, that the overview keeps its
        // geometry while it is hidden, and that only the sub-page is torn down.
        function test_theOverviewIsRestoredNotRebuiltOnReturnFromADetailPage() {
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem
            tryVerify(function() { return view.networkCard.width > 0 }, 2000)
            var networkCardBefore = view.networkCard
            var calendarBefore = view.calendarItem

            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage === "network-detail" }, 1000)
            verify(view.detailPageItem !== null, "the sub-page must be mounted")

            // `visible` rather than `active`: the overview YIELDS without being
            // rebuilt, so it keeps a real box even while it is not on screen.
            tryVerify(function() { return view.overviewItem.visible === false }, 500)
            verify(view.networkCard === networkCardBefore,
                "the retained overview must not be rebuilt while hidden")
            verify(view.calendarItem === calendarBefore)
            verify(view.networkCard.width > 0,
                "a hidden-but-retained overview keeps its geometry")

            verify(view.handleBack())

            tryVerify(function() { return view.overviewItem.visible === true }, 500)
            verify(view.networkCard === networkCardBefore,
                "back restores the retained overview; it must not build a new one")
            verify(view.calendarItem === calendarBefore)
            tryVerify(function() { return view.detailPageItem === null }, 1000,
                "the sub-page is torn down; the overview is not")
            compare(host.route, "launcher")
            compare(host.phase, "open")
            host.destroy()
        }

        // The view itself is retained across the whole route: leaving it for a
        // launcher view and coming back restores the same instance, so the second
        // visit costs no rebuild.
        function test_theViewSurvivesALeaveAndReturnInsideTheSameRoute() {
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem
            var cardBefore = view.networkCard

            verify(page.closeControlCenter())
            tryVerify(function() { return page.controlCenterVisible === false }, 1000)
            verify(host.contentItem === page, "leaving the view keeps the route page")
            compare(host.phase, "open", "and it does not close the surface")

            page.openControlCenter()
            tryVerify(function() { return page.controlCenterVisible }, 1000)
            verify(page.controlCenterItem === view,
                "returning must restore the retained view, not build a second one")
            verify(view.networkCard === cardBefore)
            compare(host.route, "launcher")
            host.destroy()
        }

        // The sub-page hand-off through the REAL host, with motion on. Same
        // surface, same route, same Loader: the host's own `route` never changes
        // and no second surface or page appears, which is what distinguishes a
        // sub-page from a route swap.
        function test_theSubPageHandoffNeverTouchesTheHostRoute() {
            Lazer.MotionTokens.reducedMotionOverride = false
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem
            var mounted = host.contentItem
            tryVerify(function() { return view.controlCardCount === 4 }, 2000)

            view.openNetworkDetails()
            tryVerify(function() { return view.subPageReveal > 0 && view.subPageReveal <= 1 },
                1000, "the hand-off must pass through a reveal")

            // Mid-flight the host still knows nothing about it: the route page it
            // holds is the same object, and the surface is fully open throughout.
            // The overview's own state is asserted here too, and not only its reveal
            // scalar: a reveal that animates while `visible` flips hard would satisfy
            // the check above and still be the cut this replaces.
            verify(host.contentItem === mounted,
                "a sub-page must not replace the host's route page")
            compare(host.route, "launcher")
            compare(host.phase, "open",
                "a sub-page must not close or reopen the surface")
            verify(host.routeRetained === true)
            verify(view.overviewItem.visible,
                "the outgoing overview must still be painted while the page arrives")
            verify(view.overviewItem.opacity < 1,
                "and it must be fading, not already gone (opacity="
                    + view.overviewItem.opacity + ")")

            tryVerify(function() { return view.subPageReveal === 1 }, 2000)
            verify(host.contentItem === mounted)
            compare(host.route, "launcher")
            compare(host.phase, "open")
            host.destroy()
        }

        // Reduced motion through the real host: the hand-off lands immediately,
        // so the surface is never caught between two states. Asserted on the
        // settled state in the same turn as the request, which an animation could
        // not produce.
        function test_reducedMotionLandsTheSubPageHandoffImmediately() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var host = openControlCenterView()
            var page = host.contentItem
            var view = page.controlCenterItem
            tryVerify(function() { return view.controlCardCount === 4 }, 2000)

            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage === "network-detail" }, 1000)
            compare(view.subPageReveal, 1)
            verify(view.detailPageItem !== null)
            verify(!view.overviewItem.visible)
            verify(host.contentItem !== null)
            compare(host.phase, "open")
            host.destroy()
        }
    }
}