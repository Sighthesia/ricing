import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify mode selection and persistent indicator ownership.
Item {
    width: 240
    height: 80

    Lazer.ModeSelector { id: selector }

    TestCase {
        name: "LazerModeSelector"

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            selector.selectedMode = "osu"
        }

        function cleanup() { Lazer.MotionTokens.reducedMotionOverride = false }

        function test_selectionAndIndicatorIdentity() {
            compare(selector.selectedMode, "osu")
            compare(selector.selectedIndex, 0)
            selector.activateIndex(2)
            compare(selector.selectedMode, "catch")
            var indicator = selector.indicatorItem
            selector.activateIndex(3)
            compare(selector.indicatorItem, indicator)
            compare(selector.indicatorTargetX, selector.slotX(3) + 10)
            selector.moveSelection(-1)
            compare(selector.selectedMode, "catch")
        }

        function test_navigationWraps() {
            selector.moveSelection(-1)
            compare(selector.selectedMode, "mania")
            selector.moveSelection(1)
            compare(selector.selectedMode, "osu")
        }

        function test_reducedMotionSnapsIndicator() {
            Lazer.MotionTokens.reducedMotionOverride = true
            selector.activateIndex(3)
            compare(selector.indicatorX, selector.indicatorTargetX)
        }
    }
}
