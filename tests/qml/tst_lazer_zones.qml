import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify responsive utility priority and local zone state.
Item {
    Lazer.LeftZone { id: left }
    Lazer.UtilityZone { id: utility }
    Lazer.StatusZone { id: status }
    SignalSpy { id: settingsSpy; target: left; signalName: "settingsRequested" }
    TestCase {
        name: "LazerZones"
        function init() {
            left.settingsActive = false
            settingsSpy.clear()
        }
        function test_defaults() {
            compare(left.selectedMode, "osu")
            verify(left.settingsButtonItem !== null)
            compare(left.settingsButtonItem.isActive, false)
            compare(status.notificationsActive, false)
            status.activateNotification()
            compare(status.notificationsActive, true)
        }
        function test_settingsButtonContract() {
            left.settingsButtonItem.clicked()
            compare(settingsSpy.count, 1)
            left.settingsActive = true
            compare(left.settingsButtonItem.isActive, true)
        }
        function test_responsiveUtilities() {
            utility.availableWidth = 1000
            compare(utility.visibleIds.length, 8)
            utility.availableWidth = 32
            compare(utility.visibleIds, ["music"])
        }
    }
}
