import QtQuick
import Quickshell
import Quickshell.Io
import "services"

// [DEBUG-rs3] Feedback loop: desktop-entry churn (as launch-triggered
// .desktop rewrites cause) must reach an open or reopening launcher.
// Sandboxed XDG_DATA_HOME applications dir; the harness writes/removes the
// entry file exactly like an app's own rewriter would, and drives the REAL
// LauncherService (real adapters, real DesktopEntries).
Item {
    id: root

    property int failures: 0
    function fail(m) { failures++; console.log("[DEBUG-rs3] FAIL:", m) }
    function pass(m) { console.log("[DEBUG-rs3] PASS:", m) }

    readonly property string entryPath: "/tmp/opencode/xdg-data/applications/afloatchurn.desktop"
    readonly property string entryBody: "[Desktop Entry]\\nType=Application\\nName=Churn Probe\\nExec=true\\nComment=probe entry\\n"

    function hasVisibleProbe() {
        if (LauncherService.loading || !LauncherService.results) return false
        for (var i = 0; i < LauncherService.results.length; i++)
            if (String(LauncherService.results[i].id).indexOf("afloatchurn") >= 0)
                return true
        return false
    }

    Process {
        id: sh
        property var next: null
        command: ["sh", "-c", ""]
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode !== 0) root.fail("shell step failed")
            if (next) next()
        }
        function run(cmd, then) { next = then; command = ["sh", "-c", cmd]; running = true }
    }

    Timer { id: step; interval: 300; property var next; onTriggered: next() }

    // Poll until the open session's visible probe state matches `want`.
    function waitProbe(want, cont, label) {
        var t = Qt.createQmlObject(
            "import QtQuick; Timer { interval: 250; repeat: true; property int tries: 0 }",
            root, "waitTimer")
        t.triggered.connect(function() {
            t.tries++
            var got = hasVisibleProbe()
            if (!LauncherService.loading && got === want) {
                t.stop(); t.destroy(); cont(true)
            } else if (t.tries > 40) {
                t.stop(); t.destroy(); cont(false)
            }
        })
        t.restart()
    }

    Component.onCompleted: { step.next = phase0; step.restart() }
    function finish() {
        console.log(failures === 0 ? "[DEBUG-rs3] ALL GREEN" : "[DEBUG-rs3] RED x" + failures)
        Qt.quit()
    }

    // Phase 0: no entry; open apps mode, search -> empty.
    function phase0() {
        sh.run("rm -f " + entryPath, function() {
            LauncherService.open()
            LauncherService.query = "churn"
            waitProbe(false, function(ok) {
                if (!ok) fail("phase0 probe listed before create")
                else pass("phase0 empty before entry exists")
                phase1()
            }, "p0")
        })
    }

    // Phase 1: create while OPEN; live rescan must surface it.
    function phase1() {
        sh.run("printf '" + entryBody + "' > " + entryPath, function() {
            waitProbe(true, function(ok) {
                if (!ok) fail("phase1 open-panel rescan missed new entry")
                else pass("phase1 live rescan surfaced entry")
                phase2()
            }, "p1")
        })
    }

    // Phase 2: remove while open; must fold away.
    function phase2() {
        sh.run("rm -f " + entryPath, function() {
            waitProbe(false, function(ok) {
                if (ok) {
                    pass("phase2 removal propagated while open")
                } else {
                    fail("phase2 removed entry still listed")
                    // Diagnostic: how long does the RAW DesktopEntries view
                    // take to drop it? Distinguishes quickshell lag from
                    // launcher staleness.
                    var t = Qt.createQmlObject(
                        "import QtQuick; Timer { interval: 500; repeat: true; property int tries: 0 }",
                        root, "diagTimer")
                    t.triggered.connect(function() {
                        t.tries++
                        var vals = DesktopEntries.applications.values
                        var present = false
                        for (var i = 0; i < vals.length; i++)
                            if (vals[i] && String(vals[i].id).indexOf("afloatchurn") >= 0) present = true
                        console.log("[DEBUG-rs3] diag t=" + t.tries + "x500ms rawPresent=" + present
                                    + " listedStill=" + hasVisibleProbe())
                        if (!present || t.tries > 20) { t.stop(); t.destroy(); phase3() }
                    })
                    t.restart()
                    return
                }
                phase3()
            }, "p2")
        })
    }

    // Phase 3 - THE USER SYMPTOM: churn while panel CLOSED, reopen+search.
    function phase3() {
        sh.run("printf '" + entryBody + "' > " + entryPath, function() {
            LauncherService.close()
            waitProbe(false, function(ok) {   // watcher notices while closed
                LauncherService.open()
                LauncherService.query = "churn"
                waitProbe(true, function(ok2) {
                    if (!ok2) fail("phase3 reopen after closed-panel churn missed entry")
                    else pass("phase3 reopen after churn shows entry")
                    finish()
                }, "p3b")
            }, "p3a")
        })
    }
}
