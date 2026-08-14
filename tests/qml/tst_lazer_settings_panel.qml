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
        width: 840
        height: 560
        appearanceSettings: appearanceSettings
        barSettings: barSettings
        notificationSettings: notificationSettings
        saveCallback: saveService.save
        wallpaperService: wallpaperService
    }
    SignalSpy { id: escapeSpy; target: panel; signalName: "escapeRequested" }

    TestCase {
        name: "LazerSettingsPanel"

        function init() {
            panel.interactive = true
            panel.selectedCategory = 0
            panel.width = 840
            panel.height = 560
            Lazer.MotionTokens.reducedMotionOverride = false
            panel.appearancePage.contentY = 0
            panel.barPage.contentY = 0
            panel.notificationPage.contentY = 0
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

        function test_sizesRailAndUsesOneIndicator() {
            compare(panel.railWidth, 216)
            compare(panel.indicatorCount, 1)
            panel.width = 700
            compare(panel.railWidth, 168)
            verify(panel.appearanceNav.selected)
            verify(!panel.barNav.selected)
            verify(!panel.notificationNav.selected)
        }

        function test_switchKeepsScrollPositionAndDisablesHiddenPages() {
            panel.appearancePage.contentY = 36
            panel.selectCategory(1)
            compare(panel.appearancePage.contentY, 36)
            verify(!panel.appearancePage.enabled)
            verify(panel.barPage.enabled)
            verify(!panel.notificationPage.enabled)
            tryCompare(panel.barPage, "opacity", 1, 300)
            panel.selectCategory(2)
            verify(panel.notificationPage.enabled)
            verify(!panel.barPage.enabled)
        }

        function test_keyboardNavigationAndEscapeAreInteractiveGated() {
            panel.forceActiveFocus()
            keyPress(Qt.Key_Down)
            compare(panel.selectedCategory, 1)
            keyPress(Qt.Key_Down)
            compare(panel.selectedCategory, 2)
            keyPress(Qt.Key_Up)
            compare(panel.selectedCategory, 1)
            keyPress(Qt.Key_Enter)
            compare(panel.selectedCategory, 1)
            panel.interactive = false
            keyPress(Qt.Key_Down)
            compare(panel.selectedCategory, 1)
            panel.interactive = true
            escapeSpy.clear()
            keyPress(Qt.Key_Escape)
            compare(escapeSpy.count, 1)
        }

        function test_crossfadeUsesReducedMotionOnlyForTranslation() {
            panel.selectCategory(1)
            verify(panel.barPage.x === 0 || panel.barPage.x === 8 || panel.barPage.x === -8)
            Lazer.MotionTokens.reducedMotionOverride = true
            panel.selectCategory(2)
            compare(panel.notificationPage.x, 0)
            compare(panel.categoryTransitionDuration, 160)
        }
    }
}
