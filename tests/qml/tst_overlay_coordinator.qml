import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Exercise mutual exclusion, pending transitions, and final focus restoration.
Item {
    id: host
    width: 320
    height: 200

    Item { id: opener; objectName: "opener"; focus: true }
    Item { id: alternateOpener; objectName: "alternate-opener" }
    Lazer.OverlayCoordinator { id: coordinator }

    SignalSpy { id: openSpy; target: coordinator; signalName: "openRequested" }
    SignalSpy { id: closeSpy; target: coordinator; signalName: "closeRequested" }
    SignalSpy { id: routeSpy; target: coordinator; signalName: "routeRequested" }

    TestCase {
        name: "OverlayCoordinator"
        when: windowShown

        function init() {
            coordinator.activeTarget = ""
            coordinator.activeOwner = ""
            coordinator.pendingTarget = ""
            coordinator.transitioning = false
            coordinator.opener = null
            coordinator._closingOwner = ""
            openSpy.clear()
            closeSpy.clear()
            routeSpy.clear()
            host.forceActiveFocus()
        }

        function test_openRouteSwitchAndFinalClose() {
            verify(coordinator.request("wiki", opener))
            compare(openSpy.count, 1)
            compare(openSpy.signalArguments[0][0], "wave")
            compare(openSpy.signalArguments[0][1], "wiki")

            verify(coordinator.request("news", opener))
            compare(routeSpy.count, 1)
            compare(routeSpy.signalArguments[0][0], "news")
            compare(coordinator.activeTarget, "news")

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
            verify(!coordinator.transitioning)

            verify(coordinator.request("settings", alternateOpener))
            compare(closeSpy.count, 2)
            compare(closeSpy.signalArguments[1][0], "settings")
            coordinator.ownerClosed("settings")
            compare(coordinator.activeTarget, "")
            compare(coordinator.activeOwner, "")
            verify(alternateOpener.activeFocus)
            compare(coordinator.opener, null)
        }

        function test_invalidAndStaleCompletionDoNothing() {
            verify(!coordinator.request("remote", opener))
            compare(openSpy.count, 0)
            coordinator.ownerClosed("music")
            compare(coordinator.activeTarget, "")
        }

        function test_pendingTargetCanBeReplacedWhileClosing() {
            coordinator.request("wiki", opener)
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

        function test_activeOwnerMayCloseItself() {
            coordinator.request("wiki", opener)
            coordinator.ownerClosed("wave")
            compare(coordinator.activeTarget, "")
            compare(coordinator.activeOwner, "")
            verify(opener.activeFocus)
        }
    }
}
