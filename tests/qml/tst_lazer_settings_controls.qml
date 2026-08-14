import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Provide a compact host for the reusable settings control contract tests.
Item {
    width: 760
    height: 480

    Lazer.LazerSettingsRow {
        id: row
        labelText: "设置"
        descriptionText: "说明文字"
        Lazer.LazerSettingsToggle { id: rowToggle }
    }

    Lazer.LazerSettingsToggle { id: toggle }
    Lazer.LazerSettingsSlider {
        id: slider
        from: 0
        to: 10
        stepSize: 2
        suffix: "%"
        value: 4
    }
    Lazer.LazerSettingsChoice {
        id: choice
        model: [
            { value: "auto", label: "自动" },
            { value: "dark", label: "深色模式" }
        ]
        currentValue: "auto"
    }
    Lazer.LazerSettingsTextField {
        id: textField
        text: "  wallpaper.png  "
        placeholderText: "壁纸路径"
    }

    SignalSpy { id: toggleSpy; target: toggle; signalName: "toggled" }
    SignalSpy { id: sliderSpy; target: slider; signalName: "valueModified" }
    SignalSpy { id: choiceSpy; target: choice; signalName: "valueSelected" }
    SignalSpy { id: commitSpy; target: textField; signalName: "textCommitted" }
    SignalSpy { id: clearSpy; target: textField; signalName: "clearRequested" }

    TestCase {
        name: "LazerSettingsControls"

        function init() {
            toggle.enabled = true
            toggle.checked = false
            toggleSpy.clear()
            slider.enabled = true
            slider.value = 4
            sliderSpy.clear()
            choice.enabled = true
            choice.currentValue = "auto"
            choiceSpy.clear()
            textField.enabled = true
            textField.text = "  wallpaper.png  "
            commitSpy.clear()
            clearSpy.clear()
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function cleanup() { Lazer.MotionTokens.reducedMotionOverride = false }

        function test_toggleActivationAndDisabledBlocking() {
            toggle.activate()
            compare(toggle.checked, true)
            compare(toggleSpy.count, 1)
            compare(toggleSpy.signalArguments[0][0], true)

            toggle.enabled = false
            toggle.activate()
            compare(toggle.checked, true)
            compare(toggleSpy.count, 1)
        }

        function test_sliderNormalizesStepsAndSuffix() {
            slider.value = 99
            compare(slider.value, 10)
            compare(slider.displayText, "10%")
            slider.value = 5
            compare(slider.value, 6)
            slider.increase()
            compare(slider.value, 8)
            slider.decrease()
            compare(slider.value, 6)
            verify(sliderSpy.count >= 1)
        }

        function test_sliderDisabledAndKeyboardBehavior() {
            slider.enabled = false
            slider.increase()
            compare(slider.value, 4)
            slider.enabled = true
            slider.forceActiveFocus()
            keyPress(Qt.Key_Right)
            compare(slider.value, 6)
            keyPress(Qt.Key_Left)
            compare(slider.value, 4)
        }

        function test_choiceRejectsUnknownValues() {
            choice.selectValue("missing")
            compare(choice.currentValue, "auto")
            compare(choiceSpy.count, 0)
            choice.selectValue("dark")
            compare(choice.currentValue, "dark")
            compare(choiceSpy.count, 1)
            compare(choiceSpy.signalArguments[0][0], "dark")
        }

        function test_textTrimsCommitAndClears() {
            textField.commit()
            compare(commitSpy.count, 1)
            compare(commitSpy.signalArguments[0][0], "wallpaper.png")
            textField.clear()
            compare(textField.text, "")
            compare(clearSpy.count, 1)
        }

        function test_focusVisibleAndReducedMotion() {
            slider.forceActiveFocus()
            verify(slider.focusVisible)
            Lazer.MotionTokens.reducedMotionOverride = true
            compare(slider.effectiveScale, 1)
        }

        function test_rowHasMinimumHeightAndDefaultControl() {
            verify(row.implicitHeight >= 56)
            compare(row.controlItem, rowToggle)
        }
    }
}
