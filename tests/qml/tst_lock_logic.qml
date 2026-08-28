import QtQuick
import QtTest
import "../../modules/lock/LockLogic.js" as Logic

TestCase {
    name: "LockLogic"

    function test_canStartRejectsConcurrentLockAttempt() {
        verify(Logic.canStart(false, false))
        verify(!Logic.canStart(true, false))
        verify(!Logic.canStart(false, true))
        verify(!Logic.canStart(true, true))
    }

    function test_nextState() {
        compare(Logic.nextState("idle", "prepare-ready"), "locked")
        compare(Logic.nextState("locked", "auth-success"), "exiting")
        compare(Logic.nextState("exiting", "exit-finished"), "idle")
    }

    function test_shouldReleaseLockWaitsForFinishedExit() {
        verify(!Logic.shouldReleaseLock("exiting", false))
        verify(Logic.shouldReleaseLock("exiting", true))
        verify(!Logic.shouldReleaseLock("locked", true))
    }

    function test_failureTransitionNotifiesOnceAndKeepsFirstMeaningfulMessage() {
        var first = Logic.failureTransition(false, "", "PAM conversation failed")
        compare(first.shouldNotify, true)
        compare(first.message, "PAM conversation failed")

        var completed = Logic.failureTransition(first.failureReported, first.message,
                                                 "Authentication failed")
        compare(completed.shouldNotify, false)
        compare(completed.message, "PAM conversation failed")
    }

    function test_failureTransitionCanFillAnInitiallyEmptyMessageWithoutRenotifying() {
        var first = Logic.failureTransition(false, "", "")
        compare(first.shouldNotify, true)

        var completed = Logic.failureTransition(true, first.message, "Authentication failed")
        compare(completed.shouldNotify, false)
        compare(completed.message, "Authentication failed")
    }
}
