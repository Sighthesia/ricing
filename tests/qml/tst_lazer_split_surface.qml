import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/bar/BarPopupMotion.js" as PopupMotion

// Verify the shared split surface timing and ownership contracts.
Item {
    id: root
    width: 400
    height: 400

    Lazer.LazerSplitSurface {
        id: surface
        width: 320
        height: 200
        revealProgress: 0
        interactive: true
        headerHeight: 48

        Rectangle {
            id: childA
            objectName: "childA"
            width: 20
            height: 20
            color: "red"
        }
        Rectangle {
            id: childB
            objectName: "childB"
            width: 30
            height: 30
            color: "blue"
        }
    }

    TestCase {
        name: "LazerSplitSurface"
        when: windowShown

        function init() {
            surface.revealProgress = 0
            surface.interactive = true
            surface.headerHeight = 48
        }

        function test_progressZeroHidesBothLayers() {
            surface.revealProgress = 0
            compare(surface.headerProgress, 0)
            compare(surface.contentProgress, 0)
            compare(surface.headerSurfaceItem.opacity, 1)
            compare(surface.contentSurfaceItem.opacity, 1)
            verify(!surface.interactable)
            verify(surface.contentSurfaceItem.enabled)
        }

        function test_progressOneShowsBothLayers() {
            surface.revealProgress = 1
            compare(surface.headerProgress, 1)
            compare(surface.contentProgress, 1)
            compare(surface.headerSurfaceItem.opacity, 1)
            compare(surface.contentSurfaceItem.opacity, 1)
            verify(surface.interactable)
            verify(surface.contentSurfaceItem.enabled)
        }

        function test_surfaceMotionDoesNotChangeOpacity() {
            surface.revealProgress = 0.1
            compare(surface.headerSurfaceItem.opacity, 1)
            compare(surface.contentSurfaceItem.opacity, 1)
            surface.revealProgress = 0.8
            compare(surface.headerSurfaceItem.opacity, 1)
            compare(surface.contentSurfaceItem.opacity, 1)
        }

        function test_surfaceMotionTravelsTowardTheDivider() {
            surface.revealProgress = 0
            verify(surface.headerSurfaceItem.transform[0].y < 0)
            verify(surface.contentSurfaceItem.transform[0].y < 0)
            surface.revealProgress = 1
            compare(surface.headerSurfaceItem.transform[0].y, 0)
            compare(surface.contentSurfaceItem.transform[0].y, 0)
        }

        function test_surfaceUsesFullCardTravelWithoutClipping() {
            surface.revealProgress = 0
            compare(surface.headerTravel, surface.headerHeight)
            verify(surface.contentTravel >= surface.contentSurfaceItem.height)
            verify(!surface.clip)
            surface.revealProgress = 1
            compare(surface.headerSurfaceItem.transform[0].y, 0)
            compare(surface.contentSurfaceItem.transform[0].y, 0)
        }

        function test_surfaceLayersTravelFromTheSameBarSide() {
            surface.revealProgress = 0
            verify(surface.headerSurfaceItem.transform[0].y < 0)
            verify(surface.contentSurfaceItem.transform[0].y < 0)
            surface.topAnchored = false
            verify(surface.headerSurfaceItem.transform[0].y > 0)
            verify(surface.contentSurfaceItem.transform[0].y > 0)
            surface.topAnchored = true
        }

        function test_contentProgressStartsAfterDelay() {
            var total = Lazer.MotionTokens.settingsSidebarFade + Lazer.MotionTokens.settingsContentDelay
            var delay = Lazer.MotionTokens.settingsContentDelay
            var fade = Lazer.MotionTokens.settingsSidebarFade
            // Before delay threshold content should remain at 0 while header advances.
            surface.revealProgress = 0.2
            var expectedHeader = PopupMotion.headerProgress(0.2, total, fade)
            var expectedContent = PopupMotion.contentProgress(0.2, total, delay, fade)
            compare(surface.headerProgress, expectedHeader)
            compare(surface.contentProgress, expectedContent)
            verify(surface.headerProgress > 0)
            compare(surface.contentProgress, 0)
            // After delay content starts to rise.
            surface.revealProgress = 0.5
            expectedHeader = PopupMotion.headerProgress(0.5, total, fade)
            expectedContent = PopupMotion.contentProgress(0.5, total, delay, fade)
            compare(surface.headerProgress, expectedHeader)
            compare(surface.contentProgress, expectedContent)
            verify(surface.contentProgress > 0)
            verify(surface.contentProgress < 1)
            verify(surface.headerProgress > surface.contentProgress)
        }

        function test_interactableGatedByInteractiveAndContentProgress() {
            surface.interactive = true
            surface.revealProgress = 1
            verify(surface.interactable)
            surface.revealProgress = 0.5
            verify(!surface.interactable)
            surface.revealProgress = 1
            surface.interactive = false
            verify(!surface.interactable)
            surface.interactive = true
            verify(surface.interactable)
        }

        function test_contentChildrenParentedBelowContentSurface() {
            compare(childA.parent, surface.contentSurfaceItem)
            compare(childB.parent, surface.contentSurfaceItem)
            verify(childA.parent !== surface)
            verify(childB.parent !== surface)
            verify(surface.contentSurfaceItem.children.length >= 2)
        }

        function test_surfaceAliasesAndHeaderGeometry() {
            verify(surface.headerSurfaceItem !== null)
            verify(surface.contentSurfaceItem !== null)
            verify(surface.dividerItem !== null)
            compare(surface.headerSurfaceItem.height, 48)
            compare(surface.dividerItem.height, 1)
            surface.headerHeight = 60
            compare(surface.headerSurfaceItem.height, 60)
            surface.headerHeight = 48
        }

        function test_contentColorAlias() {
            var initial = surface.contentColor
            surface.contentColor = "#123456"
            compare(surface.contentSurfaceItem.color, "#123456")
            surface.contentColor = initial
        }
    }
}
