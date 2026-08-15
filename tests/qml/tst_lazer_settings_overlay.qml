import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify the settings overlay owns two independently moving layers with a
// 200ms content-readiness gate, osu-style stagger, and escape-to-close.
Item {
    id: host
    width: 960
    height: 640

    Item { id: opener; focus: true }
    Lazer.LazerSettingsOverlay { id: overlay; anchors.fill: parent }
    SignalSpy { id: closedSpy; target: overlay; signalName: "closed" }
    SignalSpy { id: requestSpy; target: overlay; signalName: "closeRequested" }

    TestCase {
        name: "LazerSettingsOverlay"
        when: windowShown

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            if (overlay.phase !== "closed")
                overlay.resetImmediately()
            closedSpy.clear()
            requestSpy.clear()
        }

        function cleanup() {
            if (overlay.phase !== "closed")
                overlay.resetImmediately()
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_requiredGeometryAndLayerAliases() {
            compare(overlay.requiredWidth, 570)
            compare(overlay.panelHost.width, 570)
            compare(overlay.panelHost.height, host.height)
            compare(overlay.panelEnterDuration, 600)
            compare(overlay.panelExitDuration, 600)
            verify(overlay.sidebarLayer)
            verify(overlay.contentLayer)
            compare(overlay.panel.width, overlay.requiredWidth)
            compare(overlay.blocksDesktop, false)
        }

        function test_openMovesLayersIndependently() {
            overlay.openFrom(opener)
            verify(overlay.interactive)
            verify(overlay.blocksDesktop)
            verify(overlay.sidebarLayer.x < 0)
            verify(overlay.contentLayer.x < 0)
            verify(overlay.contentLayer.x < overlay.sidebarLayer.x)
            tryCompare(overlay, "phase", "open", 1200)
            compare(overlay.sidebarLayer.x, 0)
            compare(overlay.contentLayer.x, 170)
            compare(overlay.panel.progress, 1)
            verify(overlay.panel.contentReady)
        }

        function test_contentReadyDelaysAndFocusesSearch() {
            overlay.openFrom(opener)
            verify(!overlay.panel.contentReady)
            tryVerify(function() { return overlay.panel.contentReady }, 600)
            verify(overlay.panel.searchField.activeFocus)
        }

        function test_quickCloseCancelsReadiness() {
            overlay.openFrom(opener)
            overlay.closeWithoutFocusRestore()
            wait(300)
            verify(!overlay.panel.contentReady)
            tryCompare(overlay, "phase", "closed", 1200)
        }

        function test_reopenRetargetsFromCurrentProgress() {
            overlay.openFrom(opener)
            tryVerify(function() { return overlay.progress > 0 && overlay.progress < 1 }, 300)
            overlay.closeWithoutFocusRestore()
            wait(60)
            var before = overlay.progress
            overlay.openFrom(opener)
            verify(overlay.progress >= before - 0.03)
            tryCompare(overlay, "phase", "open", 1200)
        }

        function test_closeRestoresOpenerOnlyAfterFinalClose() {
            overlay.openFrom(opener)
            tryCompare(overlay, "phase", "open", 1200)
            verify(!opener.activeFocus)
            overlay.closeAndRestoreFocus()
            tryCompare(overlay, "phase", "closed", 1200)
            verify(opener.activeFocus)
            compare(closedSpy.count, 1)
        }

        function test_escapeClosesAndResetsStagger() {
            overlay.openFrom(opener)
            tryCompare(overlay, "phase", "open", 1200)
            verify(overlay.panel.appearanceNav.appearOpacity > 0)
            overlay.panel.currentNav.forceActiveFocus()
            keyPress(Qt.Key_Escape)
            compare(requestSpy.count, 1)
            compare(overlay.panel.appearanceNav.appearOpacity, 0)
            tryCompare(overlay, "phase", "closed", 1200)
        }

        function test_reopenAfterCloseDefaultsExpandedAndClearsSearch() {
            overlay.openFrom(opener)
            tryCompare(overlay, "phase", "open", 1200)
            overlay.panel.toggleExpanded()
            tryCompare(overlay.panel, "sidebarExpanded", false, 600)
            overlay.panel.searchQuery = "模糊"
            overlay.closeAndRestoreFocus()
            tryCompare(overlay, "phase", "closed", 1200)
            overlay.openFrom(opener)
            compare(overlay.panel.sidebarExpanded, true)
            compare(overlay.panel.searchQuery, "")
            tryCompare(overlay, "phase", "open", 1200)
        }

        function test_reducedMotionRemovesTranslation() {
            Lazer.MotionTokens.reducedMotionOverride = true
            overlay.openFrom(opener)
            compare(overlay.sidebarLayer.x, 0)
            compare(overlay.contentLayer.x, 170)
            tryCompare(overlay, "phase", "open", 250)
            compare(overlay.panel.appearanceNav.appearOpacity, 1)
        }

        function test_settingsBindingsRemainAvailable() {
            verify(overlay.panel.appearancePage)
            verify(overlay.panel.barPage)
            verify(overlay.panel.notificationPage)
            verify(overlay.panel.sidePanel)
            verify(overlay.panel.interactive === false)
        }
    }
}
