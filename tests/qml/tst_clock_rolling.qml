import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/bar/widgets" as ClockParts

// Verify the ported flip-clock strips: digit parsing, seconds toggle, and
// instant digit swaps under reduced motion.
Item {
    ClockParts.RollingClockTime {
        id: rolling
        currentTime: new Date(2026, 0, 2, 9, 5, 7)
    }
    ClockParts.RollingDigit {
        id: digit
        targetDigit: 3
    }
    ClockParts.Clock { id: clock }

    TestCase {
        name: "ClockRolling"
        function test_digitParsing() {
            compare(rolling.hourTens, 0)
            compare(rolling.hourOnes, 9)
            compare(rolling.minuteTens, 0)
            compare(rolling.minuteOnes, 5)
            compare(rolling.secondTens, 0)
            compare(rolling.secondOnes, 7)
        }
        function test_secondsToggleWidens() {
            rolling.showSeconds = false
            var narrow = rolling.implicitWidth
            rolling.showSeconds = true
            verify(rolling.implicitWidth > narrow)
        }
        function test_digitFollowsTarget() {
            Lazer.MotionTokens.reducedMotionOverride = true
            digit.targetDigit = 8
            compare(digit._displayDigit, 8)
            compare(digit.digitWidth > 0, true)
            compare(digit.digitHeight > 0, true)
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_clockUsesRolling() {
            compare(clock.useRollingDigits, true)
            compare(clock.showSeconds, false)
            verify(clock.timeSlotWidth > 0)
            verify(clock.implicitWidth > 0)
        }
        function test_flipTokensMatchLegacy() {
            // Ported pacing: old Motion.color.transitionDuration (300) x 8/4/1.
            compare(Lazer.MotionTokens.clockHourFlip, 2400)
            compare(Lazer.MotionTokens.clockMinuteFlip, 1200)
            compare(Lazer.MotionTokens.clockSecondFlip, 300)
            compare(Lazer.MotionTokens.clockFlipEasing, Easing.OutCubic)
            // Component defaults match the old branch components.
            compare(rolling.hourTransitionDuration, 180)
            compare(rolling.minuteTransitionDuration, 180)
            compare(rolling.secondTransitionDuration, 180)
            compare(rolling.transitionEasing, Easing.InOutCubic)
            compare(digit.transitionDuration, 180)
            compare(digit.transitionEasing, Easing.InOutCubic)
            compare(rolling.digitPixelSize, 14)
        }
    }
}
