import QtQuick
import QtTest
import "../../modules/lock/StartupLockLogic.js" as Logic
import "../../modules/lazerbar/StartupRevealLogic.js" as Reveal

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

    // The startup lock is the regression this guards: it engages before any
    // chrome exists, so a capture could only record a half-assembled desktop
    // that the lock's own wallpaper reveal would then contradict.
    function test_startupLockNeverCapturesTheDesktop() {
        compare(Logic.backgroundModeFor("screenshot", true), "wallpaper")
        compare(Logic.backgroundModeFor("wallpaper", true), "wallpaper")
        compare(Logic.backgroundModeFor("", true), "wallpaper")
        compare(Logic.backgroundModeFor(undefined, true), "wallpaper")
    }

    function test_manualLockKeepsTheConfiguredCapture() {
        compare(Logic.backgroundModeFor("screenshot", false), "screenshot")
        compare(Logic.backgroundModeFor("wallpaper", false), "wallpaper")
        compare(Logic.backgroundModeFor("screenshot", undefined), "screenshot")
    }

    // The startup wave waits for both gates; a manual request never consults
    // them, so a configured reveal cannot be delayed by a settling boot.
    function test_startupWaveNeedsWallpaperAndChromeReady() {
        verify(!Reveal.waveAllowed(true, false, false))
        verify(!Reveal.waveAllowed(true, true, false))
        verify(!Reveal.waveAllowed(true, false, true))
        verify(Reveal.waveAllowed(true, true, true))
        verify(Reveal.waveAllowed(false, false, false))
    }

    // Readiness gates the wave only: the startup request always reveals the
    // wallpaper (there is no desktop to capture) and a manual request always
    // keeps the configured background mode.
    function test_readinessDoesNotChangeBackgroundMode() {
        compare(Logic.backgroundModeFor("screenshot", true), "wallpaper")
        compare(Logic.backgroundModeFor("wallpaper", true), "wallpaper")
        compare(Logic.backgroundModeFor("screenshot", false), "screenshot")
        compare(Logic.backgroundModeFor("wallpaper", false), "wallpaper")
        compare(Logic.backgroundModeFor("screenshot", undefined), "screenshot")
    }
}
