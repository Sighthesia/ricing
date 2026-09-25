import QtQuick
import QtTest
import "../../modules/lock"

Item {
    id: harness
    width: 520
    height: 420

    QtObject {
        id: fakeService
        property bool running: false
        property string errorText: ""
        property string resultText: ""
        property var calls: []
        property bool unavailable: false
        signal actionFinished(string actionId, bool success, string message)

        function isAvailable(actionId) {
            return !unavailable && ["lock", "logout", "suspend", "reboot", "shutdown"].indexOf(actionId) >= 0
        }

        function execute(actionId) {
            if (running || !isAvailable(actionId))
                return false
            calls = calls.concat([actionId])
            return true
        }
    }

    LockSessionMenu {
        id: menu
        x: 24
        y: 24
        reducedMotion: true
        sessionService: fakeService
    }

    TestCase {
        name: "LockSessionMenu"
        when: windowShown

        function init() {
            menu.open = false
            menu.pendingAction = ""
            menu.errorText = ""
            menu.statusText = ""
            fakeService.calls = []
            fakeService.running = false
            fakeService.unavailable = false
        }

        function test_startsClosedWithFiveStaticRows() {
            compare(menu.open, false)
            compare(menu.menuItemCount, 5)
        }

        function test_triggerOpensAndEscapeCloses() {
            menu.toggleOpen()
            compare(menu.open, true)
            compare(menu.revealProgress, 1)
            verify(menu.handleEscape())
            compare(menu.open, false)
            compare(menu.revealProgress, 0)
        }

        function test_lockExecutesWithoutConfirmation() {
            menu.open = true
            menu.activateAction("lock")
            compare(fakeService.calls, ["lock"])
            compare(menu.pendingAction, "")
            compare(menu.open, false)
        }

        function test_systemActionRequiresSecondActivation() {
            menu.open = true
            menu.activateAction("shutdown")
            compare(fakeService.calls, [])
            compare(menu.pendingAction, "shutdown")
            menu.activateAction("shutdown")
            compare(fakeService.calls, ["shutdown"])
            compare(menu.pendingAction, "")
        }

        function test_unavailableActionDoesNotExecute() {
            menu.open = true
            fakeService.unavailable = true
            menu.activateAction("reboot")
            compare(fakeService.calls, [])
            compare(menu.pendingAction, "")
        }

        function test_escapeCancelsConfirmationBeforeClosing() {
            menu.open = true
            menu.activateAction("logout")
            verify(menu.handleEscape())
            compare(menu.pendingAction, "")
            compare(menu.open, true)
            verify(menu.handleEscape())
            compare(menu.open, false)
        }
    }
}
