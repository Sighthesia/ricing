import QtQuick
import QtTest
import "../../modules/lock/LockSessionMenuLogic.js" as Logic

TestCase {
    name: "LockSessionMenuLogic"

    function test_menuHasFiveStableActions() {
        var ids = Logic.actions().map(function(action) { return action.id })
        compare(ids, ["lock", "logout", "suspend", "reboot", "shutdown"])
    }

    function test_confirmationAndEscapePrecedence() {
        compare(Logic.confirmationAction(true, "", "shutdown"), "select")
        compare(Logic.confirmationAction(true, "shutdown", "shutdown"), "confirm")
        compare(Logic.confirmationAction(true, "shutdown", "reboot"), "pending")
        compare(Logic.escapeAction(true, "shutdown"), "cancel-confirmation")
        compare(Logic.escapeAction(true, ""), "close")
        compare(Logic.escapeAction(false, ""), "none")
    }

    function test_triggerRequiresKnownAvailableIdleAction() {
        verify(Logic.canTrigger("lock", true, false))
        verify(!Logic.canTrigger("missing", true, false))
        verify(!Logic.canTrigger("lock", false, false))
        verify(!Logic.canTrigger("lock", true, true))
    }
}
