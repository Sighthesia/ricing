import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify player presentation, action signals, and reveal behavior.
Item {
    width: 400; height: 200
    Lazer.OsuMusicOverlay { id: overlay }
    SignalSpy { id: shuffleSpy; target: overlay; signalName: "shuffleRequested" }
    SignalSpy { id: previousSpy; target: overlay; signalName: "previousRequested" }
    SignalSpy { id: playlistSpy; target: overlay; signalName: "playlistRequested" }
    TestCase {
        name: "OsuMusicOverlay"
        function init() { overlay.close(); overlay.openProgress = 0; overlay.shuffleActive = false; overlay.progress = 0; overlay.canGoPrevious = false; shuffleSpy.clear(); previousSpy.clear(); playlistSpy.clear(); Lazer.MotionTokens.reducedMotionOverride = false }
        function cleanup() { Lazer.MotionTokens.reducedMotionOverride = false }
        function test_geometryAndProgress() {
            compare(overlay.implicitWidth, 340); compare(overlay.implicitHeight, 130)
            overlay.progress = -1; compare(overlay.clampedProgress, 0)
            overlay.progress = 2; compare(overlay.clampedProgress, 1)
        }
        function test_lifecycle() {
            compare(overlay.openDuration, 160); compare(overlay.closeDuration, 100)
            overlay.open(); compare(overlay.interactive, true); tryCompare(overlay, "openProgress", 1, 240)
            overlay.close(); compare(overlay.interactive, false); tryCompare(overlay, "openProgress", 0, 180)
        }
        function test_reducedMotion() { Lazer.MotionTokens.reducedMotionOverride = true; overlay.openProgress = 0; compare(overlay.effectiveYOffset, 0) }
        function test_signals() {
            overlay.shuffleActive = true; overlay.shuffleRequested(true); compare(shuffleSpy.count, 1)
            overlay.previousRequested(); compare(previousSpy.count, 1)
            overlay.playlistRequested(); compare(playlistSpy.count, 1)
        }
    }
}
