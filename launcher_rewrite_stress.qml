import QtQuick
import Quickshell
import Quickshell.Io
import "services"

// [DEBUG-rs3] Rewrite-in-place churn: an app rewriting ITS OWN .desktop
// (file count constant -> entry-count signal never fires). Measure whether
// raw DesktopEntries exposes torn snapshots (missing/renamed mid-read).
Item {
    id: root

    property int rounds: 10
    property int round: 0
    property int tornReads: 0
    property int staleNameReads: 0

    readonly property string entryPath: "/tmp/opencode/xdg-data/applications/churnself.desktop"
    readonly property string bodyA: "[Desktop Entry]\\nType=Application\\nName=ChurnSelf\\nExec=true\\nComment=alpha state\\n"
    readonly property string bodyB: "[Desktop Entry]\\nType=Application\\nName=ChurnSelf\\nExec=true\\nComment=beta state\\nNoDisplay=false\\n"

    function rawEntry() {
        var vals = DesktopEntries.applications.values
        for (var i = 0; i < vals.length; i++)
            if (vals[i] && String(vals[i].id) === "churnself") return vals[i]
        return null
    }

    Process {
        id: sh
        property var next: null
        command: ["sh", "-c", ""]
        stdout: StdioCollector {}
        onExited: function(code) { if (next) next() }
        function run(cmd, then) { next = then; command = ["sh", "-c", cmd]; running = true }
    }

    function finish() {
        console.log("[DEBUG-rs3] SUMMARY rewrite rounds=" + rounds
                    + " torn=" + tornReads + " staleName=" + staleNameReads)
        LauncherService.close()
        sh.run("rm -f " + entryPath, function() { Qt.quit() })
    }

    // Poll raw entry comment until it equals `want`; log every distinct
    // intermediate snapshot (torn reads).
    function awaitComment(want, cont) {
        var seen = {}
        var t = Qt.createQmlObject(
            "import QtQuick; Timer { interval: 60; repeat: true; property int tries: 0 }",
            root, "ac")
        t.triggered.connect(function() {
            t.tries++
            var e = rawEntry()
            var c = e ? String(e.comment == null ? "" : e.comment) : "<absent>"
            if (!seen[c]) {
                seen[c] = true
                console.log("[DEBUG-rs3] r" + round + " t" + t.tries + " snapshot comment='" + c + "'"
                            + (e && e.noDisplay ? " noDisplay=true" : ""))
                if (e && (!String(e.name || "").length))
                    tornReads++
            }
            if ((e && c === want) || t.tries > 50) {
                if (t.tries > 50 && !(e && c === want)) staleNameReads++
                t.stop(); t.destroy(); cont()
            }
        })
        t.restart()
    }

    Component.onCompleted: {
        sh.run("rm -f " + entryPath, function() { startRound() })
    }
    function startRound() {
        round++
        if (round > rounds) { finish(); return }
        sh.run("printf '" + bodyA + "' > " + entryPath, function() {
            awaitComment("alpha state", function() {
                sh.run("printf '" + bodyB + "' > " + entryPath, function() {
                    awaitComment("beta state", function() { Qt.callLater(startRound) })
                })
            })
        })
    }
}
