import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify utility-zone music state and request ownership.
Item {
    width: 600; height: 80
    Lazer.UtilityZone { id: utility; availableWidth: 1000 }
    SignalSpy { id: openSpy; target: utility; signalName: "musicOverlayRequested" }
    TestCase {
        name: "LazerMusicIntegration"
        function init() { utility.musicActive = false; openSpy.clear() }
        function test_musicButtonContract() {
            verify(utility.musicButtonItem !== null)
            compare(utility.musicButtonItem.isActive, false)
            utility.musicButtonItem.clicked()
            compare(openSpy.count, 1)
            compare(openSpy.signalArguments[0][0], true)
            utility.musicActive = true
            compare(utility.musicButtonItem.isActive, true)
        }
        function test_musicSurvivesNarrowWidth() {
            utility.availableWidth = 32
            compare(utility.visibleIds, ["music"])
            compare(utility.musicButtonItem.visible, true)
        }
    }
}
