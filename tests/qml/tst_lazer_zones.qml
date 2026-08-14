import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify responsive utility priority and local zone state.
Item {
    Lazer.LeftZone { id: left }
    Lazer.UtilityZone { id: utility }
    Lazer.StatusZone { id: status }
    TestCase {
        name: "LazerZones"
        function test_defaults() {
            compare(left.selectedMode, "osu")
            compare(status.notificationsActive, false)
            status.activateNotification()
            compare(status.notificationsActive, true)
        }
        function test_responsiveUtilities() {
            utility.availableWidth = 1000
            compare(utility.visibleIds.length, 8)
            utility.availableWidth = 32
            compare(utility.visibleIds, ["music"])
        }
    }
}
