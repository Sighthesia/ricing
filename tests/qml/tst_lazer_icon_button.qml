import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify button state composition and reduced-motion behavior.
Item {
    width: 100
    height: 100

    Lazer.IconButton {
        id: button
        testMode: true
    }

    TestCase {
        name: "LazerIconButton"
        when: windowShown

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            button.enabled = true
            button.active = false
            button.forceHoverForTest = false
            button.forcePressForTest = false
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_stateComposition() {
            compare(button.buttonState, "rest")
            button.active = true
            compare(button.buttonState, "active")
            button.forceHoverForTest = true
            compare(button.buttonState, "activeHover")
            button.forcePressForTest = true
            compare(button.buttonState, "activePressed")
            button.enabled = false
            compare(button.buttonState, "disabled")
        }

        function test_reducedMotionSuppressesTransforms() {
            Lazer.MotionTokens.reducedMotionOverride = true
            button.forceHoverForTest = true
            button.forcePressForTest = true
            compare(button.effectiveScale, 1)
            compare(button.effectiveYOffset, 0)
            verify(button.backgroundColor !== "transparent")
        }

        function test_normalMotionUsesExactTransforms() {
            button.forceHoverForTest = true
            compare(button.effectiveScale, 1.015)
            button.forcePressForTest = true
            compare(button.effectiveScale, 0.985)
            compare(button.effectiveYOffset, 1)
        }
    }
}
