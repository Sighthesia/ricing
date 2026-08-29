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

    // Declarative injection target for sidebarData/contentData alias coverage.
    Lazer.TwoLayerPopup {
        id: injectedPopup
        width: 200
        height: 100
        orientation: 1
        direction: 1
        revealProgress: 1

        sidebarData: Rectangle {
            objectName: "injectedSidebar"
            width: 200
            height: 24
            color: "green"
        }

        contentData: Rectangle {
            objectName: "injectedContent"
            width: 200
            height: 40
            color: "yellow"
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

        function test_reducedMotionEndRevealCollapsesBothLayers() {
            Lazer.MotionTokens.reducedMotionOverride = true
            popup.endReveal()
            compare(popup.sidebarRevealProgress, 0)
            compare(popup.contentRevealProgress, 0)
        }

        function test_reducedMotionBeginRevealRestoresBothLayers() {
            Lazer.MotionTokens.reducedMotionOverride = true
            popup.endReveal()
            popup.beginReveal()
            compare(popup.sidebarRevealProgress, 1)
            compare(popup.contentRevealProgress, 1)
        }

        function test_sidebarDataAndContentDataInjection() {
            var sidebarChild = null
            var contentChild = null
            for (var i = 0; i < injectedPopup.sidebarLayer.children.length; ++i) {
                if (injectedPopup.sidebarLayer.children[i].objectName === "injectedSidebar")
                    sidebarChild = injectedPopup.sidebarLayer.children[i]
            }
            for (var j = 0; j < injectedPopup.contentLayer.children.length; ++j) {
                if (injectedPopup.contentLayer.children[j].objectName === "injectedContent")
                    contentChild = injectedPopup.contentLayer.children[j]
            }
            verify(sidebarChild !== null, "sidebarData should inject into sidebarLayer")
            verify(contentChild !== null, "contentData should inject into contentLayer")
            compare(sidebarChild.parent, injectedPopup.sidebarLayer)
            compare(contentChild.parent, injectedPopup.contentLayer)
            verify(injectedPopup.sidebarData.length > 0)
            verify(injectedPopup.contentData.length > 0)
        }

        function test_horizontalRevealKeepsLayerTravelVisible() {
            popup.orientation = popup.horizontal
            popup.revealProgress = 0
            compare(popup.clip, false)
            compare(popup.sidebarLayer.x, popup.horizontalSidebarX)
            compare(popup.contentLayer.x, popup.horizontalContentX)
        }
    }
}
