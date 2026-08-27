import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify the reusable two-layer popup direction and stagger contracts.
Item {
    id: root
    width: 400
    height: 400

    Lazer.TwoLayerPopup {
        id: popup
        width: 320
        height: 200
        orientation: 1
        direction: 1
        revealProgress: 1

        // Sidebar content determines host height for stacking checks.
        Rectangle {
            parent: popup.sidebarLayer
            width: 320
            height: 48
            color: "red"
        }

        // Content child determines the second host height.
        Rectangle {
            parent: popup.contentLayer
            width: 320
            height: 96
            color: "blue"
        }
    }

    TestCase {
        name: "TwoLayerPopup"
        when: windowShown

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            popup.orientation = popup.vertical
            popup.direction = popup.down
            popup.revealProgress = 1
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_downDirectionStacksSidebarBeforeContent() {
            popup.orientation = popup.vertical
            popup.direction = popup.down
            compare(popup.sidebarLayer.y, 0)
            compare(popup.contentLayer.y, popup.sidebarLayer.height + 1)
        }

        function test_upDirectionStacksContentBeforeSidebar() {
            popup.orientation = popup.vertical
            popup.direction = popup.up
            compare(popup.contentLayer.y, 0)
            compare(popup.sidebarLayer.y, popup.contentLayer.height + 1)
        }

        function test_contentRevealWaitsForDelay() {
            popup.orientation = popup.vertical
            popup.revealProgress = 0.2
            verify(popup.sidebarRevealProgress > popup.contentRevealProgress)
        }
    }
}
