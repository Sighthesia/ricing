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
        horizontalSidebarX: -170
        horizontalContentX: -400
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

    // A body-only popup: the rail is collapsed, which is what the mod-key window
    // hint asks the host for. `BarPopupHost` relies on the sidebar slot
    // measuring 0 so its geometry drops the rail band instead of keeping an
    // unpainted 48px strip the body would be offset by.
    Lazer.TwoLayerPopup {
        id: bodyOnlyPopup
        width: 360
        height: 200
        orientation: 1
        direction: 1
        revealProgress: 1

        // Height 0 on the rail wrapper is what collapses the slot. Measured,
        // not assumed: `sidebarSlot` sizes itself from `childrenRect`, and
        // childrenRect counts an INVISIBLE child at its full height (so
        // `visible: false` alone leaves the slot at 48), while a child that is
        // simply 0 tall measures 0.
        sidebarData: Item {
            objectName: "collapsedRail"
            width: 360
            height: 0
            visible: false
        }

        contentData: Rectangle {
            objectName: "bodyOnlyContent"
            width: 360
            height: 120
        }
    }

    // The rail at full height, for contrast: same structure, non-zero height.
    Lazer.TwoLayerPopup {
        id: railedPopup
        width: 360
        height: 200
        orientation: 1
        direction: 1
        revealProgress: 1

        sidebarData: Item {
            objectName: "fullRail"
            width: 360
            height: 48
        }

        contentData: Rectangle {
            width: 360
            height: 120
        }
    }

    // Same shape as railedPopup, but never told its rail is collapsible - the
    // trap the flag exists to close.
    Lazer.TwoLayerPopup {
        id: symptomPopup
        width: 360
        height: 200
        orientation: 1
        direction: 1
        revealProgress: 1

        sidebarData: Item {
            objectName: "symptomRail"
            width: 360
            height: 48
        }

        contentData: Rectangle {
            width: 360
            height: 120
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
            // The 1px overlap is a deliberate seam-kill contract (d305475e): the
            // content layer tucks *under* the opaque sidebar, so a `+ 1` gap would
            // let the layer-shell background bleed through as a dark seam.
            compare(popup.contentLayer.y, Math.max(0, popup.sidebarLayer.height - 1))
        }

        function test_layersReportImplicitSizeFromChildren() {
            compare(popup.sidebarLayer.implicitHeight, 48)
            compare(popup.contentLayer.implicitHeight, 96)
            compare(popup.sidebarLayer.implicitWidth, 320)
            compare(popup.contentLayer.implicitWidth, 320)
        }

        function test_hiddenRailMeasuresZero() {
            // The slot sizes itself from `childrenRect`, so the rail wrapper's
            // own height is the only thing that collapses it. If this ever
            // reports 48, the host would keep an unpainted band and the body
            // would sit 48px below where the panel starts.
            compare(bodyOnlyPopup.sidebarLayer.implicitHeight, 0)
            compare(bodyOnlyPopup.sidebarLayer.height, 0)
            // The body is not offset by a rail that is not there.
            compare(bodyOnlyPopup.contentLayer.y, 0)
        }

        function test_collapsedRailDoesNotShrinkTheBody() {
            // Collapsing the rail must not shrink the content: the window list
            // is the whole panel.
            compare(bodyOnlyPopup.contentLayer.implicitHeight, 120)
            compare(bodyOnlyPopup.contentLayer.height, 120)
        }

        function test_aZeroHeightChildCollapsesTheSlotEvenWithTallGrandchildren() {
            // Why the host collapses the wrapper rather than only hiding it:
            // childrenRect counts an invisible direct child at its full height,
            // so `visible: false` alone would leave the slot at 48 - and the
            // wrapper's own visible grandchildren do not expand it.
            compare(railedPopup.sidebarLayer.implicitHeight, 48)
            compare(bodyOnlyPopup.sidebarLayer.implicitHeight, 0)
        }

        function test_aRailThatLatchesUpwardParksTheContentAfterwards() {
            // The regression, measured on the sequence rather than the end state:
            // the host reuses ONE popup instance across intents, so a titled
            // popup settles first (latching 48) and a later body-only one lands
            // on the same instance. Without `railCollapsible` the latch refuses
            // to forget, and the content is parked 47px below a rail that is
            // gone - the blank band that was reported.
            symptomPopup.revealProgress = 0
            wait(0)
            symptomPopup.revealProgress = 1
            wait(0)
            compare(symptomPopup.stableSidebarHeight, 48, "titled popup latches its rail")

            symptomPopup.sidebarLayer.children[0].height = 0
            symptomPopup.revealProgress = 0
            wait(0)
            compare(symptomPopup.sidebarLayer.implicitHeight, 0, "rail is gone")
            compare(symptomPopup.stableSidebarHeight, 48, "latch still holds the old rail")

            // The parking only happens while the reveal is in flight: that is
            // when the content prefers the cached height over the live one, and
            // it is exactly the window during which the blank band is visible.
            // At rest the content reads the live rail and looks correct, which
            // is why this reads as a flash rather than a mislayout.
            symptomPopup.revealProgress = 0.5
            wait(0)
            compare(symptomPopup.contentLayer.y, 47, "content parked below a rail that is gone")

            symptomPopup.revealProgress = 1
            compare(symptomPopup.contentLayer.y, 0, "at rest it settles correctly, hiding the cause")

            symptomPopup.sidebarLayer.children[0].height = 48
            symptomPopup.revealProgress = 0
            symptomPopup.revealProgress = 1
            wait(0)
        }

        function test_railCollapsibleLetsTheLatchForget() {
            // Same sequence, with the host telling the layer its rail is
            // optional. The latch is then allowed to record 0, and the content
            // reads the rail live rather than a stale height.
            railedPopup.revealProgress = 0
            wait(0)
            railedPopup.revealProgress = 1
            wait(0)
            compare(railedPopup.stableSidebarHeight, 48)

            railedPopup.railCollapsible = true
            railedPopup.sidebarLayer.children[0].height = 0
            wait(0)
            compare(railedPopup.sidebarLayer.implicitHeight, 0)
            compare(railedPopup.stableSidebarHeight, 0, "latch follows the rail down to 0")

            // Mid-flight is where the blank band appeared; the content has to
            // sit at the top the whole way through.
            railedPopup.revealProgress = 0
            wait(0)
            railedPopup.revealProgress = 0.5
            wait(0)
            compare(railedPopup.contentLayer.y, 0, "content is not parked mid-reveal")
            railedPopup.revealProgress = 1
            wait(0)
            compare(railedPopup.contentLayer.y, 0)

            railedPopup.railCollapsible = false
            railedPopup.sidebarLayer.children[0].height = 48
            railedPopup.revealProgress = 0
            railedPopup.revealProgress = 1
            wait(0)
        }

    function test_upDirectionStacksContentBeforeSidebar() {
            popup.orientation = popup.vertical
            popup.direction = popup.up
            compare(popup.contentLayer.y, 0)
            // Same deliberate 1px overlap as the down direction, mirrored: the
            // sidebar paints above content, so stacking must not leave a seam.
            compare(popup.sidebarLayer.y, Math.max(0, popup.contentLayer.height - 1))
        }

        function test_contentRevealWaitsForDelay() {
            popup.orientation = popup.vertical
            popup.revealProgress = 0.2
            verify(popup.sidebarRevealProgress > popup.contentRevealProgress)
        }

        function test_contentTravelsFartherThanSidebar() {
            popup.orientation = popup.vertical
            popup.direction = popup.down
            popup.opening = true
            popup.contentDelay = Lazer.MotionTokens.settingsContentDelay
            popup.sidebarOffset = -(popup.sidebarLayer.height + 1)
            popup.contentOffset = -(popup.sidebarLayer.height + popup.contentLayer.height + 2)
            popup.revealProgress = 0.5
            compare(popup.contentLayer.transform[0].y, popup.contentOffset * (1 - popup.contentRevealProgress))
            compare(popup.sidebarLayer.transform[0].y, popup.sidebarOffset * (1 - popup.sidebarRevealProgress))
            verify(Math.abs(popup.contentLayer.transform[0].y) > Math.abs(popup.sidebarLayer.transform[0].y))
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
            popup.animateLayerOpacity = false
            popup.horizontalSidebarX = -170
            popup.horizontalContentX = -400
            popup.revealProgress = 0.5
            compare(popup.sidebarLayer.x, -170)
            compare(popup.contentLayer.x, -400)
            compare(popup.sidebarLayer.opacity, 1)
            compare(popup.contentLayer.opacity, 1)
            popup.revealProgress = 0
            compare(popup.clip, false)
            compare(popup.sidebarLayer.x, -170)
            compare(popup.contentLayer.x, -400)
            popup.animateLayerOpacity = true
        }
    }
}
