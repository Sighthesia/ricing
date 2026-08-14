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
        property real glassHighlightWidth: 2
        property real glassHighlightIntensity: 0.56
        property real glassGlowWidth: 5
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
        id: appearancePage
        width: 600
        height: 500
        settingsObject: appearanceSettings
        wallpaperService: fakeWallpaper
        saveCallback: saveState.save
    }
    Lazer.LazerSettingsBar {
        id: barPage
        width: 600
        height: 500
        settingsObject: barSettings
        saveCallback: saveState.save
    }
    Lazer.LazerSettingsNotifications {
        id: notificationsPage
        width: 600
        height: 500
        settingsObject: notificationSettings
        saveCallback: saveState.save
    }

    TestCase {
        name: "LazerSettingsPages"

        function init() {
            saveState.count = 0
            appearanceSettings.wallpaperPath = "/tmp/old.png"
            fakeWallpaper.changed = ""
        }

        function test_pagesAreScrollableAndLocalized() {
            verify(appearancePage.contentHeight > appearancePage.height)
            verify(barPage.contentHeight > barPage.height)
            verify(notificationsPage.contentHeight > notificationsPage.height)
            compare(appearancePage.title, "外观")
            compare(barPage.title, "状态栏")
            compare(notificationsPage.title, "通知")
        }

        function test_appearanceWallpaperUsesServiceContract() {
            appearancePage.wallpaperField.commit()
            compare(fakeWallpaper.changed, "/tmp/old.png")
            compare(saveState.count, 0)
            appearancePage.wallpaperField.clear()
            compare(appearanceSettings.wallpaperPath, "")
            compare(saveState.count, 1)
        }

        function test_pagesClampAndValidateValues() {
            appearancePage.panelOpacitySlider.setValue(99)
            compare(appearanceSettings.panelOpacity, 1)
            barPage.heightSlider.setValue(999)
            compare(barSettings.height, 120)
            notificationsPage.positionChoice.selectValue("invalid")
            compare(notificationSettings.position, "top-right")
            notificationsPage.maxVisibleSlider.setValue(-1)
            compare(notificationSettings.maxVisible, 1)
        }

        function test_dependentRowsDisableControls() {
            appearanceSettings.enableBlur = false
            verify(!appearancePage.blurSurfaceRow.enabled)
            verify(!appearancePage.blurSurfaceSlider.effectiveEnabled)
            barSettings.floating = false
            verify(!barPage.floatingMarginSlider.effectiveEnabled)
        }
    }
}
