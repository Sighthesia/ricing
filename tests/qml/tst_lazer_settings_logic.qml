import QtQuick
import QtTest
import "../../modules/lazerbar/LazerBarLogic.js" as BarLogic
import "../../modules/lazerbar/LazerSettingsLogic.js" as SettingsLogic

// Verify settings overlay state, geometry, and normalization helpers.
Item {
    TestCase {
        name: "LazerSettingsLogic"

        function test_overlayState() {
            compare(BarLogic.nextOverlay("", "settings"), "settings")
            compare(BarLogic.nextOverlay("settings", "settings"), "")
            compare(BarLogic.nextOverlay("music", "settings"), "settings")
        }

        function test_panelGeometry() {
            compare(SettingsLogic.panelWidth(1920), 1040)
            compare(SettingsLogic.panelWidth(900), 760)
            compare(SettingsLogic.panelWidth(600), 568)
            compare(SettingsLogic.panelHeight(1080), 760)
            compare(SettingsLogic.panelHeight(540), 508)
            compare(SettingsLogic.navigationWidth(759), 168)
            compare(SettingsLogic.navigationWidth(760), 216)
        }

        function test_settingsConversions() {
            compare(SettingsLogic.timeoutSecondsToMs(1), 2000)
            compare(SettingsLogic.timeoutSecondsToMs(20), 15000)
            compare(SettingsLogic.categoryDirection(2, 0), -1)
        }

        function test_notificationAnchors() {
            var anchors = SettingsLogic.notificationAnchors("bottom-left")
            compare(anchors.top, false)
            compare(anchors.bottom, true)
            compare(anchors.left, true)
            compare(anchors.right, false)
        }

        function test_clampAndInvalidValues() {
            compare(SettingsLogic.clamp(12, 0, 10), 10)
            compare(SettingsLogic.clamp(-2, 0, 10), 0)
            compare(SettingsLogic.clamp(4, 10, 0), 4)
            compare(SettingsLogic.panelWidth(NaN), 320)
            compare(SettingsLogic.panelHeight(Infinity), 320)
        }
    }
}
