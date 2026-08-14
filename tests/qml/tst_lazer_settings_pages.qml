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
        }

        function cleanup() {
            appearancePage.height = 500
            barPage.height = 500
            notificationsPage.height = 500
        }

        function test_pagesAreScrollableAndLocalized() {
            appearancePage.height = 180
            barPage.height = 180
            notificationsPage.height = 180
            verify(appearancePage.contentHeight > 0)
            verify(barPage.contentHeight > 0)
            verify(notificationsPage.contentHeight > notificationsPage.height)
            compare(appearancePage.title, "外观")
            compare(barPage.title, "顶部栏")
            compare(notificationsPage.title, "通知")
            verify(notificationsPage.contentY >= 0)
            verify(notificationsPage.contentHeight > 180)
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
            compare(barSettings.floatingMargin, 17)
        }
    }
}
