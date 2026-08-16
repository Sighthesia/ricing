import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

Item {
    width: 960
    height: 640
    QtObject { id: appearanceSettings; property string wallpaperPath: ""; property string colorScheme: "auto"; property real panelOpacity: 0.9; property bool enableBlur: true; property real blurSurfaceOpacity: 0.35; property real glassHighlightIntensity: 0.56; property real glassGlowIntensity: 0.22; property bool glassThemeAdaptive: true; property bool ripplePulseEnabled: true }
    QtObject { id: barSettings; property int height: 48; property string position: "top"; property bool floating: false; property int floatingMargin: 4; property int cornerRadius: 12 }
    QtObject { id: notificationSettings; property int maxVisible: 3; property int timeout: 5000; property string position: "top-right"; property bool dnd: false }
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
    }
    Lazer.LazerSettingsOverlay { id: overlay; anchors.fill: parent }

    TestCase {
        name: "Smoke"
        function test_loads() {
            verify(panel.sidebar)
            verify(panel.content)
            verify(panel.appearancePage)
            verify(panel.barPage)
            verify(panel.notificationPage)
            verify(panel.appearanceNav)
            verify(panel.barNav)
            verify(panel.notificationNav)
            verify(panel.searchField)
        }
        function test_geometry() {
            compare(panel.panelWidth, 570)
            compare(panel.sidebarWidth, 170)
            compare(panel.contentWidth, 400)
            compare(panel.sidebarLayerX, 0)
            compare(panel.contentLayerX, 170)
        }
    }
}
