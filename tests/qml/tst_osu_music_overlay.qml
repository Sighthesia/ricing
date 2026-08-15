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
    SignalSpy { id: closeRequestSpy; target: overlay; signalName: "closeRequested" }
    SignalSpy { id: closedSpy; target: overlay; signalName: "closed" }
    TestCase {
        name: "OsuMusicOverlay"
        function init() { overlay.close(); overlay.openProgress = 0; overlay.openState = false; overlay.interactive = false; overlay.shuffleActive = false; overlay.progress = 0; overlay.canGoPrevious = false; shuffleSpy.clear(); previousSpy.clear(); playlistSpy.clear(); closeRequestSpy.clear(); closedSpy.clear(); Lazer.MotionTokens.reducedMotionOverride = false }
        function cleanup() { Lazer.MotionTokens.reducedMotionOverride = false }
        function test_geometryAndProgress() {
            compare(overlay.implicitWidth, 340); compare(overlay.implicitHeight, 130)
            overlay.progress = -1; compare(overlay.clampedProgress, 0)
            overlay.progress = 2; compare(overlay.clampedProgress, 1)
        }
        function test_lifecycle() {
            compare(overlay.openDuration, 160); compare(overlay.closeDuration, 100)
            overlay.open(); compare(overlay.openState, true); compare(overlay.interactive, true); tryCompare(overlay, "openProgress", 1, 240)
            overlay.close(); compare(overlay.openState, false); compare(overlay.interactive, false); tryCompare(overlay, "openProgress", 0, 180); tryCompare(closedSpy, "count", 1, 100)
        }
        function test_reducedMotion() { Lazer.MotionTokens.reducedMotionOverride = true; overlay.openProgress = 0; compare(overlay.effectiveYOffset, 0) }
        function test_signals() {
            overlay.shuffleActive = true; overlay.shuffleRequested(true); compare(shuffleSpy.count, 1)
            overlay.previousRequested(); compare(previousSpy.count, 1)
            overlay.playlistRequested(); compare(playlistSpy.count, 1)
        }
        function test_localNowPlayingStructure() {
            verify(overlay.background); verify(overlay.metadataBlock); verify(overlay.controlsRow); verify(overlay.progressBar)
            verify(overlay.implicitWidth < 600); verify(overlay.implicitHeight < 300)
            compare(overlay.background.radius, 4)
            verify(overlay.route === undefined); verify(overlay.waveProgress === undefined)
        }
        function test_disabledControlsAndEscape() {
            overlay.canGoPrevious = false
            verify(!overlay.previousControl.enabled)
            overlay.open(); tryCompare(overlay, "openProgress", 1, 240)
            overlay.forceActiveFocus(); keyPress(Qt.Key_Escape)
            compare(closeRequestSpy.count, 1)
        }
    }
}
