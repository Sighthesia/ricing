import QtQuick
import QtTest
import "../../modules/lazerbar"
import "../../modules/lazerbar/WaveSurfaceLogic.js" as Logic

// Exercise the content-agnostic wave owner: geometry, close zones, lifecycle, focus, and reduced motion.
Item {
    id: testRoot
    width: 800
    height: 600

    Item { id: opener; focus: true }

    // The test mounts arbitrary launcher-like data to prove the shell renders without interpreting it.
    WaveSurfaceHost {
        id: host
        anchors.fill: parent
        title: "Launcher"
        description: "search everything"
        sidebarEntries: [
            { id: "apps", label: "Apps" },
            { id: "clipboard", label: "Clipboard" },
            { id: "shortcuts", label: "Shortcuts" }
        ]
        activeSidebarId: "apps"
        contentComponent: sampleContentComponent
    }

    Component {
        id: sampleContentComponent
        Rectangle { color: "#101010" }
    }

    SignalSpy { id: closedSpy; target: host; signalName: "closed" }
    SignalSpy { id: sidebarSpy; target: host; signalName: "sidebarSelected" }

    TestCase {
        name: "WaveSurfaceHost"
        when: windowShown

        function init() {
            MotionTokens.reducedMotionOverride = false
            if (host.phase !== "closed")
                host.finishClose()
            host.phase = "closed"
            host.route = ""
            host.bodyProgress = 0
            host.waveProgress = 0
            host.inputActive = false
            host.pageCanGoBack = false
            host.title = "Launcher"
            host.description = "search everything"
            // Re-assert imperatively so tests that swap entries cannot break this binding.
            host.sidebarEntries = [
                { id: "apps", label: "Apps" },
                { id: "clipboard", label: "Clipboard" },
                { id: "shortcuts", label: "Shortcuts" }
            ]
            closedSpy.clear()
            sidebarSpy.clear()
        }

        function initTestCase() {
            // A future route registered through the extension seam drives the cross-fade test.
            Logic.registerRoute("gallery")
        }

        function cleanup() {
            if (host.phase !== "closed")
                host.finishClose()
            MotionTokens.reducedMotionOverride = false
        }

        function test_geometryAndViewportCentering() {
            compare(host.surfaceWidth, 680)
            compare(host.surface.radius, 0)
            compare((testRoot.width - host.surfaceWidth) / 2, 60)
            compare(host.waveRepeater.count, 4)
            compare(host.waveRepeater.itemAt(0).angle, 13)
            compare(host.waveRepeater.itemAt(1).angle, -7)
            compare(host.waveRepeater.itemAt(2).angle, 4)
            compare(host.waveRepeater.itemAt(3).angle, -2)
        }

        function test_contentRoutesStayClosed() {
            verify(!host.openRoute("settings", opener))
            verify(!host.openRoute("music", opener))
            verify(!host.openRoute("wiki", opener))
            verify(!host.openRoute("news", opener))
            verify(!host.openRoute("beatmap", opener))
            compare(host.phase, "closed")
            compare(host.visible, false)
        }

        function test_openCloseAndReverseFromCurrentProgress() {
            compare(host.visible, false)
            verify(host.openRoute("launcher", opener))
            compare(host.visible, true)
            tryCompare(host, "phase", "open", 1600)
            compare(host.bodyProgress, 1)
            compare(host.waveProgress, 1)

            host.close()
            tryVerify(function() { return host.bodyProgress > 0 && host.bodyProgress < 1 }, 300)
            var beforeReverse = host.bodyProgress
            verify(host.openRoute("gallery", opener))
            verify(host.bodyProgress >= beforeReverse - 0.03)
            tryCompare(host, "phase", "open", 1600)
            compare(host.route, "gallery")
        }

        function test_backdropLeadsBodyDuringOpen() {
            verify(host.openRoute("launcher", opener))
            // Tuned waveBackdropEnter (600ms) completes ahead of the body slide (800ms).
            tryCompare(host, "waveProgress", 1, 700)
            verify(host.bodyProgress < 1)
            tryCompare(host, "phase", "open", 400)
        }

        function test_sameOwnerRouteCrossFadeKeepsShellOpen() {
            verify(host.openRoute("launcher", opener))
            tryCompare(host, "phase", "open", 1600)
            var bodyBefore = host.bodyProgress
            verify(host.openRoute("gallery", opener))
            tryCompare(host, "route", "gallery", 300)
            compare(host.phase, "open")
            compare(host.bodyProgress, bodyBefore)
            verify(host.contentItem)
        }

        function test_sideZonesUseFullCloseLifecycle() {
            verify(host.openRoute("launcher", opener))
            tryCompare(host, "phase", "open", 1600)
            mouseClick(host.outsideLeft, host.outsideLeft.width / 2, 20)
            compare(host.phase, "closing")
            tryCompare(host, "phase", "closed", 800)
            compare(closedSpy.count, 1)

            verify(host.openRoute("launcher", opener))
            tryCompare(host, "phase", "open", 1600)
            mouseClick(host.outsideRight, host.outsideRight.width / 2, 20)
            compare(host.phase, "closing")
        }

        function test_escapePrecedence() {
            verify(host.openRoute("launcher", opener))
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
            tryCompare(host, "phase", "closed", 800)
            compare(closedSpy.count, 1)
        }

        function test_focusRestoresToOpenerAfterClose() {
            verify(opener.activeFocus)
            verify(host.openRoute("launcher", opener))
            tryVerify(function() { return host.activeFocus }, 300)
            host.finishClose()
            compare(host.phase, "closed")
            tryVerify(function() { return opener.activeFocus }, 300)
        }

        function test_sidebarRendersEntriesAndEmitsSelection() {
            compare(host.sidebar.width, 220)
            verify(host.openRoute("launcher", opener))
            tryCompare(host, "phase", "open", 1600)
            compare(host.sidebar.visible, true)
            mouseClick(host.sidebar, host.sidebar.width / 2, 18 + 42 + 2 + 21)
            tryCompare(sidebarSpy, "count", 1)
            compare(sidebarSpy.signalArguments[0][0], "clipboard")
            compare(host.activeSidebarId, "apps")

            host.sidebarEntries = []
            compare(host.sidebar.visible, false)
        }

        function test_normalMotionSlidesBodyFromBelow() {
            verify(host.openRoute("launcher", opener))
            compare(host.surface.y, testRoot.height)
            tryCompare(host, "phase", "open", 1600)
            compare(host.surface.y, 0)
        }

        function test_reducedMotionPinsBodyAndFinishesFast() {
            MotionTokens.reducedMotionOverride = true
            verify(host.openRoute("launcher", opener))
            compare(host.surface.y, 0)
            tryCompare(host, "phase", "open", 400)
            compare(host.surface.y, 0)
            compare(host.waveProgress, 1)
            host.close()
            tryCompare(host, "phase", "closing", 200)
            tryCompare(host, "phase", "closed", 400)
        }
    }
}
