import QtQuick
import Quickshell
import Quickshell.Io
import "services"

// [DEBUG-rs3] Stress loop: measure removal propagation across N churn
// rounds - raw DesktopEntries view vs the open launcher's list.
Item {
    id: root

    property int rounds: 12
    property int round: 0
    property int removeFails: 0
    property int addFails: 0
    // per-round timings
    property int rawLagMs: 0
    property int listLagMs: 0

    readonly property string entryPath: "/tmp/opencode/xdg-data/applications/afloatchurn.desktop"
    readonly property string entryBody: "[Desktop Entry]\\nType=Application\\nName=Churn Probe\\nExec=true\\nComment=probe entry\\n"

    function rawPresent() {
        var vals = DesktopEntries.applications.values
        for (var i = 0; i < vals.length; i++)
            if (vals[i] && String(vals[i].id).indexOf("afloatchurn") >= 0) return true
        return false
    }
    function listHasProbe() {
        var res = LauncherService.results
        if (!res) return false
        for (var i = 0; i < res.length; i++)
            if (String(res[i].id).indexOf("afloatchurn") >= 0) return true
        return false
    }

    Process {
        id: sh
        property var next: null
        command: ["sh", "-c", ""]
        stdout: StdioCollector {}
        onExited: function(code) { if (code !== 0) console.log("[DEBUG-rs3] sh fail"); if (next) next() }
        function run(cmd, then) { next = then; command = ["sh", "-c", cmd]; running = true }
    }

    function waitList(want, ms, cont) {
        var t = Qt.createQmlObject(
            "import QtQuick; Timer { interval: 100; repeat: true; property int tries: 0 }",
            root, "wl")
        t.triggered.connect(function() {
            t.tries++
            if (listHasProbe() === want || t.tries * 100 > ms) {
                t.stop(); t.destroy(); cont(listHasProbe() === want)
            }
        })
        t.restart()
    }

    Component.onCompleted: {
        sh.run("rm -f " + entryPath, function() {
            LauncherService.open()
            LauncherService.query = ""
            startRound()
        })
    }

    function startRound() {
        round++
        if (round > rounds) { report(); return }
        // ADD phase: file in; wait until listed (max 6s).
        sh.run("printf '" + entryBody + "' > " + entryPath, function() { waitList(true, 6000, function(listed) {
            if (!listed) { addFails++; console.log("[DEBUG-rs3] r" + round + " ADD never listed") }
            // REMOVE phase: file gone; measure raw vs list propagation.
            rawLagMs = -1; listLagMs = -1
            var t0 = Date.now()
            sh.run("rm -f " + entryPath, function() {
                pollRemoval(t0)
            })
        }) })
    }

    function pollRemoval(t0) {
        var t = Qt.createQmlObject(
            "import QtQuick; Timer { interval: 100; repeat: true; property int tries: 0 }",
            root, "pr")
        t.triggered.connect(function() {
            t.tries++
            var elapsed = Date.now() - t0
            if (rawLagMs < 0 && !rawPresent()) rawLagMs = elapsed
            if (listLagMs < 0 && !listHasProbe()) listLagMs = elapsed
            if ((rawLagMs >= 0 && listLagMs >= 0) || t.tries > 80) {
                t.stop(); t.destroy()
                console.log("[DEBUG-rs3] r" + round + " rawLag=" + rawLagMs + "ms listLag=" + listLagMs + "ms"
                            + (listLagMs < 0 ? "  LIST-STALE" : "") + (rawLagMs < 0 ? "  RAW-STALE" : ""))
                if (listLagMs < 0) removeFails++
                Qt.callLater(startRound)
            }
        })
        t.restart()
    }

    function report() {
        console.log("[DEBUG-rs3] SUMMARY rounds=" + rounds + " removeStale=" + removeFails + " addFail=" + addFails)
        LauncherService.close()
        Qt.quit()
    }
}
