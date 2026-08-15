import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify the dedicated left-side Settings lifecycle, focus, and fixed geometry.
Item {
    id: host; width: 960; height: 640
    Item { id: opener; focus: true }
    Lazer.LazerSettingsOverlay { id: overlay; anchors.fill: parent }
    SignalSpy { id: closedSpy; target: overlay; signalName: "closed" }
    SignalSpy { id: requestSpy; target: overlay; signalName: "closeRequested" }
    TestCase {
        name: "LazerSettingsOverlay"; when: windowShown
        function init() { overlay.resetImmediately(); closedSpy.clear(); requestSpy.clear(); Lazer.MotionTokens.reducedMotionOverride = false }
        function cleanup() { if (overlay.phase !== "closed") overlay.resetImmediately(); Lazer.MotionTokens.reducedMotionOverride = false }
        function test_leftGeometryAndTiming() {
            compare(overlay.requiredWidth, 616)
            compare(overlay.panelHost.width, 616)
            compare(overlay.panelHost.height, host.height)
            compare(overlay.panelHost.y, 0)
            compare(overlay.panelEnterDuration, 600); compare(overlay.panelExitDuration, 600)
            overlay.openFrom(opener); verify(overlay.panelOffsetX < 0); compare(overlay.panelHost.x, overlay.panelOffsetX)
            tryCompare(overlay, "phase", "open", 800); compare(overlay.panelOffsetX, 0)
        }
        function test_closeEscapeAndFocus() {
            overlay.openFrom(opener); tryCompare(overlay, "phase", "open", 800)
            overlay.panel.currentNav.forceActiveFocus(); keyPress(Qt.Key_Escape)
            compare(requestSpy.count, 1); compare(overlay.phase, "closing")
            tryCompare(overlay, "phase", "closed", 800); compare(closedSpy.count, 1); verify(opener.activeFocus)
        }
        function test_reopenRetargetsCurrentProgress() {
            overlay.openFrom(opener); tryVerify(function(){ return overlay.progress > 0 && overlay.progress < 1 }, 300)
            overlay.closeWithoutFocusRestore(); wait(60); var before = overlay.progress
            overlay.openFrom(opener); verify(overlay.progress >= before - 0.03); tryCompare(overlay, "phase", "open", 800)
        }
        function test_reducedMotionRemovesTranslation() {
            Lazer.MotionTokens.reducedMotionOverride = true; overlay.openFrom(opener)
            compare(overlay.panelOffsetX, 0); tryCompare(overlay, "phase", "open", 250)
        }
        function test_settingsBindingsRemainAvailable() {
            verify(overlay.panel.appearancePage); verify(overlay.panel.barPage); verify(overlay.panel.notificationPage)
            verify(overlay.panel.sidePanel); compare(overlay.panel.width, overlay.requiredWidth)
        }
    }
}
