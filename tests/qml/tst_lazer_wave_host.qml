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
// Each test owns its own host, because retention is a one-way latch: a shared
// instance would let the first open decide what the next test sees.
Item {
    id: testRoot
    width: 900
    height: 700

    function createHost() {
        var host = hostComponent.createObject(testRoot)
        host.width = testRoot.width
        host.height = testRoot.height
        return host
    }

    Component {
        id: hostComponent
        Lazer.WaveSurfaceHost {
            contentComponent: Component {
                Item { objectName: "routePage" }
            }
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
    }
}
