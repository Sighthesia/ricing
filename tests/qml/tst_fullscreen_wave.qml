import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify one wave layer's angle, reveal endpoints, clipping, and reduced-motion path.
Item {
    width: 800
    height: 600

    Lazer.FullscreenWave { id: first; width: 680; height: 554; angle: 13; restOffset: -120 }
    Lazer.FullscreenWave { id: second; width: 680; height: 554; angle: -7 }
    Lazer.FullscreenWave { id: third; width: 680; height: 554; angle: 4 }
    Lazer.FullscreenWave { id: fourth; width: 680; height: 554; angle: -2 }

    TestCase {
        name: "FullscreenWave"

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            first.progress = 0
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_anglesAndClipping() {
            compare(first.angle, 13)
            compare(second.angle, -7)
            compare(third.angle, 4)
            compare(fourth.angle, -2)
            verify(first.clip)
        }

        function test_revealEndpoints() {
            compare(first.effectiveOffset, first.hiddenOffset)
            compare(first.opacity, 0)
            first.progress = 1
            compare(first.effectiveOffset, first.restOffset)
            compare(first.opacity, 1)
        }

        function test_reducedMotionUsesFinalGeometry() {
            Lazer.MotionTokens.reducedMotionOverride = true
            first.progress = 0.4
            compare(first.effectiveOffset, first.restOffset)
            compare(first.opacity, 0.4)
        }
    }
}
