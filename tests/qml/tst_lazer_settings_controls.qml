import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Provide a compact host for the reusable settings control contract tests.
Item {
    width: 760
    height: 480

    QtObject { id: toggleHolder; property bool value: false }
    QtObject { id: sliderHolder; property real value: 4 }
    QtObject { id: choiceHolder; property string value: "auto" }
    QtObject { id: textHolder; property string value: "  wallpaper.png  " }
    QtObject { id: resetState; property int count: 0 }

    // Keep a non-settings child here to verify Row's guarded contract.
    Lazer.LazerSettingsRow {
        id: plainRow
        width: 160
        Rectangle { width: 20; height: 20 }
    }

    Lazer.LazerSettingsRow {
        id: row
        width: 520
        labelText: "设置"
        descriptionText: "这是一段很长的中文说明，用于验证窄宽布局不会和右侧控件重叠。"
        Lazer.LazerSettingsToggle { id: rowToggle }
    }

    Lazer.LazerSettingsRow {
        id: revertRow
        width: 520
        labelText: "可恢复项"
        defaultValue: 5
        currentValue: 7
        resetCallback: function() { resetState.count++ }
        Lazer.LazerSettingsSlider { id: revertRowSlider; from: 0; to: 10 }
    }

    Lazer.LazerSettingsRow {
        id: compactRow
        width: 220
        labelText: "窄屏设置"
        descriptionText: "紧凑布局说明"
        Lazer.LazerSettingsTextField {
            id: compactTextField
            text: textHolder.value
            onTextCommitted: next => textHolder.value = next
            onClearRequested: textHolder.value = ""
        }
    }

    Lazer.LazerSettingsToggle {
        id: toggle
        checked: toggleHolder.value
        onToggled: next => toggleHolder.value = next
    }
    Lazer.LazerSettingsSlider {
        id: slider
        from: 0
        to: 10
        stepSize: 2
        suffix: "%"
        value: sliderHolder.value
        defaultValue: 2
        onValueModified: next => sliderHolder.value = next
    }
    Lazer.LazerSettingsSlider { id: secondSlider; value: 2 }
    Lazer.LazerSettingsChoice {
        id: choice
        model: [
            { value: "auto", label: "自动" },
            { value: "dark", label: "深色模式" }
        ]
        currentValue: choiceHolder.value
        onValueSelected: next => choiceHolder.value = next
    }
    Lazer.LazerSettingsTextField {
        id: textField
        text: textHolder.value
        placeholderText: "壁纸路径"
        onTextCommitted: next => textHolder.value = next
        onClearRequested: textHolder.value = ""
    }
    Lazer.LazerSettingsTextField { id: secondTextField; text: "second" }
    Lazer.LazerSettingsToggle { id: invalidWidthToggle; availableWidth: -20 }
    Lazer.LazerSettingsSlider { id: invalidWidthSlider; availableWidth: NaN }

    SignalSpy { id: toggleSpy; target: toggle; signalName: "toggled" }
    SignalSpy { id: sliderSpy; target: slider; signalName: "valueModified" }
    SignalSpy { id: choiceSpy; target: choice; signalName: "valueSelected" }
    SignalSpy { id: commitSpy; target: textField; signalName: "textCommitted" }
    SignalSpy { id: clearSpy; target: textField; signalName: "clearRequested" }
    SignalSpy { id: dropdownSpy; target: Lazer.SettingsOverlayBridge; signalName: "dropdownRequested" }
    SignalSpy { id: dropdownDismissSpy; target: Lazer.SettingsOverlayBridge; signalName: "dropdownDismissed" }

    TestCase {
        name: "LazerSettingsControls"

        function init() {
            toggle.enabled = true
            toggleHolder.value = false
            toggleSpy.clear()
            slider.enabled = true
            slider.from = 0
            slider.to = 10
            slider.stepSize = 2
            slider.requestedWidth = slider.implicitWidth
            sliderHolder.value = 4
            slider.focus = false
            secondSlider.focus = false
            sliderSpy.clear()
            choice.enabled = true
            choiceHolder.value = "auto"
            choiceSpy.clear()
            choice.menuOpen = false
            dropdownSpy.clear()
            dropdownDismissSpy.clear()
            Lazer.SettingsOverlayBridge.clearTooltips()
            textField.enabled = true
            textField.focus = false
            textField.editorItem.focus = false
            textHolder.value = "  wallpaper.png  "
            commitSpy.clear()
            clearSpy.clear()
            resetState.count = 0
            revertRow.currentValue = 7
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
            Lazer.SettingsOverlayBridge.clearTooltips()
        }

        function test_toggleActivationAndDisabledBlocking() {
            toggle.activate()
            compare(toggleHolder.value, true)
            compare(toggleSpy.count, 1)
            compare(toggleSpy.signalArguments[0][0], true)

            toggle.enabled = false
            toggle.activate()
            compare(toggleHolder.value, true)
            compare(toggleSpy.count, 1)
        }

        function test_toggleKeyboardActivation() {
            toggle.forceActiveFocus()
            keyPress(Qt.Key_Return)
            compare(toggleHolder.value, true)
            keyPress(Qt.Key_Space)
            compare(toggleHolder.value, false)
        }

        function test_toggleRendersFixedOsuNub() {
            compare(toggle.nubItem.implicitWidth, 50)
            compare(toggle.nubItem.implicitHeight, 15)
            verify(toggle.nubItem)
            toggle.checked = true
            verify(toggle.nubItem.effectiveChecked)
            Lazer.MotionTokens.reducedMotionOverride = true
            compare(toggle.nubMorphEnabled, false)
            compare(toggle.fillWidth, false)
        }

        function test_sliderNormalizesStepsAndSuffix() {
            sliderHolder.value = 99
            compare(slider.displayValue, 10)
            compare(slider.displayText, "10%")
            sliderHolder.value = 5
            compare(slider.displayValue, 6)
            slider.increase()
            compare(sliderHolder.value, 8)
            slider.decrease()
            compare(sliderHolder.value, 6)
            verify(sliderSpy.count >= 1)
            sliderHolder.value = 3
            compare(slider.displayValue, 4)
        }

        function test_sliderDisabledAndKeyboardBehavior() {
            slider.enabled = false
            slider.increase()
            compare(sliderHolder.value, 4)
            slider.enabled = true
            slider.forceActiveFocus()
            keyPress(Qt.Key_Right)
            compare(sliderHolder.value, 6)
            keyPress(Qt.Key_Left)
            compare(sliderHolder.value, 4)
        }

        function test_slidersDoNotClaimInitialFocus() {
            verify(!slider.activeFocus)
            verify(!secondSlider.activeFocus)
            slider.forceActiveFocus()
            verify(slider.activeFocus)
            verify(!secondSlider.activeFocus)
        }

        function test_sliderSafeRangesAndReducedMotion() {
            slider.from = 10
            slider.to = 0
            slider.stepSize = 3
            sliderHolder.value = 9
            compare(slider.displayValue, 10)
            compare(slider.normalizedFraction, 0)
            compare(slider.normalized(0), 0)
            compare(slider.normalized(9), 10)
            slider.setValue(10)
            compare(sliderHolder.value, 10)
            slider.setValue(0)
            compare(sliderHolder.value, 0)
            slider.from = 4
            slider.to = 4
            sliderHolder.value = 4
            compare(slider.normalizedFraction, 0)
            compare(slider.valueForTrackPosition(0), 4)
            compare(slider.valueForTrackPosition(slider.trackItem.width), 4)
            var beforeEqualRange = sliderSpy.count
            slider.setValue(4)
            compare(sliderSpy.count, beforeEqualRange)
            Lazer.MotionTokens.reducedMotionOverride = true
            compare(slider.trackFillBehaviorEnabled, false)
            verify(slider.trackTapEnabled)
        }

        function test_sliderDoubleClickRestoresDefault() {
            sliderHolder.value = 8
            slider.resetToDefault()
            compare(sliderHolder.value, 2)
            verify(slider.defaultValue !== undefined)
            slider.defaultValue = undefined
            sliderHolder.value = 6
            slider.resetToDefault()
            compare(sliderHolder.value, 6)
            compare(slider.nubDoubleTapEnabled, false)
        }

        function test_sliderReverseTrackMapping() {
            slider.from = 10
            slider.to = 0
            slider.stepSize = 3
            sliderHolder.value = 10
            slider.forceActiveFocus()
            keyPress(Qt.Key_Right)
            compare(sliderHolder.value, 7)
            keyPress(Qt.Key_Left)
            compare(sliderHolder.value, 10)
            compare(slider.valueForTrackPosition(0), 10)
            compare(slider.valueForTrackPosition(slider.trackItem.width), 0)
            compare(slider.valueForTrackPosition(slider.trackItem.width / 2), 4)
        }

        function test_choiceRejectsUnknownValues() {
            choice.selectValue("missing")
            compare(choiceHolder.value, "auto")
            compare(choiceSpy.count, 0)
            choiceHolder.value = "missing"
            compare(choice.displayLabel, "")
            choice.selectNext(1)
            compare(choiceSpy.count, 0)
            choiceHolder.value = "auto"
            choice.selectValue("dark")
            compare(choiceHolder.value, "dark")
            compare(choiceSpy.count, 1)
            compare(choiceSpy.signalArguments[0][0], "dark")
            compare(choice.displayLabel, "深色模式")
        }

        function test_choiceOpensRealDropdownInsteadOfCycling() {
            choiceHolder.value = "auto"
            choice.forceActiveFocus()
            keyPress(Qt.Key_Right)
            compare(choiceHolder.value, "auto")
            compare(dropdownSpy.count, 0)
            keyPress(Qt.Key_Enter)
            compare(choice.menuOpen, true)
            compare(dropdownSpy.count, 1)
            verify(dropdownSpy.signalArguments[0][0] === choice)
            keyPress(Qt.Key_Space)
            compare(choice.menuOpen, true)
            choice.closeMenu()
            compare(choice.menuOpen, false)
            compare(dropdownDismissSpy.count, 1)
            compare(choiceHolder.value, "auto")
        }

        function test_choiceDisabledBlocksMenu() {
            choice.enabled = false
            choice.openMenu()
            compare(choice.menuOpen, false)
            compare(dropdownSpy.count, 0)
            compare(choice.activeFocusOnTab, false)
            choice.closeMenu()
            compare(dropdownDismissSpy.count, 0)
        }

        function test_textTrimsCommitAndClears() {
            textField.commit()
            compare(commitSpy.count, 1)
            compare(commitSpy.signalArguments[0][0], "wallpaper.png")
            compare(textHolder.value, "wallpaper.png")
            textHolder.value = "external.png"
            compare(textField.text, "external.png")
            textField.clear()
            compare(textHolder.value, "")
            compare(clearSpy.count, 1)
            textField.enabled = false
            textField.focus = false
            textField.commit()
            textField.clear()
            compare(commitSpy.count, 1)
            compare(clearSpy.count, 1)
            compare(textField.activeFocusOnTab, false)
        }

        function test_textFieldOwnsFocusAndPreservesBinding() {
            verify(!textField.activeFocus)
            verify(!secondTextField.activeFocus)
            textField.focusEditor()
            verify(textField.activeFocus)
            verify(textField.editorItem.activeFocus)
            verify(!secondTextField.editorItem.activeFocus)
            textField.editorItem.insert(textField.editorItem.cursorPosition, "typed")
            compare(textField.text, "  wallpaper.png  ")
            compare(textField.editorItem.text, "  wallpaper.png  typed")
            textHolder.value = "external-while-editing.png"
            compare(textField.text, "external-while-editing.png")
            compare(textField.editorItem.text, "  wallpaper.png  typed")
            textField.focus = false
            compare(textField.editorItem.text, "external-while-editing.png")
            textField.focusEditor()
            textField.editorItem.selectAll()
            textField.editorItem.text = "  committed.png  "
            textField.commit()
            compare(textHolder.value, "committed.png")
            textHolder.value = "external.png"
            compare(textField.text, "external.png")
            textField.enabled = false
            verify(!textField.editorItem.activeFocus)
        }

        function test_invalidAvailableWidthsStaySafe() {
            verify(invalidWidthToggle.width >= 0)
            verify(isFinite(invalidWidthToggle.width))
            verify(invalidWidthSlider.width >= 0)
            verify(isFinite(invalidWidthSlider.width))
            slider.requestedWidth = 0
            verify(slider.trackItem.width >= 0)
        }

        function test_focusVisibleAndReducedMotion() {
            slider.forceActiveFocus()
            verify(slider.focusVisible)
            Lazer.MotionTokens.reducedMotionOverride = true
            compare(slider.trackFillBehaviorEnabled, false)
        }

        function test_rowHasMinimumHeightAndDefaultControl() {
            verify(row.implicitHeight >= 56)
            compare(row.compactLayout, false)
            compare(row.controlItem, rowToggle)
            verify(row.textRegionWidth > 0)
            verify(row.controlItem.width > 0)
            verify(row.controlItem.height > 0)
            verify(row.controlItem.x >= 0)
            verify(row.controlItem.x + row.controlItem.width <= row.width - 16)
            row.enabled = false
            compare(row.opacity, Lazer.LazerTheme.settingsDisabledAlpha)
            compare(row.contentEnabled, false)
            compare(rowToggle.rowEnabled, false)
            compare(choice.activeFocusOnTab, true)
            choice.enabled = false
            compare(choice.activeFocusOnTab, false)
            compare(plainRow.controlSupportsRowEnabled, false)
        }

        function test_rowSearchContractMatchesLabelOrDescription() {
            row.searchQuery = ""
            verify(row.matchesSearch)
            verify(row.searchVisible)
            verify(row.visible)
            verify(row.height > 0)
            row.searchQuery = "设置"
            verify(row.matchesSearch)
            verify(row.searchVisible)
            row.searchQuery = "长"
            verify(row.matchesSearch)
            row.searchQuery = "audio"
            verify(!row.matchesSearch)
            verify(!row.searchVisible)
            verify(!row.visible)
            compare(row.height, 0)
            row.searchQuery = ""
            verify(row.visible)
            verify(row.height > 0)
            row.enabled = false
            row.searchQuery = "设置"
            verify(row.matchesSearch)
            verify(row.searchVisible)
            verify(row.visible)
            verify(!row.contentEnabled)
            row.enabled = true
            row.searchQuery = ""
        }

        function test_compactRowStacksTextAndControl() {
            compare(compactRow.compactLayout, true)
            verify(compactRow.textRegionWidth > 0)
            verify(compactTextField.width <= 188)
            verify(compactTextField.x >= 0)
            verify(compactTextField.x + compactTextField.width <= compactRow.width - 16)
            verify(compactRow.labelTextItem.bottom <= compactTextField.top)
            verify(compactRow.height >= compactRow.implicitHeight)
        }

        function test_rowWidthBindingRemainsOwnedByParent() {
            var holder = Qt.createQmlObject('import QtQuick; QtObject { property real value: 300 }', row)
            rowToggle.requestedWidth = Qt.binding(function() { return holder.value })
            compare(rowToggle.requestedWidth, 300)
            verify(rowToggle.width <= row.width - 32)
            holder.value = 180
            compare(rowToggle.requestedWidth, 180)
            compare(rowToggle.width, 180)
        }

        function test_rowShowsRevertUntilValueMatchesDefault() {
            verify(revertRow.hasDefault)
            verify(!revertRow.isDefault)
            verify(revertRow.revertVisible)
            verify(revertRow.canReset)
            verify(revertRow.revertButtonItem.visible)
            revertRow.activateReset()
            compare(resetState.count, 1)
            revertRow.currentValue = 5
            verify(revertRow.isDefault)
            verify(!revertRow.revertVisible)
            verify(!revertRow.canReset)
            verify(!revertRow.revertButtonItem.visible)
            revertRow.defaultValue = undefined
            verify(!revertRow.hasDefault)
            verify(!revertRow.revertVisible)
        }
    }
}