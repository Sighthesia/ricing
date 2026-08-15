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
            panel.appearancePage.contentY = 0
            panel.barPage.contentY = 0
            panel.notificationPage.contentY = 0
            closeSpy.clear()
            categorySpy.clear()
            wait(20)
        }

        function cleanup() { Lazer.MotionTokens.reducedMotionOverride = false }

        function test_keepsAllPagesAliveAndInjectsDependencies() {
            verify(panel.appearancePage)
            verify(panel.barPage)
            verify(panel.notificationPage)
            compare(panel.appearancePage.settingsObject, appearanceSettings)
            compare(panel.barPage.settingsObject, barSettings)
            compare(panel.notificationPage.settingsObject, notificationSettings)
            compare(panel.appearancePage.wallpaperService, wallpaperService)
            compare(panel.appearancePage.saveCallback, saveService.save)
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
            panel.closeButton.forceActiveFocus()
            closeSpy.clear()
            keyPress(Qt.Key_Space)
            compare(closeSpy.count, 1)
            panel.closeButton.forceActiveFocus()
            keyPress(Qt.Key_Return)
            compare(closeSpy.count, 2)
            panel.focusNavigation()
            verify(panel.currentNav.activeFocus)
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

        function test_closeButtonOwnsPanelCloseContract() {
            panel.focusNavigation()
            closeSpy.clear()
            panel.closeButton.forceActiveFocus()
            keyPress(Qt.Key_Space)
            compare(closeSpy.count, 1)
            panel.requestClose()
            compare(closeSpy.count, 2)
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
    }
}
