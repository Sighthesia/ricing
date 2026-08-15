import QtQuick
import QtTest
import "../../modules/lazerbar"

// Exercise the fixed wave owner, side close zones, and route lifecycle without Quickshell.
Item {
    id: testRoot
    width: 800
    height: 600

    Item { id: opener; focus: true }
    FullscreenOverlayHost { id: host; anchors.fill: parent }
    SignalSpy { id: closedSpy; target: host; signalName: "closed" }

    TestCase {
        name: "FullscreenOverlayHost"
        when: windowShown

        function init() {
            host.phase = "closed"
            host.route = ""
            host.bodyProgress = 0
            host.waveProgress = 0
            host.barPosition = "top"
            host.barHeight = 46
            closedSpy.clear()
        }

        function test_geometryAndWaveLayers() {
            compare(host.surfaceWidth, 680)
            compare(host.surfaceTop, 46)
            compare(host.surface.radius, 0)
            compare(host.waveRepeater.count, 4)
            compare(host.waveRepeater.itemAt(0).angle, 13)
            compare(host.waveRepeater.itemAt(1).angle, -7)
            compare(host.waveRepeater.itemAt(2).angle, 4)
            compare(host.waveRepeater.itemAt(3).angle, -2)
            host.barPosition = "bottom"
            compare(host.surfaceTop, 0)
        }

        function test_invalidCompatibilityRoutesStayClosed() {
            verify(!host.openRoute("settings", opener))
            verify(!host.openRoute("music", opener))
            compare(host.phase, "closed")
        }

        function test_openCloseAndReverseFromCurrentProgress() {
            verify(host.openRoute("wiki", opener))
            tryCompare(host, "phase", "open", 1600)
            compare(host.bodyProgress, 1)
            compare(host.waveProgress, 1)

            host.close()
            tryVerify(function() { return host.bodyProgress > 0 && host.bodyProgress < 1 }, 300)
            var beforeReverse = host.bodyProgress
            verify(host.openRoute("news", opener))
            verify(host.bodyProgress >= beforeReverse - 0.03)
            tryCompare(host, "phase", "open", 1600)
            compare(host.route, "news")
        }

        function test_sameOwnerRouteCrossFadeKeepsShellOpen() {
            host.openRoute("wiki", opener)
            tryCompare(host, "phase", "open", 1600)
            var bodyBefore = host.bodyProgress
            host.openRoute("news", opener)
            tryCompare(host, "route", "news", 300)
            compare(host.phase, "open")
            compare(host.bodyProgress, bodyBefore)
            verify(host.routeItem)
        }

        function test_sideZonesUseFullCloseLifecycle() {
            host.openRoute("beatmap", opener)
            tryCompare(host, "phase", "open", 1600)
            mouseClick(host.outsideLeft, host.outsideLeft.width / 2, 20)
            compare(host.phase, "closing")
            tryCompare(host, "phase", "closed", 800)
            compare(closedSpy.count, 1)

            host.openRoute("wiki", opener)
            tryCompare(host, "phase", "open", 1600)
            mouseClick(host.outsideRight, host.outsideRight.width / 2, 20)
            compare(host.phase, "closing")
        }

        function test_escapePrecedence() {
            host.openRoute("wiki", opener)
            tryCompare(host, "phase", "open", 1600)
            host.inputActive = true
            host.pageCanGoBack = true
            verify(host.handleEscape())
            verify(!host.inputActive)
            compare(host.phase, "open")
            verify(host.handleEscape())
            verify(!host.pageCanGoBack)
            compare(host.phase, "open")
            verify(host.handleEscape())
            compare(host.phase, "closing")
        }

        function cleanup() {
            if (host.phase !== "closed")
                host.finishClose()
            MotionTokens.reducedMotionOverride = false
            host.inputActive = false
            host.pageCanGoBack = false
        }
    }
}
