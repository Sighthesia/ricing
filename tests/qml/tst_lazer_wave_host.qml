import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// The wave host builds its route page on the first open and keeps it.
//
// A launcher open costs a whole screen of row delegates, and tearing them down
// when the surface closes meant every open rebuilt the chrome, the rows, their
// shaped text and their icons from nothing - the hitch the user feels on the
// second, third and fourth open. Nothing is built at shell startup either way:
// the page is cold until the first open asks for it.
//
// The host is also the shared owner for every sibling route, so it selects the
// page by route name instead of holding one fixed component: the launcher and
// the control center each get their own registered component behind a single
// retained Loader, and route-local back comes from whichever page is mounted.
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
        id: controlCenterRoutePage
        Item { objectName: "controlCenterPage" }
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
    // A page whose handler refuses every press, like the control center's
    // overview: it publishes the contract, then declines to act on it.
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

    Component {
        id: hostComponent
        Lazer.WaveSurfaceHost {
            contentComponent: Component {
                Item { objectName: "routePage" }
            }
            routeComponents: ({
                "launcher": launcherRoutePage,
                "control-center": controlCenterRoutePage
            })
        }
    }

    TestCase {
        name: "LazerWaveHost"
        when: windowShown

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

        function test_controlCenterRouteIsAcceptedAndRetained() {
            var host = testRoot.createHost()
            verify(host.openRoute("control-center"))
            tryVerify(function() { return host.contentItem !== null }, 2000)
            compare(host.route, "control-center")
            compare(host.contentItem.objectName, "controlCenterPage",
                    "the route must select its own registered component")
            var page = host.contentItem
            host.close()
            tryCompare(host, "phase", "closed", 3000)
            verify(host.contentItem === page)
            verify(host.loadedRoute === "control-center",
                   "the retained page's route survives the close")
            host.destroy()
        }

        function test_aRouteSwapReplacesThePageAndKeepsTheSurfaceOpen() {
            var host = testRoot.createHost()
            verify(host.openRoute("launcher"))
            tryCompare(host, "phase", "open", 2000)
            compare(host.contentItem.objectName, "launcherPage")

            verify(host.openRoute("control-center"))

            // The swap crosses over inside the same owner: no close, no second
            // window, one Loader that swapped its component.
            tryCompare(host, "route", "control-center", 2000)
            compare(host.phase, "open")
            compare(host.contentItem.objectName, "controlCenterPage")
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

            verify(host.openRoute("control-center"))

            // Not at the route flip: the announcement is the end of the fade.
            compare(swapSpy.count, 0, "the swap is still crossing over")
            tryCompare(swapSpy, "count", 1, 2000)
            compare(swapSpy.signalArguments[0][0], "control-center")
            compare(host.loadedRoute, "control-center")
            wait(200)
            compare(swapSpy.count, 1, "one swap, one announcement")
            host.destroy()
        }

        // A swap cut short by a close never completes, so it must not announce
        // a route the surface never finished showing. Deterministic rather than
        // timed: no animation tick can elapse inside one JS turn, so the close
        // lands while the cross-fade is still queued.
        function test_aSwapInterruptedByACloseAnnouncesNothing() {
            var host = testRoot.createHost()
            verify(host.openRoute("launcher"))
            tryCompare(host, "phase", "open", 2000)

            verify(host.openRoute("control-center"))
            host.close()

            tryCompare(host, "phase", "closed", 3000)
            compare(swapSpy.count, 0, "an abandoned swap is not a completion")
            compare(host.route, "")
            host.destroy()
        }

        function test_aReopenOfTheSameRouteKeepsTheSamePage() {
            var host = testRoot.createHost()
            verify(host.openRoute("control-center"))
            tryVerify(function() { return host.contentItem !== null }, 2000)
            var page = host.contentItem
            host.close()
            tryCompare(host, "phase", "closed", 3000)
            verify(host.openRoute("control-center"))
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
            verify(host.openRoute("control-center"))
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
    }
}
