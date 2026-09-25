import QtQuick
import QtTest
import "../../services/SessionServiceLogic.js" as Logic

TestCase {
    name: "SessionServiceLogic"

    function test_knownActionsAndLogoutAvailability() {
        verify(Logic.isKnownAction("lock"))
        verify(Logic.isKnownAction("shutdown"))
        verify(!Logic.isKnownAction("format"))
        verify(!Logic.isAvailable("logout", ""))
        verify(Logic.isAvailable("logout", "42"))
    }

    function test_singleInFlightGateRejectsUnknownAndUnavailableActions() {
        verify(Logic.canStart(false, "reboot", "42"))
        verify(!Logic.canStart(true, "reboot", "42"))
        verify(!Logic.canStart(false, "logout", ""))
        verify(!Logic.canStart(false, "missing", "42"))
    }

    function test_commandMappingsNeverMapLockToProcess() {
        compare(Logic.commandFor("lock", "42"), [])
        compare(Logic.commandFor("logout", "42"), ["loginctl", "terminate-session", "42"])
        compare(Logic.commandFor("logout", ""), [])
        compare(Logic.commandFor("suspend", "42"), ["systemctl", "suspend"])
        compare(Logic.commandFor("reboot", "42"), ["systemctl", "reboot"])
        compare(Logic.commandFor("shutdown", "42"), ["systemctl", "poweroff"])
    }
}
