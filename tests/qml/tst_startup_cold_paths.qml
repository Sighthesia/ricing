import QtQuick
import QtTest

// Static wiring contracts for startup cold paths that cannot be mounted by
// qmltestrunner: the production files import Quickshell and contain surfaces.
// The test reads those files rather than duplicating their decision logic.
Item {
    id: root

    function readText(path) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl(path), false)
        xhr.send(null)
        return xhr.status === 200 ? xhr.responseText : ""
    }

    readonly property string waveHost: readText("../../modules/lazerbar/WaveSurfaceHost.qml")
    readonly property string launcher: readText("../../modules/lazerbar/LauncherSurface.qml")
    readonly property string topBar: readText("../../modules/bar/TopBar.qml")
    readonly property string shell: readText("../../shell.qml")
    readonly property string wallpaper: readText("../../modules/lazerbar/WallpaperBackground.qml")

    TestCase {
        name: "StartupColdPaths"

        function test_closedWaveCanKeepAnIdlePrewarmedRoute() {
            verify(root.waveHost.length > 1000)
            verify(root.waveHost.indexOf(
                       'active: root.phase !== "closed" || root.routeRetained') >= 0,
                   "route content must stay inactive until an open or idle prewarm")
            verify(root.waveHost.indexOf("function prewarmRoute()") >= 0,
                   "the host needs an explicit idle prewarm seam")
        }

        function test_launcherPrewarmWaitsForExplicitStartupGate() {
            verify(root.launcher.indexOf("startupPrewarmAllowed") >= 0)
            verify(root.launcher.indexOf(
                       "running: !!root.session && root.startupPrewarmAllowed === true") >= 0)
            verify(root.launcher.indexOf("onTriggered: waveHost.prewarmRoute()") >= 0,
                   "the idle prewarm must retain the real route")
            verify(root.launcher.indexOf("prewarmLoader") < 0,
                   "a duplicate hidden page must not be constructed")
            verify(root.shell.indexOf("startupPrewarmAllowed: root.startupWorkFinished") >= 0)
        }

        // The bar arrives by sliding in from out of its own viewport, and the
        // slide offset must read the combined progress — not `revealProgress`
        // directly, which would leave the startup expansion with no effect on the
        // geometry at all. Read as text because TopBar.qml is a PanelWindow tree.
        function test_theBarSlidesInFromItsOwnStartupProgress() {
            verify(root.topBar.indexOf("import \"./StartupBarRevealLogic.js\" as StartupReveal") >= 0,
                   "the shared startup reveal helper must be imported")
            verify(root.topBar.indexOf("property real startupProgress: 0") >= 0,
                   "the bar must start slid out")
            verify(root.topBar.indexOf(
                       "readonly property real slideProgress: StartupReveal.slideProgress(") >= 0,
                   "the combined slide progress must come from the shared helper")
            // The geometry, not some other property, is what has to read it.
            verify(root.topBar.indexOf("y: (1 - screenScope.slideProgress)") >= 0,
                   "the slide geometry must read the combined progress")
            // Line-anchored, because a bare substring search for
            // "y: (1 - screenScope.revealProgress)" also matches the tail of
            // "opacity: (1 - screenScope.revealProgress)" one line further down.
            verify(!/(^|\n)\s*y: \(1 - screenScope\.revealProgress\)/.test(root.topBar),
                   "reading the auto-hide progress alone would strand the startup bar")
            // An unarrived bar is invisible but still over the screen edge, so its
            // input region has to wait too.
            verify(root.topBar.indexOf("StartupReveal.claimsFullRegion(") >= 0,
                   "the input region must wait for the bar to arrive")
        }

        // Per screen, and off this screen's own readiness: gating the arrival on
        // the root's aggregate would make the fast monitor wait for the slow one.
        function test_theBarArrivesWhenItsOwnWidgetsAreStaged() {
            verify(root.topBar.indexOf("function expandAtStartup()") >= 0)
            verify(root.topBar.indexOf("screenScope.expandAtStartup()") >= 0,
                   "the arrival must be triggered")
            verify(root.topBar.indexOf("StartupReveal.latchStartup(") >= 0,
                   "the arrival must be latched, so a later event cannot undo it")
            // Reduced motion has to arrive without travelling, or the one-shot
            // arrival is the one case that cannot be interrupted at all.
            verify(root.topBar.indexOf("if (MotionTokens.reducedMotion)") >= 0,
                   "reduced motion must snap the arrival instead of animating it")
        }

        function test_chromeMountsWhenWallpaperBootStarts() {
            verify(root.wallpaper.indexOf("property bool bootStarted: false") >= 0)
            verify(root.wallpaper.indexOf("root.reportBootStarted()") >= 0)
            verify(root.shell.indexOf("onBootStartedChanged") >= 0)
            verify(root.shell.indexOf("root.mountChromeForWallpaperBootstrap()") >= 0)
        }
    }
}
