import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Define the host and focus fixtures for the settings overlay contract.
Item {
    id: host
    width: 960
    height: 640

    Item { id: opener; width: 24; height: 24; focus: true }
    Lazer.LazerSettingsOverlay { id: overlay; width: host.width; height: host.height }

    SignalSpy { id: closedSpy; target: overlay; signalName: "closed" }
    SignalSpy { id: requestSpy; target: overlay; signalName: "closeRequested" }

    TestCase {
        name: "LazerSettingsOverlay"
        when: windowShown

        function init() {
            overlay.phase = "closed"
            overlay.progress = 0
            overlay.scrimProgress = 0
            overlay.entryDirection = 1
            overlay.opener = null
            closedSpy.clear()
            requestSpy.clear()
            wait(10)
        }

        function test_fixedHostAndPanelSizingContract() {
            compare(overlay.width, host.width)
            compare(overlay.height, host.height)
            compare(overlay.panel.availableWidth, host.width)
            compare(overlay.panel.availableHeight, host.height)
            compare(overlay.panel.width, overlay.panel.panelWidth)
            compare(overlay.panel.height, overlay.panel.panelHeight)
            compare(overlay.panel.y, 0)
            compare(overlay.panelHost.y - overlay.panelRestY, overlay.panelOffsetY)
            compare(overlay.panelEnterDuration, 320)
            compare(overlay.panelExitDuration, 240)
            compare(overlay.scrimDuration, 180)
            compare(overlay.scrimTargetOpacity, 0.6)
        }

        function test_openLifecycleAndTopBottomDirection() {
            overlay.openFrom(opener, -1)
            compare(overlay.phase, "opening")
            verify(overlay.interactive)
            verify(overlay.blocksDesktop)
            compare(overlay.entryDirection, -1)
            verify(overlay.panelOffsetY < 0)
            compare(overlay.panelHost.y - overlay.panelRestY, overlay.panelOffsetY)
            tryCompare(overlay, "phase", "open", 400)
            compare(overlay.progress, 1)
            compare(overlay.scrimProgress, 1)
            compare(overlay.scrim.opacity, 0.6)

            overlay.closeWithoutFocusRestore()
            compare(overlay.phase, "closing")
            verify(!overlay.interactive)
            verify(overlay.blocksDesktop)
            tryCompare(overlay, "phase", "closed", 320)
            verify(!overlay.blocksDesktop)

            overlay.openFrom(opener, 1)
            verify(overlay.panelOffsetY > 0)
            verify(overlay.panelHost.y > overlay.panelRestY)
            tryCompare(overlay, "phase", "open", 400)
        }

        function test_reducedMotionKeepsOpacityButRemovesTranslation() {
            Lazer.MotionTokens.reducedMotionOverride = true
            overlay.openFrom(opener, -1)
            compare(overlay.panelOffsetY, 0)
            compare(overlay.panelHost.y, overlay.panelRestY)
            verify(overlay.panel.opacity < 1)
            tryCompare(overlay, "phase", "open", 120)
            compare(overlay.panelOffsetY, 0)
            overlay.closeWithoutFocusRestore()
            compare(overlay.panelOffsetY, 0)
            tryCompare(overlay, "phase", "closed", 120)
            Lazer.MotionTokens.reducedMotionOverride = false

            overlay.openFrom(opener, 1)
            verify(overlay.panelOffsetY > 0)
            compare(overlay.panelHost.y - overlay.panelRestY, overlay.panelOffsetY)
            wait(70)
            verify(overlay.panelOffsetY < overlay.panelHost.height)
            tryCompare(overlay, "phase", "open", 400)
        }

        function test_closeRequestScrimAndEscapeAreModal() {
            overlay.openFrom(opener, 1)
            tryCompare(overlay, "phase", "open", 400)
            mouseClick(overlay.scrim, 20, 20)
            compare(requestSpy.count, 1)
            compare(overlay.phase, "closing")
            tryCompare(overlay, "phase", "closed", 320)

            overlay.openFrom(opener, 1)
            tryCompare(overlay, "phase", "open", 400)
            overlay.panel.requestClose()
            compare(requestSpy.count, 2)
            compare(overlay.phase, "closing")

            tryCompare(overlay, "phase", "closed", 320)
            overlay.openFrom(opener, 1)
            tryCompare(overlay, "phase", "open", 400)
            requestSpy.clear()
            keyPress(Qt.Key_Escape)
            compare(requestSpy.count, 1)
            compare(overlay.phase, "closing")
        }

        function test_panelBlankAreaIsolatedButNavigationRemainsInteractive() {
            overlay.openFrom(opener, 1)
            tryCompare(overlay, "phase", "open", 400)
            requestSpy.clear()
            mouseClick(overlay.panel, overlay.panel.width - 4, overlay.panel.height - 4)
            compare(requestSpy.count, 0)
            compare(overlay.phase, "open")

            mouseClick(overlay.panel.barNav, overlay.panel.barNav.width / 2, overlay.panel.barNav.height / 2)
            compare(overlay.panel.selectedCategory, "bar")
        }

        function test_tabTrapCyclesNavigationAndClose() {
            overlay.openFrom(opener, 1)
            tryCompare(overlay, "phase", "open", 400)
            overlay.panel.currentNav.forceActiveFocus()
            verify(overlay.panel.currentNav.activeFocus)
            keyPress(Qt.Key_Tab)
            verify(overlay.panel.closeButton.activeFocus)
            overlay.panel.closeButton.forceActiveFocus()
            keyPress(Qt.Key_Tab)
            verify(overlay.panel.currentNav.activeFocus)
            overlay.panel.currentNav.forceActiveFocus()
            keyPress(Qt.Key_Backtab)
            verify(overlay.panel.closeButton.activeFocus)
            overlay.panel.closeButton.forceActiveFocus()
            keyPress(Qt.Key_Tab, Qt.ShiftModifier)
            verify(overlay.panel.currentNav.activeFocus)
            verify(!opener.activeFocus)
        }

        function test_cycleFocusMethodUsesModalRing() {
            overlay.openFrom(opener, 1)
            tryCompare(overlay, "phase", "open", 400)
            overlay.panel.currentNav.forceActiveFocus()
            overlay.cycleFocus(false)
            verify(overlay.panel.closeButton.activeFocus)
            overlay.cycleFocus(false)
            verify(overlay.panel.currentNav.activeFocus)
            overlay.cycleFocus(true)
            verify(overlay.panel.closeButton.activeFocus)
            overlay.panel.forceActiveFocus()
            overlay.cycleFocus(true)
            verify(overlay.panel.closeButton.activeFocus)
        }

        function test_reopenFromClosingRetargetsCurrentProgress() {
            overlay.openFrom(opener, 1)
            wait(70)
            overlay.closeWithoutFocusRestore()
            var closingProgress = overlay.progress
            verify(closingProgress > 0 && closingProgress < 1)
            overlay.openFrom(opener, -1)
            compare(overlay.phase, "opening")
            verify(overlay.progress >= closingProgress)
            compare(overlay.entryDirection, -1)
            tryCompare(overlay, "phase", "open", 400)
            compare(overlay.progress, 1)
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
            overlay.phase = "closed"
            overlay.progress = 0
            overlay.scrimProgress = 0
        }
    }
}
