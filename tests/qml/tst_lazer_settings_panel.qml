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
            panel.interactive = true
            panel.selectedCategory = "appearance"
            panel.sidebarExpanded = true
            panel.searchQuery = ""
            panel.progress = 1
            panel.width = 570
            panel.height = 560
            panel.availableWidth = 570
            panel.availableHeight = 560
            panel.sections.contentY = 0
            barSettings.height = 48
            resetService.count = 0
            resetService.category = ""
            resetService.key = ""
            resetService.value = undefined
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
            compare(panel.content.searchSurfaceItem.color, Lazer.LazerTheme.settingsRail)
            compare(panel.content.searchSurfaceItem.border.width, 0)
            compare(panel.content.searchSurfaceItem.radius, 0)
            verify(panel.content.scrollShadowItem.enabled === false)
            verify(panel.content.emptyStateItem.enabled === false)
            verify(panel.content.dropdownLayerItem.visible === false)
            verify(panel.content.menuCatcherItem.enabled === false)
        }

        function test_visibleRowsOwnStableCardAndControlGeometry() {
            var page = panel.appearancePage
            var rows = [page.wallpaperRow, page.colorSchemeRow, page.panelOpacityRow,
                        page.enableBlurRow, page.blurSurfaceRow]
            for (var i = 0; i < rows.length; i++) {
                var row = rows[i]
                var control = row.controlItem
                verify(row.visible)
                verify(row.height > 0)
                compare(row.cardItem.width, row.cardBodyWidth)
                compare(row.cardItem.height, row.height)
                verify(control.width > 0)
                verify(control.height > 0)
                var controlRect = control.mapToItem(row, 0, 0)
                verify(controlRect.x >= -0.1)
                verify(controlRect.y >= -0.1)
                verify(controlRect.x + control.width <= row.width + 0.1)
                verify(controlRect.y + control.height <= row.height + 0.1)
            }
            var viewport = panel.content.viewportItem
            var firstRect = page.wallpaperRow.mapToItem(panel.content, 0, 0)
            verify(firstRect.y >= viewport.y - panel.sections.contentY - 0.1)
            verify(viewport.clip)
        }

        function test_choiceMenuExpandsRowAndPushesFollowingRows() {
            var row = panel.appearancePage.colorSchemeRow
            var choice = row.controlItem
            var following = panel.appearancePage.panelOpacityRow
            var closedHeight = row.height
            var closedY = following.y

            verify(choice !== null)
            compare(choice.menuOpen, false)
            compare(choice.menuReservedHeight, 0)
            choice.openMenu()
            tryCompare(choice, "menuOpen", true)
            tryCompare(row, "height", row.implicitHeight, 500)
            verify(row.height > closedHeight)
            verify(following.y > closedY)
            verify(row.cardHighlightItem.height >= row.height - 1)
            verify(choice.optionListHeight > 0)

            choice.selectValue("dark")
            tryCompare(choice, "menuOpen", false)
            tryCompare(row, "height", closedHeight, 500)
            tryCompare(following, "y", closedY, 500)
        }

        function test_choiceEscapeAndOutsideTapCloseWithoutChangingValue() {
            var row = panel.appearancePage.colorSchemeRow
            var choice = row.controlItem
            var originalValue = choice.currentValue

            choice.openMenu()
            tryCompare(choice, "menuOpen", true)
            keyPress(Qt.Key_Escape)
            tryCompare(choice, "menuOpen", false)
            compare(choice.currentValue, originalValue)

            choice.openMenu()
            tryCompare(choice, "menuOpen", true)
            mouseClick(panel.content, 4, 4)
            tryCompare(choice, "menuOpen", false)
            compare(choice.currentValue, originalValue)
        }

        function test_choiceClosesWhenSwitchingCategory() {
            var choice = panel.appearancePage.colorSchemeRow.controlItem
            choice.openMenu()
            tryCompare(choice, "menuOpen", true)
            panel.selectCategory("bar")
            tryCompare(choice, "menuOpen", false)
            verify(!panel.appearancePage.sectionActive)
            verify(panel.barPage.sectionActive)
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

        function test_switchActivatesSectionAndKeepsAllSectionsVisible() {
            panel.selectCategory("bar")
            tryCompare(panel, "selectedCategory", "bar", 300)
            verify(!panel.appearancePage.sectionActive)
            verify(panel.barPage.sectionActive)
            verify(!panel.notificationPage.sectionActive)
            verify(panel.appearancePage.visible)
            verify(panel.barPage.visible)
            verify(panel.notificationPage.visible)
            panel.selectCategory("notifications")
            tryCompare(panel, "selectedCategory", "notifications", 300)
            verify(panel.notificationPage.sectionActive)
            verify(!panel.barPage.sectionActive)
        }

        function test_searchFiltersAllSectionsAndShowsEmptyState() {
            panel.searchQuery = "模糊"
            compare(panel.appearancePage.visibleResultCount, 2)
            compare(panel.barPage.visibleResultCount, 0)
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
            compare(panel.barPage.visibleResultCount, 2)
            verify(!panel.barPage.heightRow.visible)
            panel.selectCategory("bar")
            tryCompare(panel, "selectedCategory", "bar", 300)
            compare(panel.appearancePage.visibleResultCount, 0)
            verify(panel.content.emptyStateVisible === false)
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

        function test_selectCategoryScrollsSectionIntoView() {
            panel.selectCategory("bar")
            tryCompare(panel, "selectedCategory", "bar", 300)
            tryVerify(function() {
                var bar = panel.barPage
                var top = panel.sections.mapFromItem(bar, 0, 0).y
                var center = panel.sections.contentY + panel.sections.height / 2
                return center >= top && center <= top + bar.height
            }, 500)
            Lazer.MotionTokens.reducedMotionOverride = true
            panel.selectCategory("notifications")
            tryCompare(panel, "selectedCategory", "notifications", 300)
            var notif = panel.notificationPage
            var notifTop = panel.sections.mapFromItem(notif, 0, 0).y
            var notifCenter = panel.sections.contentY + panel.sections.height / 2
            verify(notifCenter >= notifTop && notifCenter <= notifTop + notif.height)
            compare(panel.categoryTransitionDuration, 160)
            compare(panel.contentTransitionEasing, Lazer.MotionTokens.outSoft)
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_bottomBoundaryActivatesFinalSection() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var maximumY = Math.max(0, panel.sections.contentHeight - panel.sections.height)
            verify(maximumY > 0)
            panel.sections.contentY = maximumY
            wait(0)
            compare(panel.selectedCategory, "notifications")
            verify(panel.notificationPage.sectionActive)
            verify(!panel.barPage.sectionActive)
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_ownedStringContractAndInvalidDirectAssignmentRecovery() {
            panel.selectCategory("notifications")
            compare(panel.selectedIndex, 2)
            compare(categorySpy.count, 1)
            panel.selectedCategory = "invalid"
            tryCompare(panel, "selectedCategory", "appearance", 300)
            compare(panel.selectedIndex, 0)
            verify(panel.appearancePage.sectionActive)
            verify(!panel.notificationPage.sectionActive)
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

        function test_rowHighlightsOnHoverNotFocus() {
            var row = panel.appearancePage.panelOpacityRow
            var slider = panel.appearancePage.panelOpacitySlider
            slider.forceActiveFocus()
            tryVerify(function() { return slider.activeFocus }, 200)
            verify(row.rowHighlighted === false)
            verify(row.cardItem.border.width === 0)
            movePointerTo(row)
            tryVerify(function() { return row.rowHighlighted }, 200)
            verify(row.cardItem.border.width > 0)
            movePointerAway()
            tryVerify(function() { return row.rowHighlighted === false }, 200)
        }

        function test_fastRetargetEndsAtLatestCategoryAndOthersDim() {
            panel.selectCategory("bar")
            panel.selectCategory("notifications")
            tryCompare(panel, "selectedCategory", "notifications", 300)
            tryVerify(function() { return panel.notificationPage.sectionActive }, 400)
            verify(!panel.appearancePage.sectionActive)
            verify(!panel.barPage.sectionActive)
            verify(panel.notificationPage.sectionActive)
            verify(!panel.appearancePage.activeFocus)
            verify(!panel.barPage.activeFocus)
        }

        function test_scrollRetargetReplacesInFlightAnimation() {
            panel.selectCategory("appearance")
            panel.selectCategory("bar")
            panel.selectCategory("notifications")
            wait(1)
            compare(panel.selectedCategory, "notifications")
            tryVerify(function() { return panel.notificationPage.sectionActive }, 400)
            tryVerify(function() {
                var notif = panel.notificationPage
                var top = panel.sections.mapFromItem(notif, 0, 0).y
                return Math.abs(panel.sections.contentY + panel.sections.height / 2 - (top + notif.height / 2)) < 12
            }, 500)
        }

        function test_reducedMotionMakesScrollInstant() {
            Lazer.MotionTokens.reducedMotionOverride = true
            panel.selectCategory("appearance")
            panel.selectCategory("bar")
            compare(panel.selectedCategory, "bar")
            verify(panel.barPage.sectionActive)
            verify(!panel.appearancePage.sectionActive)
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_dropdownExpandsInlineAndSelects() {
            panel.contentReady = true
            panel.selectCategory("bar")
            var choice = panel.barPage.positionChoice
            var row = panel.barPage.positionRow
            var closedHeight = row.height
            choice.openMenu()
            verify(panel.content.dropdownVisible)
            verify(!panel.content.dropdownLayerItem.visible)
            verify(!panel.content.menuCatcherItem.enabled)
            verify(choice.menuOpen)
            verify(choice.headerItem.width > 0)
            verify(choice.optionListHeight > 0)
            verify(row.height > closedHeight)
            choice.selectValue("bottom")
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

        function test_rowsNeverCreateFloatingTooltips() {
            panel.contentReady = true
            var row = panel.appearancePage.colorSchemeRow
            movePointerTo(row)
            wait(20)
            verify(row.rowHovered)
            compare(panel.content.debugSnapshot().hasOwnProperty("tooltip"), false)
            panel.contentReady = false
        }
    }
}
