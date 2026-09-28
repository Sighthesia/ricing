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

    // Empty parking spot for the test pointer. Hover state is sticky between
    // test functions (a HoverHandler keeps reporting until the pointer moves
    // again), and it drives card colour, border width and `row.hovered` — so
    // init() parks the pointer here to make every non-hover test deterministic.
    Item { id: pointerPark; x: 20; y: 470; width: 20; height: 8 }

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
        id: choiceRow
        width: 520
        labelText: "配色方案"
        Lazer.LazerSettingsChoice {
            id: rowChoice
            model: [{ value: "auto", label: "自动" }]
            currentValue: "auto"
        }
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

    Lazer.LazerSettingsRow {
        id: resetTextRow
        width: 520
        labelText: "壁纸路径"
        defaultValue: "default.png"
        currentValue: textHolder.value
        resetCallback: function() { resetState.count++ }
        Lazer.LazerSettingsTextField {
            id: resetTextField
            text: textHolder.value
        }
    }

    // Park the standalone controls in their own column, clear of every row.
    // Left at the default (0, 0) they stack on top of `row`/`revertRow` and
    // their own HoverHandlers win, so the rows below never see a hover — a
    // fixture-geometry artifact that reads exactly like a product bug.
    Item {
        x: 600
        y: 0
        width: 150
        height: 460

        Lazer.LazerSettingsToggle {
            id: toggle
            checked: toggleHolder.value
            onToggled: next => toggleHolder.value = next
        }
        Lazer.LazerSettingsSlider {
            id: slider
            y: 30
            from: 0
            to: 10
            stepSize: 2
            suffix: "%"
            value: sliderHolder.value
            defaultValue: 2
            onValueModified: next => sliderHolder.value = next
        }
        Lazer.LazerSettingsSlider { id: secondSlider; y: 70; value: 2 }
        Lazer.LazerSettingsChoice {
            id: choice
            y: 110
            model: [
                { value: "auto", label: "自动" },
                { value: "dark", label: "深色模式" }
            ]
            currentValue: choiceHolder.value
            onValueSelected: next => choiceHolder.value = next
        }
        Lazer.LazerSettingsTextField {
            id: textField
            y: 180
            text: textHolder.value
            placeholderText: "壁纸路径"
            onTextCommitted: next => textHolder.value = next
            onClearRequested: textHolder.value = ""
        }
        Lazer.LazerSettingsTextField { id: secondTextField; y: 220; text: "second" }
        Lazer.LazerSettingsToggle { id: invalidWidthToggle; y: 260; availableWidth: -20 }
        Lazer.LazerSettingsSlider { id: invalidWidthSlider; y: 290; availableWidth: NaN }
    }

    SignalSpy { id: toggleSpy; target: toggle; signalName: "toggled" }
    SignalSpy { id: sliderSpy; target: slider; signalName: "valueModified" }
    SignalSpy { id: revertRowSliderSpy; target: revertRowSlider; signalName: "valueModified" }
    SignalSpy { id: choiceSpy; target: choice; signalName: "valueSelected" }
    SignalSpy { id: commitSpy; target: textField; signalName: "textCommitted" }
    SignalSpy { id: clearSpy; target: textField; signalName: "clearRequested" }
    SignalSpy { id: dropdownSpy; target: Lazer.SettingsOverlayBridge; signalName: "dropdownRequested" }
    SignalSpy { id: dropdownDismissSpy; target: Lazer.SettingsOverlayBridge; signalName: "dropdownDismissed" }

    TestCase {
        name: "LazerSettingsControls"

        // Generous ceiling for every try* below: the longest Behaivour in play
        // is MotionTokens.slow (240ms) plus a searchExitDelay pause.
        readonly property int settleTimeout: 3000

        function init() {
            // Re-stack every row. init() runs before each function, and
            // test_choiceRowReservesMenuHeightAndTogglesClosed deliberately
            // moves choiceRow to y 0; a row left stacked on top of another
            // shadows the one below it (its reset strip swallows the click, its
            // hover handlers starve the other row's), which reads as a product
            // bug but is pure fixture pollution.
            row.y = 20
            revertRow.y = 80
            compactRow.y = 150
            choiceRow.y = 280
            resetTextRow.y = 380
            // Park the pointer on empty host space so a previous test's hover
            // cannot tint a card or report `hovered` in the next one.
            mouseMove(pointerPark, pointerPark.width / 2, pointerPark.height / 2)
            // init() only resets what it lists. A test function that mutates a
            // row's `enabled`, leaves a choice menu open, leaves a Qt.binding on
            // a control's requestedWidth, or writes slider.defaultValue poisons
            // every function that runs after it — so reset all of them here.
            row.enabled = true
            revertRow.enabled = true
            choiceRow.enabled = true
            compactRow.enabled = true
            // test_rowWidthBindingRemainsOwnedByParent installs a permanent
            // Qt.binding on requestedWidth; drop it back to the implicit width.
            rowToggle.requestedWidth = rowToggle.implicitWidth
            rowChoice.menuOpen = false
            toggle.enabled = true
            toggleHolder.value = false
            toggleSpy.clear()
            slider.enabled = true
            slider.from = 0
            slider.to = 10
            slider.stepSize = 2
            slider.requestedWidth = slider.implicitWidth
            // test_sliderDoubleClickRestoresDefault writes `undefined` here and
            // never restores it, which makes every later resetToDefault() a
            // no-op and leaves flashActive permanently dark.
            slider.defaultValue = 2
            sliderHolder.value = 4
            slider.focus = false
            slider.flashAnimationItem.stop()
            slider.flashOverlayItem.opacity = 0
            slider.bumpAnimationItem.stop()
            slider.bumpScale = 1
            secondSlider.focus = false
            sliderSpy.clear()
            revertRowSliderSpy.clear()
            revertRow.defaultValue = 5
            revertRow.currentValue = 7
            choice.enabled = true
            choiceHolder.value = "auto"
            choiceSpy.clear()
            choice.menuOpen = false
            dropdownSpy.clear()
            dropdownDismissSpy.clear()
            textField.enabled = true
            textField.focus = false
            textField.editorItem.focus = false
            textHolder.value = "  wallpaper.png  "
            commitSpy.clear()
            clearSpy.clear()
            resetState.count = 0
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
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
            compare(toggle.implicitWidth, 44)
            compare(toggle.implicitHeight, 20)
            verify(toggle.nubItem)
            toggle.checked = false
            // The capsule colour runs a `Behavior on color`, so reading it in the
            // same turn as the `checked` flip still returns the previous colour.
            tryCompare(toggle.nubItem, "color", Lazer.LazerTheme.settingsToggleOff, settleTimeout)
            toggle.checked = true
            tryCompare(toggle.nubItem, "color", Lazer.LazerTheme.settingsAccent, settleTimeout)
            Lazer.MotionTokens.reducedMotionOverride = true
            compare(toggle.nubMorphEnabled, false)
            compare(toggle.fillWidth, false)
        }

        function test_toggleRowCentersControlAndReservesRightResetSlot() {
            var capsuleCenter = rowToggle.nubItem.mapToItem(row, rowToggle.nubItem.width / 2,
                                                            rowToggle.nubItem.height / 2)
            var contentCenter = row.contentItem.mapToItem(row, row.contentItem.width / 2,
                                                          row.contentItem.height / 2)
            verify(Math.abs(capsuleCenter.y - contentCenter.y) < 0.1)
            var labelCenter = row.labelTextItem.mapToItem(row, row.labelTextItem.width / 2,
                                                          row.labelTextItem.height / 2)
            verify(Math.abs(labelCenter.y - capsuleCenter.y) < 0.1)
            compare(row.labelTextItem.height, row.contentItem.height)
            verify(rowToggle.x + rowToggle.width <= row.width - row.contentPadding - row.revertZoneWidth)
            verify(!row.revertButtonItem.visible)
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

        function test_sliderTickFlashStartsOnlyForChangedStep() {
            compare(slider.flashActive, false)
            compare(slider.flashOverlayItem.opacity, 0)
            compare(slider.flashOverlayItem.width, slider.trackFillItem.width)
            compare(slider.flashOverlayItem.height, slider.trackItem.height)
            compare(slider.flashOverlayItem.x, slider.trackFillItem.x)

            slider.setValue(6)
            verify(slider.flashActive)
            verify(slider.bumpActive)
            compare(slider.bumpScale, Lazer.MotionTokens.sliderTickBumpScale)
            compare(slider.flashAnimationItem.duration, 800)
            compare(slider.flashAnimationItem.easing.type, Easing.OutQuint)
            compare(slider.bumpAnimationItem.duration, 220)
            compare(slider.bumpAnimationItem.easing.type, Easing.OutQuint)

            slider.flashAnimationItem.stop()
            slider.flashOverlayItem.opacity = 0
            slider.bumpAnimationItem.stop()
            slider.bumpScale = 1
            slider.setValue(6)
            compare(slider.flashActive, false)
            compare(slider.bumpActive, false)
        }

        function test_sliderTickFlashUsesResetPathAndReducedMotion() {
            sliderHolder.value = 8
            slider.resetToDefault()
            verify(slider.flashActive)

            slider.flashAnimationItem.stop()
            slider.flashOverlayItem.opacity = 0
            slider.bumpAnimationItem.stop()
            slider.bumpScale = 1
            sliderHolder.value = 8
            Lazer.MotionTokens.reducedMotionOverride = true
            slider.resetToDefault()
            compare(slider.flashActive, false)
            compare(slider.bumpActive, false)
            compare(slider.bumpScale, 1)
            compare(slider.flashOverlayItem.opacity, 0)
            compare(slider.flashAnimationItem.running, false)
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

        function test_sliderDefaultMarkerAndFullHeightThumb() {
            slider.defaultValue = 2
            sliderHolder.value = 4
            // Away from the default value the marker is a short pip; at the
            // default it swells into the active thumb's full-height slot.
            // The height is Behavioured, and the radius follows its own height
            // (`radius: height / 2`), so assert that relationship rather than
            // copying the pixel constants a retune would desync.
            verify(slider.defaultMarkerVisible)
            compare(slider.defaultMarkerItem.width, 4)
            compare(slider.defaultMarkerItem.color, "#d5ccff")
            compare(slider.nubItem.height, slider.trackItem.height)
            compare(slider.nubItem.width, 10)
            // The thumb's horizontal profile is a pill. The product hardcodes
            // radius 5 for a 10px-wide thumb, so the invariant worth locking is
            // "never rounder than half its own width" — asserting radius ==
            // width/2 would encode a coincidence as a derivation and break for
            // the wrong reason the day the thumb is resized.
            verify(slider.nubItem.radius <= slider.nubItem.width / 2)
            compare(slider.thumbColor, Lazer.LazerTheme.settingsSliderThumb)
            verify(slider.thumbColor !== Lazer.LazerTheme.settingsAccent)
            // The marker doubles as the light thumb only while the value sits
            // on the default; elsewhere there is no thumb light at all.
            verify(slider.thumbLightItem === null)
            verify(slider.defaultMarkerItem.z > slider.nubItem.z)
            verify(slider.nubItem.z > slider.trackItem.z)
            compare(slider.defaultMarkerItem.height, 6)
            compare(slider.defaultMarkerItem.radius, slider.defaultMarkerItem.height / 2)

            sliderHolder.value = 2
            // On the default value the marker reaches the track's inner height
            // (track height minus its 10px inset) — read it after the Behavior.
            tryCompare(slider.defaultMarkerItem, "height", slider.trackItem.height - 10, settleTimeout)
            compare(slider.defaultMarkerItem.radius, slider.defaultMarkerItem.height / 2)
            verify(slider.thumbLightItem === slider.defaultMarkerItem)

            sliderHolder.value = 4
            tryCompare(slider.defaultMarkerItem, "height", 6, settleTimeout)
            compare(slider.defaultMarkerItem.radius, slider.defaultMarkerItem.height / 2)
            verify(slider.thumbLightItem === null)
        }

        function test_choiceRowReservesMenuHeightAndTogglesClosed() {
            choiceRow.y = 0
            choiceRow.width = 520
            rowChoice.openMenu()
            wait(0)
            // The reserved height is the option list the control is about to
            // paint. LazerSettingsChoice derives it from the model length and
            // clamps it at the shared dropdownMaxHeight token, so assert that
            // relationship instead of the pixel literal it happens to be today.
            compare(rowChoice.menuReservedHeight, rowChoice.optionListHeight)
            verify(rowChoice.optionListHeight < Lazer.LazerTheme.dropdownMaxHeight,
                   "a one-entry list must stay under the max-height cap")
            // The row grows to whatever the control reserved (header + list +
            // its own gaps) and keeps the row's list gap on top of that.
            compare(choiceRow.implicitHeight, rowChoice.implicitHeight)
            tryCompare(choiceRow, "height", rowChoice.height + choiceRow.listGap, settleTimeout)
            compare(rowChoice.y, 0)
            choiceRow.y = 280

            // A list long enough to overflow must clamp at the token, not grow
            // without bound. Re-assigning `model` drops the fixture's literal
            // binding, so put the original single-entry list back afterwards.
            var longModel = []
            for (var i = 0; i < 20; ++i)
                longModel.push({ value: "value" + i, label: "选项" + i })
            rowChoice.model = longModel
            compare(rowChoice.menuReservedHeight, Lazer.LazerTheme.dropdownMaxHeight)
            rowChoice.model = [{ value: "auto", label: "自动" }]
            compare(rowChoice.menuReservedHeight, rowChoice.optionListHeight)

            rowChoice.openMenu()
            compare(rowChoice.menuOpen, false)
            compare(rowChoice.menuReservedHeight, 0)
            tryCompare(choiceRow, "height", rowChoice.height + choiceRow.listGap, settleTimeout)
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

        function test_choiceUsesEmbeddedLabelPresentation() {
            compare(choice.implicitHeight, Lazer.LazerTheme.settingsChoiceHeight)
            compare(choice.headerItem.radius, Lazer.LazerTheme.settingsControlRadius)
            compare(choice.headerItem.color, Lazer.LazerTheme.settingsControlSurface)
            compare(choice.rowPresentation, "choice")
            compare(rowChoice.rowPresentation, "choice")
            // The Choice owns the label: the row's own Text is hidden and the
            // row hands it its labelText to render inside the header.
            verify(!choiceRow.labelTextItem.visible)
            compare(rowChoice.fieldLabel, "配色方案")
            compare(rowChoice.height, rowChoice.implicitHeight)
            compare(rowChoice.y, 0)
            // The Choice header *is* the card: it fills the content column and
            // the row paints no card surface behind it (cardItem is
            // `visible: !choicePresentation`), so there is no card geometry here.
            verify(!choiceRow.cardItem.visible, "choice rows must not paint a card surface")
            var surfaceOrigin = rowChoice.surfaceItem.mapToItem(rowChoice, 0, 0)
            verify(Math.abs(surfaceOrigin.x) < 0.1, "the choice surface starts at the row edge")
            // The Choice fills the row's content column: LazerSettingsRow binds
            // a fillWidth control's requestedWidth to contentHost.width.
            // The row binds a fillWidth control's requestedWidth to its own
            // contentHost.width, so the Choice exactly fills the content column.
            compare(rowChoice.width, choiceRow.contentItem.width)
            compare(rowChoice.surfaceItem.width, rowChoice.width)
        }

        function test_choiceOpensRealDropdownInsteadOfCycling() {
            choiceHolder.value = "auto"
            choice.forceActiveFocus()
            keyPress(Qt.Key_Right)
            compare(choiceHolder.value, "auto")
            keyPress(Qt.Key_Enter)
            compare(choice.menuOpen, true)
            verify(String(choice.chevronItem.source).indexOf("chevron-up.svg") !== -1)
            keyPress(Qt.Key_Space)
            compare(choice.menuOpen, false)
            verify(String(choice.chevronItem.source).indexOf("chevron-down.svg") !== -1)
            choice.closeMenu()
            compare(choice.menuOpen, false)
            compare(choiceHolder.value, "auto")
            // No bridge assertion here on purpose: since d5721e73 the dropdown
            // paints itself inside the Choice's own tree, so
            // SettingsOverlayBridge.showDropdown/hideDropdown have no caller and
            // dropdownRequested/dropdownDismissed are never emitted by the
            // Choice. Spying on them can only ever report 0.
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
            // Inline rows render one line: the row's cardContentHeight for the
            // inline presentation is 44, not the 56px stacked minimum it used to
            // reserve. Assert the token-free floor the presentation guarantees.
            verify(row.implicitHeight >= 44)
            compare(row.compactLayout, false)
            compare(row.controlItem, rowToggle)
            compare(row.cardItem.color, Lazer.LazerTheme.settingsCard)
            compare(row.cardItem.radius, row.cardRadius)
            compare(row.cardItem.width, row.width)
            verify(row.textRegionWidth > 0)
            verify(row.labelTextItem.visible)
            verify(row.labelTextItem.width > 0)
            compare(row.labelTextItem.text, "设置")
            // The toggle's width and its host's x both run Behaviors, and init()
            // just reset requestedWidth, so wait for the capsule to land.
            tryVerify(function() { return rowToggle.width > 0 }, settleTimeout)
            tryCompare(rowToggle, "width", rowToggle.implicitWidth, settleTimeout)
            tryCompare(rowToggle, "height", rowToggle.implicitHeight, settleTimeout)
            // rowToggle.x is local to the row's internal control host, so map it
            // into the row before checking it against the row's own budget.
            tryVerify(function() {
                var left = rowToggle.mapToItem(row, 0, 0).x
                return left >= 0 && left + rowToggle.width <= row.width - row.contentPadding
            }, settleTimeout)
            row.enabled = false
            // Row opacity fades through a Behavior, so the disabled alpha only
            // reads true once the fade has finished.
            tryCompare(row, "opacity", Lazer.LazerTheme.settingsDisabledAlpha, settleTimeout)
            compare(row.contentEnabled, false)
            compare(rowToggle.rowEnabled, false)
            compare(choice.activeFocusOnTab, true)
            choice.enabled = false
            compare(choice.activeFocusOnTab, false)
            compare(plainRow.controlSupportsRowEnabled, false)
        }

        function test_toggleAndSliderExposeRowPresentationContracts() {
            compare(rowToggle.rowPresentation, "inline")
            compare(slider.rowPresentation, "split")
            compare(row.rowPresentation, "inline")
            compare(revertRow.rowPresentation, "split")
            // rowToggle.x is local to the row's control host, so the right-hand
            // budget has to be checked in row coordinates. The host's x and the
            // capsule's width are both Behavioured: read once they have settled.
            tryVerify(function() {
                var left = rowToggle.mapToItem(row, 0, 0).x
                return left + rowToggle.width <= row.width - row.contentPadding
            }, settleTimeout)
            verify(revertRowSlider.width >= 200)
            verify(revertRowSlider.width <= 240)
            compare(revertRowSlider.trackItem.height, 30)
            verify(revertRowSlider.trackItem.height > 26)
            compare(revertRowSlider.trackItem.radius, 4)
            compare(revertRowSlider.trackItem.color, Lazer.LazerTheme.settingsTrack)
            compare(revertRowSlider.trackFillItem.color, Lazer.LazerTheme.settingsAccent)
            compare(revertRowSlider.nubItem.width, 10)
            compare(revertRowSlider.nubItem.height, revertRowSlider.trackItem.height)
            verify(revertRowSlider.nubItem.radius <= revertRowSlider.nubItem.width / 2)
            compare(revertRowSlider.nubItem.color, Lazer.LazerTheme.settingsSliderThumb)
            verify(revertRowSlider.nubItem.color !== Lazer.LazerTheme.settingsAccent)
            verify(revertRowSlider.nubItem !== null)
            compare(revertRowSlider.height, revertRowSlider.implicitHeight)
            verify(revertRow.valueTextItem.visible)
            // The split row's value text sits on a 10px bottom inset. Item.bottom
            // is a QQuickAnchorLine (the anchor), not the edge coordinate, so
            // read the edge as y + height.
            compare(revertRow.contentItem.height
                    - (revertRow.valueTextItem.y + revertRow.valueTextItem.height), 10)
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
            // A filtered-out row collapses height, opacity and x through
            // Behaviors, so it keeps painting (and reading `visible: true`)
            // until that exit geometry has actually landed.
            tryVerify(function() { return !row.visible }, settleTimeout)
            tryCompare(row, "height", 0, settleTimeout)
            row.searchQuery = ""
            tryVerify(function() { return row.visible }, settleTimeout)
            tryVerify(function() { return row.height > 0 }, settleTimeout)
            row.enabled = false
            row.searchQuery = "设置"
            verify(row.matchesSearch)
            verify(row.searchVisible)
            verify(row.visible)
            verify(!row.contentEnabled)
            row.enabled = true
            row.searchQuery = ""
        }

        function test_rowHoverCoversLabelAndControlRegions() {
            row.searchQuery = ""
            wait(0)

            compare(row.rowHoverBlocking, false)
            mouseMove(row, 24, 12)
            // HoverHandlers only report the new point after an event-loop turn.
            tryVerify(function() { return row.hovered }, settleTimeout)

            mouseMove(row, row.controlRegionLeft + row.textRegionWidth - 24, row.height / 2)
            tryVerify(function() { return row.hovered }, settleTimeout)
            // The accent border width is Behavioured, so read it after the
            // highlight animation has landed. `border` is a grouped property:
            // tryCompare only resolves a plain property path, so poll the value
            // expression instead.
            tryVerify(function() { return row.cardItem.border.width === 1.5 }, settleTimeout)
        }

        function test_rowHoverCoversTextFieldAndChoiceControls() {
            compactRow.searchQuery = ""
            choiceRow.searchQuery = ""
            wait(0)

            mouseMove(compactRow, compactTextField.width / 2,
                      compactTextField.mapToItem(compactRow, 0, compactTextField.height / 2).y)
            verify(compactRow.hovered)

            mouseMove(choiceRow, rowChoice.width / 2, rowChoice.height / 2)
            verify(choiceRow.hovered)
            // No card assertion for the choice row: its cardItem is
            // `visible: !choicePresentation`, so nothing is painted and there
            // is no visible card whose border could be measured. The `hovered`
            // check above is the row's real hover contract.
        }

        function test_rowBlankAreaDoesNotActivateItsControl() {
            var before = revertRowSliderSpy.count
            mouseClick(revertRow, 20, 12, Qt.LeftButton)
            compare(revertRowSliderSpy.count, before)
        }

        function test_textFieldOnlyFocusesFromItsOwnArea() {
            compactTextField.focus = false
            compactTextField.editorItem.focus = false
            mouseClick(compactRow, 12, 8, Qt.LeftButton)
            verify(!compactTextField.editorItem.activeFocus)

            mouseClick(compactTextField, compactTextField.width / 2,
                       compactTextField.height / 2, Qt.LeftButton)
            verify(compactTextField.editorItem.activeFocus)
        }

        function test_choiceHeaderFocusesBeforeOpeningMenu() {
            rowChoice.focus = false
            rowChoice.menuOpen = false
            mouseClick(rowChoice, rowChoice.width / 2, rowChoice.height / 2, Qt.LeftButton)
            verify(rowChoice.activeFocus)
            verify(rowChoice.menuOpen)
            rowChoice.closeMenu()
        }

        function test_compactRowStacksTextAndControl() {
            compare(compactRow.compactLayout, true)
            verify(compactRow.textRegionWidth > 0)
            // A full-width field fills the row's padded content column, so the
            // budget is the row's own padding, not a copied pixel constant.
            compare(compactTextField.width, compactRow.width - compactRow.contentPadding * 2)
            verify(compactTextField.x >= 0)
            verify(compactTextField.x + compactTextField.width <= compactRow.width - 16)
            verify(compactRow.labelTextItem.bottom <= compactTextField.top)
            verify(compactRow.height >= compactRow.implicitHeight)
        }

        function test_rowWidthBindingRemainsOwnedByParent() {
            var holder = Qt.createQmlObject('import QtQuick; QtObject { property real value: 300 }', row)
            rowToggle.requestedWidth = Qt.binding(function() { return holder.value })
            compare(rowToggle.requestedWidth, 300)
            tryVerify(function() { return rowToggle.width <= row.width - 32 }, settleTimeout)
            holder.value = 180
            compare(rowToggle.requestedWidth, 180)
            // requestedWidth updates instantly, but the capsule's own
            // `Behavior on width` needs the event loop to reach 180.
            tryCompare(rowToggle, "width", 180, settleTimeout)
            // Undo the binding so it does not outlive this test function.
            rowToggle.requestedWidth = rowToggle.implicitWidth
            holder.destroy()
        }

        function test_rowShowsRevertUntilValueMatchesDefault() {
            verify(revertRow.hasDefault)
            verify(!revertRow.isDefault)
            verify(revertRow.revertVisible)
            verify(revertRow.canReset)
            verify(revertRow.revertButtonItem.visible)
            // The reset control is a strip that slides out from under the card's
            // rounded right edge and spans the whole row body — it is not a
            // small button floating in the row's vertical centre.
            compare(revertRow.revertButtonItem.width, revertRow.revertZoneWidth + revertRow.cardRadius)
            compare(revertRow.revertButtonItem.height, revertRow.bodyHeight)
            compare(revertRow.revertButtonItem.children[0].topRightRadius, revertRow.cardRadius)
            compare(revertRow.revertButtonItem.children[0].bottomRightRadius, revertRow.cardRadius)
            tryCompare(revertRow.revertButtonItem.children[0], "color",
                       Lazer.LazerTheme.settingsResetSurface, settleTimeout)
            tryCompare(revertRow.revertButtonItem, "x", revertRow.revertVisibleX, settleTimeout)
            compare(revertRow.revertButtonItem.x + revertRow.revertButtonItem.width,
                    revertRow.width)
            // The strip sits below the card so it reads as tucked behind it.
            verify(revertRow.revertButtonItem.z < revertRow.cardItem.z)
            // The strip owns its own hover: pointing at the row body highlights
            // the row, pointing at the strip does not (the row's highlight stops
            // at revertVisibleX). Assert both directions rather than comparing
            // against whatever hover state the previous test function left.
            mouseMove(revertRow, 200, 20)
            tryVerify(function() { return revertRow.rowHovered }, settleTimeout)
            mouseMove(revertRow.revertButtonItem, revertRow.revertButtonItem.width / 2,
                      revertRow.revertButtonItem.height / 2)
            tryVerify(function() { return !revertRow.rowHovered }, settleTimeout)
            var sliderRight = revertRowSlider.mapToItem(revertRow, revertRowSlider.width, 0).x
            verify(sliderRight <= revertRow.revertButtonItem.x + revertRow.cardRadius)
            var beforeSliderSignals = revertRowSliderSpy.count
            mouseClick(revertRow.revertButtonItem,
                       revertRow.revertButtonItem.width / 2,
                       revertRow.revertButtonItem.height / 2,
                       Qt.LeftButton)
            compare(resetState.count, 1)
            compare(revertRowSliderSpy.count, beforeSliderSignals)
            revertRow.activateReset()
            compare(resetState.count, 2)
            revertRow.currentValue = 5
            wait(250)
            verify(revertRow.isDefault)
            verify(!revertRow.revertVisible)
            verify(!revertRow.canReset)
            // Once the value matches the default the strip slides back behind
            // the card edge and stops being visible at all.
            tryCompare(revertRow.revertButtonItem, "x", revertRow.revertHiddenX, settleTimeout)
            verify(!revertRow.revertButtonItem.visible)
            verify(revertRow.revertButtonItem.x + revertRow.revertButtonItem.width
                   <= revertRow.cardItem.x + revertRow.cardItem.width)
            revertRow.defaultValue = undefined
            verify(!revertRow.hasDefault)
            verify(!revertRow.revertVisible)
            verify(!revertRow.revertButtonItem.visible)
        }

        // The reset control is a full-height strip flush with the row's right
        // edge; a0ae4159 removed the old vertically-centred-button formula, so
        // assert the strip's span rather than a centring relationship.
        function test_textFieldResetButtonSpansFullRowHeight() {
            verify(resetTextRow.revertButtonItem.visible)
            compare(resetTextRow.revertButtonItem.height, resetTextRow.bodyHeight)
            compare(resetTextRow.revertButtonItem.height, resetTextRow.height - resetTextRow.listGap)
            compare(resetTextRow.revertButtonItem.children[0].topRightRadius, resetTextRow.cardRadius)
            compare(resetTextRow.revertButtonItem.children[0].bottomRightRadius, resetTextRow.cardRadius)
            tryCompare(resetTextRow.revertButtonItem, "x", resetTextRow.revertVisibleX, settleTimeout)
            compare(resetTextRow.revertButtonItem.x + resetTextRow.revertButtonItem.width,
                    resetTextRow.width)
            // The field keeps the row's own padded budget; the strip does not
            // eat into it.
            var fieldRight = resetTextField.mapToItem(resetTextRow, resetTextField.width, 0).x
            verify(fieldRight <= resetTextRow.revertButtonItem.x)
        }
    }
}
