import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify notification stack direction and popup dismissal contracts without Quickshell.
Item {
    width: 400
    height: 500

    ListModel {
        id: entries
        ListElement { notifId: 1; appName: "A"; summary: "First"; body: "Body"; icon: "" }
        ListElement { notifId: 2; appName: "B"; summary: "Second"; body: ""; icon: "" }
    }

    Lazer.LazerNotificationStack { id: topStack; popupModel: entries; stackAtTop: true }
    Lazer.LazerNotificationStack { id: bottomStack; popupModel: entries; stackAtTop: false }
    Lazer.LazerNotificationPopup { id: popup; appName: "Test"; summary: "Dismiss me" }

    TestCase {
        name: "LazerNotificationPopups"
        when: windowShown

        function test_stackDirection() {
            compare(topStack.stackAtTop, true)
            compare(bottomStack.stackAtTop, false)
        }

        function test_popupDismissSignal() {
            var dismissed = false
            popup.dismissRequested.connect(function() { dismissed = true })
            popup.dismissRequested()
            verify(dismissed)
        }

        function test_popupOwnsVisibleGeometry() {
            verify(popup.implicitWidth > 0)
            verify(popup.implicitHeight > 0)
            compare(popup.height, popup.implicitHeight)
        }

        // Regression: model roles must reach popup content via explicit
        // `model.` bindings; required-property injection silently failed.
        function test_stackPopupsReceiveModelData() {
            var first = topStack.children[0].itemAtIndex(0)
            var second = topStack.children[0].itemAtIndex(1)
            verify(first !== null)
            compare(first.appName, "A")
            compare(first.summary, "First")
            compare(first.body, "Body")
            verify(second !== null)
            compare(second.summary, "Second")
            compare(second.body, "")
        }
    }
}
