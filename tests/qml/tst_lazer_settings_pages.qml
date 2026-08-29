import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Exercise category pages with plain fake state instead of SettingsService.
Item {
    QtObject {
        id: appearanceSettings
        property string wallpaperPath: "/tmp/old.png"
        property string colorScheme: "auto"
        property real panelOpacity: 0.9
        property bool enableBlur: true
        property real blurSurfaceOpacity: 0.35
        property real glassHighlightIntensity: 0.56
        property real glassGlowIntensity: 0.22
        property bool glassThemeAdaptive: true
        property bool ripplePulseEnabled: true
        property bool overviewBackground: false
        property bool overviewBackgroundSolid: false
        property real overviewBackgroundBlur: 0.4
        property real overviewBackgroundTint: 0.5
    }
    QtObject {
        id: barSettings
        property int height: 48
        property string position: "top"
        property bool floating: false
        property int floatingMargin: 4
        property int cornerRadius: 12
    }
    QtObject {
        id: notificationSettings
        property int maxVisible: 3
        property int timeout: 5000
        property string position: "top-right"
        property bool dnd: false
    }
    QtObject { id: fakeWallpaper; property string changed: ""; function changeWallpaper(path) { changed = path } }
    QtObject { id: saveState; property int count: 0; function save() { count++ } }

    Lazer.LazerSettingsAppearance {
        id: appearancePage; width: 600; height: 180
        settingsObject: appearanceSettings; wallpaperService: fakeWallpaper; saveCallback: saveState.save
    }
    Lazer.LazerSettingsBar {
        id: barPage; width: 600; height: 180
        settingsObject: barSettings; saveCallback: saveState.save
    }
    Lazer.LazerSettingsNotifications {
        id: notificationsPage; width: 600; height: 180
        settingsObject: notificationSettings; saveCallback: saveState.save
    }

    TestCase {
        name: "LazerSettingsPages"

        function init() {
            saveState.count = 0
            appearanceSettings.wallpaperPath = "/tmp/old.png"
            appearanceSettings.colorScheme = "auto"
            appearanceSettings.panelOpacity = 0.9
            appearanceSettings.enableBlur = true
            appearanceSettings.blurSurfaceOpacity = 0.35
            appearanceSettings.glassHighlightIntensity = 0.56
            appearanceSettings.glassGlowIntensity = 0.22
            appearanceSettings.glassThemeAdaptive = true
            appearanceSettings.ripplePulseEnabled = true
            fakeWallpaper.changed = ""
            appearancePage.wallpaperField.text = appearanceSettings.wallpaperPath
            barSettings.height = 48
            barSettings.position = "top"
            barSettings.floating = false
            barSettings.floatingMargin = 4
            barSettings.cornerRadius = 12
            notificationSettings.maxVisible = 3
            notificationSettings.timeout = 5000
            notificationSettings.position = "top-right"
            notificationSettings.dnd = false
            appearancePage.defaults = ({})
            appearancePage.resetCallback = null
            barPage.defaults = ({})
            barPage.resetCallback = null
            notificationsPage.defaults = ({})
            notificationsPage.resetCallback = null
        }

        function cleanup() {
            appearancePage.searchQuery = ""
            barPage.searchQuery = ""
            notificationsPage.searchQuery = ""
        }

        function test_pagesAreSectionBlocksAndLocalized() {
            verify(appearancePage.height > 100)
            verify(barPage.height > 100)
            verify(notificationsPage.height > 300)
            compare(appearancePage.title, "外观")
            compare(barPage.title, "顶部栏")
            compare(notificationsPage.title, "通知")
            verify(notificationsPage.hasVisibleContent)
        }

        function test_appearanceWritesAllSupportedValues() {
            appearancePage.colorSchemeChoice.selectValue("dark")
            appearancePage.panelOpacitySlider.setValue(0.35)
            appearancePage.enableBlurToggle.activate()
            appearancePage.blurSurfaceOpacitySlider.setValue(0.8)
            appearancePage.glassHighlightIntensitySlider.setValue(0.7)
            appearancePage.glassGlowIntensitySlider.setValue(0.6)
            appearancePage.glassThemeAdaptiveToggle.activate()
            appearancePage.ripplePulseToggle.activate()
            compare(appearanceSettings.colorScheme, "dark")
            compare(appearanceSettings.panelOpacity, 0.35)
            compare(appearanceSettings.enableBlur, false)
            compare(appearanceSettings.blurSurfaceOpacity, 0.8)
            compare(appearanceSettings.glassHighlightIntensity, 0.7)
            compare(appearanceSettings.glassGlowIntensity, 0.6)
            compare(appearanceSettings.glassThemeAdaptive, false)
            compare(appearanceSettings.ripplePulseEnabled, false)
            verify(saveState.count >= 8)
        }

        function test_appearanceWallpaperBranches() {
            appearancePage.wallpaperField.commit()
            compare(fakeWallpaper.changed, "")
            compare(saveState.count, 0)
            appearancePage.wallpaperField.editorItem.text = "/tmp/new.png"
            appearancePage.wallpaperField.commit()
            compare(fakeWallpaper.changed, "/tmp/new.png")
            compare(saveState.count, 0)
            appearancePage.wallpaperField.clear()
            compare(appearanceSettings.wallpaperPath, "")
            compare(saveState.count, 1)
        }

        function test_clampsAndRejectsUnknownValues() {
            appearancePage.panelOpacitySlider.setValue(-1)
            compare(appearanceSettings.panelOpacity, 0.35)
            appearancePage.panelOpacitySlider.setValue(2)
            compare(appearanceSettings.panelOpacity, 1)
            appearancePage.colorSchemeChoice.selectValue("invalid")
            compare(appearanceSettings.colorScheme, "auto")
            barPage.heightSlider.setValue(20)
            compare(barSettings.height, 40)
            barPage.heightSlider.setValue(90)
            compare(barSettings.height, 64)
            barPage.positionChoice.selectValue("invalid")
            compare(barSettings.position, "top")
            notificationsPage.maxVisibleSlider.setValue(0)
            compare(notificationSettings.maxVisible, 1)
            notificationsPage.maxVisibleSlider.setValue(20)
            compare(notificationSettings.maxVisible, 8)
            notificationsPage.timeoutSlider.setValue(1)
            compare(notificationSettings.timeout, 2000)
            notificationsPage.timeoutSlider.setValue(20)
            compare(notificationSettings.timeout, 15000)
            notificationsPage.positionChoice.selectValue("invalid")
            compare(notificationSettings.position, "top-right")
        }

        function test_invalidChoiceValuesRecoverWithoutLoadMutation() {
            saveState.count = 0
            appearanceSettings.colorScheme = "invalid"
            barSettings.position = "invalid"
            notificationSettings.position = "invalid"
            compare(appearancePage.colorSchemeChoice.currentValue, "auto")
            compare(appearancePage.colorSchemeChoice.displayLabel, "自动")
            compare(barPage.positionChoice.currentValue, "top")
            compare(barPage.positionChoice.displayLabel, "顶部")
            compare(notificationsPage.positionChoice.currentValue, "top-right")
            compare(notificationsPage.positionChoice.displayLabel, "右上")
            compare(saveState.count, 0)

            appearancePage.colorSchemeChoice.selectValue("dark")
            compare(appearanceSettings.colorScheme, "dark")
            compare(saveState.count, 1)
            barPage.positionChoice.selectNext(1)
            compare(barSettings.position, "bottom")
            compare(saveState.count, 2)
            notificationsPage.positionChoice.selectValue("bottom-left")
            compare(notificationSettings.position, "bottom-left")
            compare(saveState.count, 3)
        }

        function test_dependenciesDisableWithoutChangingValue() {
            appearanceSettings.blurSurfaceOpacity = 0.65
            appearanceSettings.enableBlur = false
            verify(!appearancePage.blurSurfaceRow.enabled)
            verify(!appearancePage.blurSurfaceSlider.effectiveEnabled)
            compare(appearanceSettings.blurSurfaceOpacity, 0.65)
            barSettings.floatingMargin = 17
            barSettings.floating = false
            verify(!barPage.floatingMarginRow.enabled)
            verify(!barPage.floatingMarginSlider.effectiveEnabled)
            verify(!barPage.floatingMarginRow.revertVisible)
            verify(!barPage.floatingMarginRow.revertButtonItem.visible)
            compare(barSettings.floatingMargin, 17)
        }

        function test_searchFiltersCurrentCategoryRows() {
            appearancePage.searchQuery = "模糊"
            compare(appearancePage.visibleResultCount, 3)
            verify(appearancePage.blurSurfaceRow.searchVisible)
            verify(appearancePage.overviewBlurRow.searchVisible)
            verify(!appearancePage.wallpaperRow.visible)
            appearancePage.searchQuery = "壁纸"
            compare(appearancePage.visibleResultCount, 1)
            verify(appearancePage.wallpaperRow.visible)
            appearancePage.searchQuery = ""
            compare(appearancePage.visibleResultCount, 13)
            verify(appearancePage.wallpaperRow.visible)
        }

        function test_searchMatchesDescriptionAndDisabledRows() {
            appearancePage.searchQuery = "自动、深色或浅色"
            verify(appearancePage.colorSchemeRow.visible)
            compare(appearancePage.visibleResultCount, 1)
            appearanceSettings.enableBlur = false
            appearancePage.searchQuery = "模糊"
            verify(appearancePage.blurSurfaceRow.searchVisible)
            verify(appearancePage.overviewBlurRow.searchVisible)
            verify(appearancePage.blurSurfaceRow.visible)
            verify(!appearancePage.blurSurfaceRow.enabled)
            compare(appearancePage.visibleResultCount, 3)
            appearancePage.searchQuery = "audio"
            compare(appearancePage.visibleResultCount, 0)
            appearancePage.searchQuery = ""
            appearanceSettings.enableBlur = true
        }

        function test_searchDoesNotTriggerSave() {
            appearancePage.searchQuery = "壁纸"
            saveState.count = 0
            appearancePage.searchQuery = "模糊"
            appearancePage.searchQuery = ""
            compare(saveState.count, 0)
        }

        function test_otherPagesFilterIndependently() {
            barPage.searchQuery = "浮动"
            compare(barPage.visibleResultCount, 2)
            barPage.searchQuery = "位置"
            compare(barPage.visibleResultCount, 1)
            barPage.searchQuery = ""
            compare(barPage.visibleResultCount, 5)
            notificationsPage.searchQuery = "通知"
            compare(notificationsPage.visibleResultCount, 3)
            notificationsPage.searchQuery = ""
            compare(notificationsPage.visibleResultCount, 4)
        }

        function test_rowsShowRevertOnlyWhenOffDefault() {
            appearancePage.defaults = { "panelOpacity": 0.9, "colorScheme": "auto", "wallpaperPath": "" }
            appearancePage.resetCallback = function(key, value) {
                if (key === "panelOpacity") appearanceSettings.panelOpacity = value
                else if (key === "colorScheme") appearanceSettings.colorScheme = value
                else if (key === "wallpaperPath") appearanceSettings.wallpaperPath = value
            }
            verify(!appearancePage.panelOpacityRow.revertVisible)
            appearanceSettings.panelOpacity = 0.55
            verify(appearancePage.panelOpacityRow.revertVisible)
            appearancePage.panelOpacityRow.activateReset()
            compare(appearanceSettings.panelOpacity, 0.9)
            verify(!appearancePage.panelOpacityRow.revertVisible)
            verify(!appearancePage.colorSchemeRow.revertVisible)
            appearanceSettings.colorScheme = "dark"
            verify(appearancePage.colorSchemeRow.revertVisible)
            appearancePage.colorSchemeRow.activateReset()
            compare(appearanceSettings.colorScheme, "auto")
            appearancePage.defaults = {}
            verify(!appearancePage.panelOpacityRow.hasDefault)
            verify(!appearancePage.panelOpacityRow.revertVisible)
        }

        function test_defaultAndResetFlowThroughPanelContract() {
            appearancePage.defaults = { "enableBlur": true }
            appearancePage.resetCallback = function(key, value) { appearanceSettings.enableBlur = value }
            appearanceSettings.enableBlur = false
            verify(appearancePage.enableBlurRow.revertVisible)
            appearancePage.enableBlurRow.activateReset()
            compare(appearanceSettings.enableBlur, true)
            verify(!appearancePage.enableBlurRow.revertVisible)
            barPage.defaults = { "floatingMargin": 4, "position": "top" }
            barPage.resetCallback = function(key, value) {
                if (key === "floatingMargin") barSettings.floatingMargin = value
                else if (key === "position") barSettings.position = value
            }
            barSettings.floating = true
            barSettings.floatingMargin = 20
            verify(barPage.floatingMarginRow.revertVisible)
            barPage.floatingMarginRow.activateReset()
            compare(barSettings.floatingMargin, 4)
            barSettings.floating = false
            notificationsPage.defaults = { "maxVisible": 3 }
            notificationsPage.resetCallback = function(key, value) { notificationSettings.maxVisible = value }
            notificationSettings.maxVisible = 6
            verify(notificationsPage.maxVisibleRow.revertVisible)
            notificationsPage.maxVisibleRow.activateReset()
            compare(notificationSettings.maxVisible, 3)
        }

        function test_sliderDefaultsUseDisplayUnitsAndResetCanonicalValues() {
            appearancePage.defaults = { "panelOpacity": 0.9 }
            appearancePage.resetCallback = function(key, value) {
                if (key === "panelOpacity") appearanceSettings.panelOpacity = value
            }
            appearanceSettings.panelOpacity = 0.55
            compare(appearancePage.panelOpacitySlider.defaultValue, 0.9)
            verify(appearancePage.panelOpacitySlider.defaultMarkerVisible)
            appearancePage.panelOpacityRow.activateReset()
            compare(appearanceSettings.panelOpacity, 0.9)

            barPage.defaults = { "height": 48 }
            barPage.resetCallback = function(key, value) {
                if (key === "height") barSettings.height = value
            }
            barSettings.height = 60
            compare(barPage.heightSlider.defaultValue, 48)
            verify(barPage.heightSlider.defaultMarkerVisible)
            barPage.heightRow.activateReset()
            compare(barSettings.height, 48)

            notificationsPage.defaults = { "timeout": 5000 }
            notificationsPage.resetCallback = function(key, value) {
                if (key === "timeout") notificationSettings.timeout = value
            }
            notificationSettings.timeout = 12000
            compare(notificationsPage.timeoutSlider.defaultValue, 5)
            compare(notificationsPage.timeoutSlider.displayValue, 12)
            verify(notificationsPage.timeoutSlider.defaultMarkerVisible)
            notificationsPage.timeoutRow.activateReset()
            compare(notificationSettings.timeout, 5000)
            compare(notificationsPage.timeoutSlider.displayValue, 5)
            verify(notificationsPage.timeoutSlider.defaultMarkerVisible)
            compare(notificationsPage.timeoutSlider.defaultMarkerItem.height,
                    notificationsPage.timeoutSlider.trackItem.height - 6)
        }
    }
}
