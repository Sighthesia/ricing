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

    function test_sessionKeyPrefersNiriSocketAndFallsBackToSessionId() {
        compare(Logic.sessionKey("/run/user/1000/niri.wayland-1.aBc123", "3"), "/run/user/1000/niri.wayland-1.aBc123")
        compare(Logic.sessionKey("", "3"), "3")
        compare(Logic.sessionKey(null, "  3  "), "3")
        compare(Logic.sessionKey("", ""), "")
        compare(Logic.sessionKey(undefined, undefined), "")
    }

    function test_markerDisarmsOnlyTheSameSession() {
        const socket = "/run/user/1000/niri.wayland-1.aBc123"
        verify(Logic.markerMatches(socket + "\n", socket))
        verify(!Logic.markerMatches("/run/user/1000/niri.wayland-1.zzZ999", socket))
        verify(!Logic.markerMatches("", socket))
        verify(!Logic.markerMatches(socket, ""))
        verify(!Logic.markerMatches(null, socket))
    }
}
