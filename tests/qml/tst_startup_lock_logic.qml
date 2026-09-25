import QtQuick
import QtTest
import "../../modules/lock/StartupLockLogic.js" as Logic

TestCase {
    name: "StartupLockLogic"

    function test_startupAttemptRequiresReadyIdleAndArmed() {
        verify(Logic.canAttempt("idle", true, true))
        verify(!Logic.canAttempt("idle", false, true))
        verify(!Logic.canAttempt("preparing", true, true))
        verify(!Logic.canAttempt("idle", true, false))
    }

    function test_startupResultClearsOnlyAfterAcceptedLock() {
        compare(Logic.nextAttempt(true, true, "idle", true), { armed: false, retry: false })
        compare(Logic.nextAttempt(true, false, "idle", false), { armed: true, retry: true })
        compare(Logic.nextAttempt(true, true, "locked", false), { armed: false, retry: false })
    }
}
