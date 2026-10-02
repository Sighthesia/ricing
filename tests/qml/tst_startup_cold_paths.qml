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

    TestCase {
        name: "StartupColdPaths"

        function test_closedWaveDoesNotConstructRoutePage() {
            verify(root.waveHost.length > 1000)
            verify(root.waveHost.indexOf('active: root.phase !== "closed"') >= 0,
                   "route content must not load while the wave is closed")
        }

        function test_launcherPrewarmWaitsForExplicitStartupGate() {
            verify(root.launcher.indexOf("startupPrewarmAllowed") >= 0)
            verify(root.launcher.indexOf(
                       "running: !!root.session && root.startupPrewarmAllowed === true") >= 0)
            verify(root.shell.indexOf("startupPrewarmAllowed: root.startupWorkFinished") >= 0)
        }
    }
}
