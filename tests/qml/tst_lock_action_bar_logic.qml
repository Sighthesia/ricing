import QtQuick
import QtTest
import "../../modules/lock/LockActionBarLogic.js" as Logic

TestCase {
    name: "LockActionBarLogic"

    function test_rowIsExactlyTheThreePowerActions() {
        var ids = Logic.actions().map(function(action) { return action.id })
        compare(ids, ["suspend", "shutdown", "logout"])
    }

    // The row drops the old Lock row (the surface is already locked) and the
    // reboot row; the service keeps both ids, so neither capability is lost.
    // The labels stay spoken/accessible names and status-line copy: the buttons
    // themselves are glyph-only, like the lock entry.
    function test_lockAndRebootAreNotRowActions() {
        compare(Logic.labelFor("lock"), "")
        compare(Logic.labelFor("reboot"), "")
        compare(Logic.labelFor("suspend"), "Suspend")
        compare(Logic.labelFor("shutdown"), "Shut down")
        compare(Logic.labelFor("logout"), "Log out")
    }

    function test_everyRowActionIsConfirmable() {
        var list = Logic.actions()
        for (var i = 0; i < list.length; ++i)
            verify(list[i].requiresConfirmation === true, list[i].id + " must confirm")
    }

    function test_confirmationNeedsASecondActivationOfTheSameAction() {
        compare(Logic.confirmationAction("", "shutdown"), "select")
        compare(Logic.confirmationAction("shutdown", "shutdown"), "confirm")
        compare(Logic.confirmationAction("shutdown", "suspend"), "pending")
        compare(Logic.confirmationAction("", "lock"), "pending")
        compare(Logic.confirmationAction("", "missing"), "pending")
    }

    // There is no panel left, so Escape only ever cancels an armed confirmation.
    function test_escapeOnlyCancelsAPendingConfirmation() {
        compare(Logic.escapeAction("shutdown"), "cancel-confirmation")
        compare(Logic.escapeAction(""), "none")
    }

    function test_triggerRequiresKnownAvailableIdleAction() {
        verify(Logic.canTrigger("suspend", true, false))
        verify(Logic.canTrigger("logout", true, false))
        verify(!Logic.canTrigger("lock", true, false))
        verify(!Logic.canTrigger("missing", true, false))
        verify(!Logic.canTrigger("suspend", false, false))
        verify(!Logic.canTrigger("suspend", true, true))
    }

    function test_statusPrefersErrorThenConfirmationThenResult() {
        compare(Logic.statusMessage("", "", ""), "")
        compare(Logic.statusMessage("", "", "suspend requested"), "suspend requested")
        compare(Logic.statusMessage("shutdown", "", ""), "Confirm Shut down?")
        compare(Logic.statusMessage("shutdown", "Session action failed", "x"),
                "Session action failed")
        compare(Logic.statusMessage("bogus", "", ""), "Select again to confirm")
    }
}
