import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify the dedicated music entry's state and timing contract.
Item {
    width: 100; height: 100
    Lazer.OsuTopBarButton { id: button; testMode: true; iconSource: "../../modules/lazerbar/icons/music.svg" }
    TestCase {
        name: "OsuTopBarButton"
        function init() { button.enabled = true; button.isActive = false; button.forceHoverForTest = false; button.tooltipRequested = false; Lazer.MotionTokens.reducedMotionOverride = false }
        function cleanup() { Lazer.MotionTokens.reducedMotionOverride = false }
        function test_states() {
            verify(Qt.colorEqual(button.backgroundColor, "transparent"))
            compare(button.iconOpacity, 0.8)
            button.forceHoverForTest = true
            verify(Qt.colorEqual(button.backgroundColor, "#333744"))
            compare(button.iconOpacity, 1)
            button.isActive = true
            verify(Qt.colorEqual(button.backgroundColor, "#EB1C60"))
            button.enabled = false
            compare(button.iconOpacity, 0.45)
        }
        function test_flash() {
            button.restartFlash()
            compare(button.flashOverlayItem.opacity, Lazer.MotionTokens.clickFlashOpacity)
            compare(button.flashAnimationItem.running, true)
            tryCompare(button, "flashActive", false, Lazer.MotionTokens.clickFlashDuration + 100)
            compare(button.flashOverlayItem.opacity, 0)
        }
        function test_tooltipDelay() {
            button.forceHoverForTest = true
            wait(150)
            compare(button.tooltipRequested, false)
            tryCompare(button, "tooltipRequested", true, 100)
            button.forceHoverForTest = false
            compare(button.tooltipRequested, false)
        }
        function test_reducedMotion() {
            Lazer.MotionTokens.reducedMotionOverride = true
            button.forceHoverForTest = true
            compare(button.effectiveScale, 1)
        }
    }
}
