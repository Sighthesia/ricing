import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Provide isolated settings dependencies for the persistent panel contract.
Item {
    width: 960
    height: 640

    QtObject { id: appearanceSettings; property string wallpaperPath: ""; property string colorScheme: "auto"; property real panelOpacity: 0.9; property bool enableBlur: true; property real blurSurfaceOpacity: 0.35; property real glassHighlightIntensity: 0.56; property real glassGlowIntensity: 0.22; property bool glassThemeAdaptive: true; property bool ripplePulseEnabled: true }
    QtObject { id: barSettings; property int height: 48; property string position: "top"; property bool floating: false; property int floatingMargin: 4; property int cornerRadius: 12 }
    QtObject { id: notificationSettings; property int maxVisible: 3; property int timeout: 5000; property string position: "top-right"; property bool dnd: false }
    QtObject { id: wallpaperService; function changeWallpaper(path) {} }
    QtObject { id: saveService; property int count: 0; function save() { count++ } }
    QtObject { id: firstActivity; property bool tooltipActive: false }
    QtObject { id: secondActivity; property bool tooltipActive: false }
    QtObject { id: sliderActivity; property bool tooltipActive: false }
    QtObject {
        id: resetService
        property int count: 0
        property string category: ""
        property string key: ""
        property var value: undefined
        function reset(nextCategory, nextKey, nextValue) {
            count++
            category = nextCategory
            key = nextKey
            value = nextValue
            if (nextCategory === "bar" && nextKey === "height")
                barSettings.height = nextValue
        }
    }

    Lazer.LazerSettingsPanel {
        id: panel
        width: 570
        height: 560
        availableWidth: 570
        availableHeight: 560
        sidePanel: true
        progress: 1
        appearanceSettings: appearanceSettings
        barSettings: barSettings
        notificationSettings: notificationSettings
        saveCallback: saveService.save
        wallpaperService: wallpaperService
        appearanceDefaults: ({ panelOpacity: 0.9 })
        barDefaults: ({ height: 48 })
        notificationDefaults: ({ timeout: 5000 })
        settingsReset: resetService.reset
    }
    Lazer.LazerSettingsChoice {
        id: externalChoice
        model: [{ value: "outside", label: "Outside" }]
        currentValue: "outside"
    }
    SignalSpy { id: closeSpy; target: panel; signalName: "closeRequested" }
    SignalSpy { id: categorySpy; target: panel; signalName: "categoryChanged" }

    TestCase {
        name: "LazerSettingsPanel"

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            Lazer.SettingsOverlayBridge.clearTooltips()
            panel.content.hideTooltip()
            panel.interactive = true
            panel.selectedCategory = "appearance"
            panel.sidebarExpanded = true
            panel.searchQuery = ""
            panel.progress = 1
            panel.width = 570
            panel.height = 560
            panel.availableWidth = 570
            panel.availableHeight = 560
            panel.appearancePage.contentY = 0
            panel.barPage.contentY = 0
            panel.notificationPage.contentY = 0
            barSettings.height = 48
            resetService.count = 0
            resetService.category = ""
            resetService.key = ""
            resetService.value = undefined
            firstActivity.tooltipActive = false
            secondActivity.tooltipActive = false
            sliderActivity.tooltipActive = false
            closeSpy.clear()
            categorySpy.clear()
            wait(20)
        }

        function cleanup() { Lazer.MotionTokens.reducedMotionOverride = false }

        function movePointerTo(item) {
            var point = item.mapToItem(panel.content, item.width / 2, item.height / 2)
            mouseMove(panel.content, point.x, point.y)
            wait(20)
        }

        function movePointerAway() {
            mouseMove(panel.content, 2, panel.content.height - 2)
            wait(20)
        }

        function test_keepsAllPagesAliveAndInjectsDependencies() {
            verify(panel.appearancePage)
            verify(panel.barPage)
            verify(panel.notificationPage)
            compare(panel.appearancePage.settingsObject, appearanceSettings)
            compare(panel.barPage.settingsObject, barSettings)
            compare(panel.notificationPage.settingsObject, notificationSettings)
            compare(panel.appearancePage.wallpaperService, wallpaperService)
            compare(panel.appearancePage.saveCallback, saveService.save)
            compare(panel.appearancePage.defaults.panelOpacity, 0.9)
            compare(panel.barPage.defaults.height, 48)
            compare(panel.notificationPage.defaults.timeout, 5000)
            compare(panel.notificationPage.timeoutSlider.defaultValue, 5)
        }

        function test_resetWrapperPreservesCategoryAndCanonicalDefault() {
            barSettings.height = 60
            verify(panel.barPage.heightRow.revertVisible)
            panel.barPage.heightRow.activateReset()
            compare(resetService.count, 1)
            compare(resetService.category, "bar")
            compare(resetService.key, "height")
            compare(resetService.value, 48)
            compare(barSettings.height, 48)
            verify(!panel.barPage.heightRow.revertVisible)
        }

        function test_layersAreIndependentAndMatchOsuGeometry() {
            compare(panel.panelWidth, 570)
            compare(panel.sidebarWidth, 170)
            compare(panel.contentWidth, 400)
            compare(panel.sidebarLayerX, 0)
            compare(panel.contentLayerX, 170)
            compare(panel.sidebar.width, 170)
            compare(panel.content.width, 400)
            compare(panel.navigationWidth, panel.railWidth)
            compare(panel.indicatorCount, 3)
            verify(panel.sidebar.z > panel.content.z)
            verify(panel.appearanceNav.selected)
            verify(!panel.barNav.selected)
            verify(!panel.notificationNav.selected)
            compare(panel.appearanceNav.selectionIndicatorItem.height, 24)
            compare(panel.appearanceNav.selectionIndicatorItem.color, Lazer.LazerTheme.settingsAccent)
            compare(panel.barNav.selectionIndicatorItem.height, 0)
            compare(panel.barNav.labelItem.color, Lazer.LazerTheme.settingsNavInactive)
        }

        function test_contentChromeUsesSingleTitleAndBorderlessSearchSurface() {
            compare(panel.content.searchField.text, "")
            compare(panel.content.searchSurfaceItem.color, Lazer.LazerTheme.settingsSearchSurface)
            compare(panel.content.searchSurfaceItem.border.width, 0)
            compare(panel.content.searchSurfaceItem.radius, 6)
        }

        function test_midOpenLayersOccupyDifferentPositions() {
            panel.progress = 0.5
            compare(panel.sidebarLayerX, -85)
            compare(panel.contentLayerX, -200)
            verify(panel.sidebarLayerX < 0)
            verify(panel.contentLayerX < panel.sidebarLayerX)
        }

        function test_collapseShrinksSidebarAndKeepsContentUsable() {
            Lazer.MotionTokens.reducedMotionOverride = true
            panel.toggleExpanded()
            compare(panel.sidebarExpanded, false)
            compare(panel.sidebarWidth, 70)
            compare(panel.contentWidth, 400)
            compare(panel.sidebar.width, 70)
            compare(panel.contentLayerX, 70)
            compare(appearanceSettings.panelOpacity, 0.9)
            compare(panel.selectedCategory, "appearance")
            verify(panel.appearancePage.enabled)
            panel.toggleExpanded()
            compare(panel.sidebarWidth, 170)
            compare(panel.contentLayerX, 170)
            panel.sidebarExpanded = true
        }

        function test_openSessionDefaultsExpandedAndClearsSearch() {
            panel.searchQuery = "模糊"
            panel.sidebarExpanded = false
            panel.beginSession()
            compare(panel.sidebarExpanded, true)
            compare(panel.searchQuery, "")
        }

        function test_switchKeepsScrollPositionAndDisablesHiddenPages() {
            panel.appearancePage.contentY = 36
            panel.selectCategory("bar")
            compare(panel.appearancePage.contentY, 36)
            verify(!panel.appearancePage.enabled)
            verify(panel.barPage.enabled)
            verify(!panel.notificationPage.enabled)
            tryCompare(panel.barPage, "opacity", 1, 300)
            panel.selectCategory("notifications")
            verify(panel.notificationPage.enabled)
            verify(!panel.barPage.enabled)
        }

        function test_searchFiltersCurrentPageAndShowsEmptyState() {
            panel.searchQuery = "模糊"
            compare(panel.appearancePage.visibleResultCount, 2)
            verify(!panel.appearancePage.wallpaperRow.visible)
            verify(panel.content.emptyStateVisible === false)
            panel.searchQuery = "zzz-no-match"
            compare(panel.appearancePage.visibleResultCount, 0)
            verify(panel.content.emptyStateVisible)
            panel.searchQuery = ""
            compare(panel.appearancePage.visibleResultCount, 9)
            verify(!panel.content.emptyStateVisible)
        }

        function test_searchSurvivesCategorySwitch() {
            panel.searchQuery = "浮动"
            panel.selectCategory("bar")
            compare(panel.barPage.visibleResultCount, 2)
            verify(!panel.barPage.heightRow.visible)
            panel.selectCategory("appearance")
            compare(panel.appearancePage.visibleResultCount, 0)
            verify(panel.content.emptyStateVisible)
            panel.searchQuery = ""
        }

        function test_keyboardNavigationAndEscapeAreInteractiveGated() {
            panel.focusNavigation()
            keyPress(Qt.Key_Down)
            compare(panel.selectedCategory, "bar")
            keyPress(Qt.Key_Down)
            compare(panel.selectedCategory, "notifications")
            keyPress(Qt.Key_Up)
            compare(panel.selectedCategory, "bar")
            keyPress(Qt.Key_Enter)
            compare(panel.selectedCategory, "bar")
            panel.interactive = false
            keyPress(Qt.Key_Down)
            compare(panel.selectedCategory, "bar")
            panel.interactive = true
            closeSpy.clear()
            panel.requestClose()
            compare(closeSpy.count, 1)
        }

        function test_crossfadeUsesReducedMotionOnlyForTranslation() {
            panel.selectedCategory = "appearance"
            panel.syncPages(0, 0)
            panel.selectCategory("bar")
            wait(80)
            verify(panel.barPage.opacity > 0 && panel.appearancePage.opacity < 1)
            verify(panel.barPage.x > 0 && panel.barPage.x < 8)
            tryCompare(panel.appearancePage, "opacity", 0, 300)
            Lazer.MotionTokens.reducedMotionOverride = true
            panel.selectCategory("notifications")
            compare(panel.notificationPage.x, 0)
            compare(panel.categoryTransitionDuration, 160)
            compare(panel.contentTransitionEasing, Lazer.MotionTokens.outSoft)
        }

        function test_ownedStringContractAndInvalidDirectAssignmentRecovery() {
            panel.selectCategory("notifications")
            compare(panel.selectedIndex, 2)
            compare(categorySpy.count, 1)
            panel.selectedCategory = "invalid"
            tryCompare(panel, "selectedCategory", "appearance", 300)
            compare(panel.selectedIndex, 0)
            verify(panel.appearancePage.enabled)
            verify(!panel.notificationPage.enabled)
            panel.selectCategory("invalid")
            compare(panel.selectedCategory, "appearance")
        }

        function test_dimensionsStayNonNegativeAtExtremes() {
            panel.availableWidth = -100
            panel.availableHeight = -100
            verify(panel.panelWidth >= 0)
            verify(panel.panelHeight >= 0)
            verify(panel.sidebarWidth >= 0)
            verify(panel.contentWidth >= 0)
            verify(panel.width >= 0)
            verify(panel.height >= 0)
            panel.availableWidth = 1200
            panel.availableHeight = 900
            compare(panel.implicitWidth, panel.panelWidth)
            compare(panel.implicitHeight, panel.panelHeight)
        }

        function test_focusAndCloseControlsUseKeyboardContracts() {
            mouseClick(panel.barNav, panel.barNav.width / 2, panel.barNav.height / 2)
            compare(panel.selectedCategory, "bar")
            verify(panel.barNav.activeFocus)
            panel.focusFirstControl()
            verify(panel.activeFocus || panel.currentNav.activeFocus)
            panel.focusNavigation()
            verify(panel.currentNav.activeFocus)
            panel.requestClose()
            compare(closeSpy.count, 1)
        }

        function test_controlFocusHighlightsItsRow() {
            var row = panel.appearancePage.panelOpacityRow
            var slider = panel.appearancePage.panelOpacitySlider
            slider.forceActiveFocus()
            tryVerify(function() { return slider.activeFocus }, 200)
            tryVerify(function() { return row.cardItem.border.width > 0 }, 200)
        }

        function test_fastRetargetEndsAtLatestCategoryAndHiddenPagesAreInactive() {
            panel.selectCategory("bar")
            panel.selectCategory("notifications")
            tryCompare(panel, "selectedCategory", "notifications", 300)
            tryCompare(panel.notificationPage, "opacity", 1, 300)
            verify(!panel.appearancePage.enabled)
            verify(!panel.barPage.enabled)
            verify(panel.notificationPage.enabled)
            verify(!panel.appearancePage.activeFocus)
            verify(!panel.barPage.activeFocus)
        }

        function test_transitionTokenRejectsStaleCallLaterCallbacks() {
            panel.selectCategory("appearance")
            panel.selectCategory("bar")
            panel.selectCategory("notifications")
            wait(1)
            verify(panel.barPage.opacity < 1)
            compare(panel.selectedCategory, "notifications")
            tryCompare(panel.notificationPage, "opacity", 1, 300)
            compare(panel.barPage.opacity, 0)
        }

        function test_reducedMotionCanResumeCrossfade() {
            Lazer.MotionTokens.reducedMotionOverride = true
            panel.selectCategory("appearance")
            compare(panel.appearancePage.x, 0)
            Lazer.MotionTokens.reducedMotionOverride = false
            panel.selectCategory("bar")
            wait(80)
            verify(panel.barPage.opacity > 0 && panel.barPage.opacity < 1)
            verify(panel.appearancePage.opacity > 0 && panel.appearancePage.opacity < 1)
            tryCompare(panel.barPage, "opacity", 1, 300)
        }

        function test_dropdownOpensInContentAndSelects() {
            panel.contentReady = true
            panel.selectCategory("bar")
            var choice = panel.barPage.positionChoice
            choice.openMenu()
            verify(panel.content.dropdownVisible)
            verify(choice.menuOpen)
            verify(choice.headerItem.width > 0)
            panel.content.selectDropdownValue("bottom")
            compare(barSettings.position, "bottom")
            verify(!panel.content.dropdownVisible)
            verify(!choice.menuOpen)
            panel.contentReady = false
        }

        function test_dropdownIgnoresChoiceFromAnotherContentOwner() {
            panel.contentReady = true
            externalChoice.openMenu()
            verify(externalChoice.menuOpen)
            verify(!panel.content.dropdownVisible)
            externalChoice.closeMenu()
            panel.contentReady = false
        }

        function test_searchAndCategoryChangeCloseDropdown() {
            panel.contentReady = true
            panel.selectCategory("bar")
            var choice = panel.barPage.positionChoice
            choice.openMenu()
            verify(panel.content.dropdownVisible)
            panel.selectCategory("appearance")
            verify(!panel.content.dropdownVisible)
            panel.selectCategory("bar")
            choice.openMenu()
            verify(panel.content.dropdownVisible)
            panel.searchQuery = "位置"
            verify(!panel.content.dropdownVisible)
            panel.searchQuery = ""
            panel.contentReady = false
        }

        function test_navSelectionFollowsCategoryWhenReducedMotionChanges() {
            Lazer.MotionTokens.reducedMotionOverride = true
            panel.selectCategory("notifications")
            verify(panel.notificationNav.selected)
            verify(!panel.appearanceNav.selected)
            compare(panel.indicatorCount, 3)
            panel.selectCategory("appearance")
            verify(panel.appearanceNav.selected)
        }

        function test_tooltipShortTextShowsFullWidth() {
            panel.contentReady = true
            var row = panel.appearancePage.colorSchemeRow
            Lazer.SettingsOverlayBridge.showTooltip(row.descriptionText, row, 1)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, row)
            compare(panel.content.activeTooltipPriority, 1)
            // The surface follows the text's natural width, never a 24px stub.
            tryVerify(function() {
                var item = panel.content.tooltipItem
                var text = panel.content.tooltipTextItem
                return item.width > 24
                    && Math.abs(item.width - (text.implicitWidth + 12)) < 0.5
                    && text.implicitHeight <= 20
            }, 300)
            Lazer.SettingsOverlayBridge.hideTooltip(row)
            panel.contentReady = false
        }

        function test_tooltipLongTextWrapsAndExpandsHeight() {
            panel.contentReady = true
            var row = panel.appearancePage.colorSchemeRow
            var longText = "这是一段特别长的设置说明文字，用来验证悬浮提示在可用宽度内正确换行，并且整个提示表面按照换行后的高度完整扩展，文本绝对不会被父级裁切或重叠。"
            Lazer.SettingsOverlayBridge.showTooltip(longText, row, 1)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            tryVerify(function() {
                var item = panel.content.tooltipItem
                var text = panel.content.tooltipTextItem
                return item.width > 24
                    && item.width <= Lazer.LazerTheme.tooltipMaxWidth
                    && text.implicitHeight > 20
                    && Math.abs(item.height - (text.implicitHeight + 12)) < 0.5
            }, 300)
            verify(panel.content.tooltipItem.height > 40)
            // The text stays fully inside the padded surface.
            var text = panel.content.tooltipTextItem
            verify(text.x >= 0)
            verify(text.y >= 0)
            verify(text.y + text.height <= panel.content.tooltipItem.height)
            verify(text.x + text.width <= panel.content.tooltipItem.width)
            Lazer.SettingsOverlayBridge.hideTooltip(row)
            panel.contentReady = false
        }

        function test_tooltipClampsWithinContentBounds() {
            panel.contentReady = true
            var row = panel.appearancePage.colorSchemeRow
            Lazer.SettingsOverlayBridge.showTooltip(row.descriptionText, row, 1)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            tryVerify(function() {
                var item = panel.content.tooltipItem
                var bounds = panel.content.tooltipBoundsRect()
                return item.x >= bounds.x - 0.5
                    && item.x + item.width <= bounds.x + bounds.width + 0.5
                    && item.y >= bounds.y - 0.5
            }, 300)
            Lazer.SettingsOverlayBridge.hideTooltip(row)
            panel.contentReady = false
        }

        function test_tooltipFollowsScrollAndClosesWhenSourceLeavesViewport() {
            panel.contentReady = true
            var page = panel.appearancePage
            var row = panel.appearancePage.colorSchemeRow
            page.contentY = 0
            Lazer.SettingsOverlayBridge.showTooltip(row.descriptionText, row, 1)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            var y0 = panel.content.tooltipItem.y
            // A modest scroll keeps the source visible and the tooltip follows.
            page.contentY = 40
            tryVerify(function() { return panel.content.tooltipItem.y < y0 - 20 }, 200)
            verify(panel.content.tooltipVisible)
            // Scrolling the source fully out of the viewport closes the tooltip.
            page.contentY = page.contentHeight
            tryVerify(function() { return !panel.content.tooltipVisible }, 300)
            verify(!panel.content.tooltipVisible)
            Lazer.SettingsOverlayBridge.hideTooltip(row)
            page.contentY = 0
            panel.contentReady = false
        }

        function test_tooltipFlipsAboveAtBottomAndBelowAtTop() {
            panel.contentReady = true
            var page = panel.appearancePage
            var row = panel.appearancePage.glassGlowRow
            page.contentY = 0
            var topY = row.mapToItem(panel.content, 0, 0).y
            // Bring the row near the bottom of the viewport -> above wins.
            page.contentY = Math.max(0, topY - 430)
            tryVerify(function() { return row.mapToItem(panel.content, 0, 0).y >= 390 }, 300)
            Lazer.SettingsOverlayBridge.showTooltip(row.descriptionText, row, 1)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            tryVerify(function() { return panel.content.tooltipPlacementSide === "above" }, 300)
            // Scroll it back near the top -> below wins.
            page.contentY = Math.max(0, topY - 115)
            tryVerify(function() { return panel.content.tooltipPlacementSide === "below" }, 300)
            verify(panel.content.tooltipVisible)
            Lazer.SettingsOverlayBridge.hideTooltip(row)
            page.contentY = 0
            panel.contentReady = false
        }

        function test_sliderTooltipAnchorsToNubAndFollows() {
            panel.contentReady = true
            var slider = panel.appearancePage.panelOpacitySlider
            var nub = slider.nubItem
            slider.forceActiveFocus()
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, nub)
            compare(panel.content.activeTooltipPriority, 2)
            var x0 = panel.content.tooltipItem.x
            slider.setValue(0.35)
            tryVerify(function() { return panel.content.tooltipItem.x !== x0 }, 400)
            verify(panel.content.tooltipVisible)
            Lazer.SettingsOverlayBridge.hideTooltip(nub)
            panel.contentReady = false
        }

        function test_tooltipPrioritySliderOverridesRowAndFallsBack() {
            panel.contentReady = true
            var row = panel.appearancePage.panelOpacityRow
            var slider = panel.appearancePage.panelOpacitySlider
            Lazer.SettingsOverlayBridge.showTooltip(row.descriptionText, row, 1)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipText, row.descriptionText)
            // The slider value tooltip (priority 2) replaces the row description.
            Lazer.SettingsOverlayBridge.showTooltip("35%", slider.nubItem, 2)
            tryVerify(function() { return panel.content.activeTooltipSource === slider.nubItem }, 200)
            compare(panel.content.activeTooltipText, "35%")
            // Dismissing the slider falls back to the still-registered row request.
            Lazer.SettingsOverlayBridge.hideTooltip(slider.nubItem)
            tryVerify(function() { return panel.content.activeTooltipSource === row }, 200)
            compare(panel.content.activeTooltipText, row.descriptionText)
            Lazer.SettingsOverlayBridge.hideTooltip(row)
            tryVerify(function() { return !panel.content.tooltipVisible }, 300)
            panel.contentReady = false
        }

        function test_equalPriorityTooltipKeepsActiveOwnerAndFallsBackInOrder() {
            panel.contentReady = true
            var first = panel.appearancePage.colorSchemeRow
            var second = panel.appearancePage.wallpaperRow
            Lazer.SettingsOverlayBridge.showTooltip(first.descriptionText, first, 1)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, first)

            // A neighbouring row may become hovered before the first hover
            // fully clears; equal priority must not make the surface jump.
            Lazer.SettingsOverlayBridge.showTooltip(second.descriptionText, second, 1)
            compare(panel.content.activeTooltipSource, first)
            compare(panel.content.activeTooltipText, first.descriptionText)

            // Updating the active request changes its text without ownership churn.
            Lazer.SettingsOverlayBridge.showTooltip("更新后的说明", first, 1)
            compare(panel.content.activeTooltipSource, first)
            compare(panel.content.activeTooltipText, "更新后的说明")

            Lazer.SettingsOverlayBridge.hideTooltip(first)
            tryVerify(function() { return panel.content.activeTooltipSource === second }, 200)
            compare(panel.content.activeTooltipText, second.descriptionText)
            Lazer.SettingsOverlayBridge.hideTooltip(second)
            panel.contentReady = false
        }

        function test_tooltipIgnoresExternalOwner() {
            panel.contentReady = true
            // A request from a source outside this content never opens a tooltip.
            Lazer.SettingsOverlayBridge.showTooltip("外部来源说明", externalChoice, 1)
            verify(!panel.content.tooltipVisible)
            verify(!panel.content.activeTooltipSource)
            Lazer.SettingsOverlayBridge.hideTooltip(externalChoice)
            // An external high-priority request must not disturb the local tooltip.
            var row = panel.appearancePage.colorSchemeRow
            Lazer.SettingsOverlayBridge.showTooltip(row.descriptionText, row, 1)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            Lazer.SettingsOverlayBridge.showTooltip("外部高优先级", externalChoice, 5)
            verify(panel.content.tooltipVisible)
            compare(panel.content.activeTooltipSource, row)
            compare(panel.content.activeTooltipText, row.descriptionText)
            Lazer.SettingsOverlayBridge.hideTooltip(externalChoice)
            Lazer.SettingsOverlayBridge.hideTooltip(row)
            panel.contentReady = false
        }

        function test_tooltipReducedMotionStillPositionsAccurately() {
            Lazer.MotionTokens.reducedMotionOverride = true
            panel.contentReady = true
            var row = panel.appearancePage.colorSchemeRow
            Lazer.SettingsOverlayBridge.showTooltip(row.descriptionText, row, 1)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.tooltipItem.opacity, 1)
            verify(panel.content.tooltipItem.x >= 0)
            Lazer.SettingsOverlayBridge.hideTooltip(row)
            compare(panel.content.tooltipItem.visible, false)
            panel.contentReady = false
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_inactiveRowDoesNotReviveAfterSliderDismissal() {
            panel.contentReady = true
            var first = panel.appearancePage.colorSchemeRow
            var second = panel.appearancePage.wallpaperRow
            var slider = panel.appearancePage.panelOpacitySlider
            firstActivity.tooltipActive = true
            secondActivity.tooltipActive = true
            sliderActivity.tooltipActive = true
            Lazer.SettingsOverlayBridge.showTooltip(first.descriptionText, first, 1, firstActivity)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, first)
            // The adjacent row registers without displacing the stable owner.
            Lazer.SettingsOverlayBridge.showTooltip(second.descriptionText, second, 1, secondActivity)
            compare(panel.content.activeTooltipSource, first)
            // A higher-priority slider owns the surface while the old row goes stale.
            Lazer.SettingsOverlayBridge.showTooltip("35%", slider.nubItem, 2, sliderActivity)
            tryVerify(function() { return panel.content.activeTooltipSource === slider.nubItem }, 200)
            firstActivity.tooltipActive = false
            sliderActivity.tooltipActive = false
            Lazer.SettingsOverlayBridge.hideTooltip(slider.nubItem)
            // The stale first request remains registered but cannot reappear.
            tryVerify(function() { return panel.content.activeTooltipSource === second }, 200)
            compare(panel.content.activeTooltipText, second.descriptionText)
            Lazer.SettingsOverlayBridge.hideTooltip(second)
            Lazer.SettingsOverlayBridge.hideTooltip(first)
            tryVerify(function() { return !panel.content.tooltipVisible }, 300)
            panel.contentReady = false
        }

        function test_sliderActivitySourceFallsBackToActiveRow() {
            panel.contentReady = true
            var row = panel.appearancePage.panelOpacityRow
            var slider = panel.appearancePage.panelOpacitySlider
            var nub = slider.nubItem
            firstActivity.tooltipActive = true
            sliderActivity.tooltipActive = true
            // Row description is active first.
            Lazer.SettingsOverlayBridge.showTooltip(row.descriptionText, row, 1, firstActivity)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            // Slider takes over with priority 2.
            Lazer.SettingsOverlayBridge.showTooltip("35%", nub, 2, sliderActivity)
            tryVerify(function() { return panel.content.activeTooltipSource === nub }, 200)
            compare(panel.content.activeTooltipPriority, 2)
            // An inactive slider may not block the still-active row fallback.
            sliderActivity.tooltipActive = false
            Lazer.SettingsOverlayBridge.hideTooltip(nub)
            tryVerify(function() { return panel.content.activeTooltipSource === row }, 200)
            compare(panel.content.activeTooltipText, row.descriptionText)
            Lazer.SettingsOverlayBridge.hideTooltip(row)
            panel.contentReady = false
        }

        // ── Tooltip ownership regression: row departure/dismissal ──

        function test_rowDepartureDismissesTooltipAndNewRowBecomesOwner() {
            panel.contentReady = true
            var first = panel.appearancePage.wallpaperRow
            var second = panel.appearancePage.colorSchemeRow
            movePointerTo(first)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, first)
            movePointerAway()
            tryCompare(panel.content, "tooltipVisible", false, 200)
            movePointerTo(second)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, second)
            compare(panel.content.activeTooltipText, second.descriptionText)
            movePointerAway()
            panel.contentReady = false
        }

        function test_controlFocusKeepsRowTooltipActive() {
            panel.contentReady = true
            var row = panel.appearancePage.panelOpacityRow
            var slider = panel.appearancePage.panelOpacitySlider
            movePointerAway()
            slider.forceActiveFocus()
            tryVerify(function() { return slider.activeFocus }, 200)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, row)
            panel.forceActiveFocus()
            wait(20)
            tryCompare(panel.content, "tooltipVisible", false, 200)
            panel.contentReady = false
        }

        function test_barCategoryRowDepartureDismissesAndNewRowOwns() {
            panel.selectCategory("bar")
            tryCompare(panel.barPage, "opacity", 1, 300)
            panel.contentReady = true
            var first = panel.barPage.heightRow
            verify(first.descriptionText.length > 0)
            movePointerTo(first)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, first)
            movePointerAway()
            tryCompare(panel.content, "tooltipVisible", false, 200)
            panel.contentReady = false
        }

        function test_notificationCategoryRowDepartureDismissesAndNewRowOwns() {
            panel.selectCategory("notifications")
            tryCompare(panel.notificationPage, "opacity", 1, 300)
            panel.contentReady = true
            var first = panel.notificationPage.dndRow
            var second = panel.notificationPage.maxVisibleRow
            movePointerTo(first)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, first)
            movePointerAway()
            tryCompare(panel.content, "tooltipVisible", false, 200)
            movePointerTo(second)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, second)
            movePointerAway()
            panel.contentReady = false
        }

        function test_controlRowHoverDrivesRowTooltip() {
            panel.contentReady = true
            var textRow = panel.appearancePage.wallpaperRow
            verify(textRow.descriptionText.length > 0)
            verify(textRow.controlItem !== null)
            movePointerTo(textRow.controlItem)
            tryCompare(panel.content, "tooltipVisible", true, 200)
            compare(panel.content.activeTooltipSource, textRow)
            movePointerAway()
            tryCompare(panel.content, "tooltipVisible", false, 200)
            panel.contentReady = false
        }
    }
}
