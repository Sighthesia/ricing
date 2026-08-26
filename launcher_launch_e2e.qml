import QtQuick
import Quickshell
import Quickshell.Io
import "services"

// [DEBUG-rs3] End-to-end user flow: launch an app from search, then
// repeatedly reopen + search, measuring how long the app stays invisible.
Item {
    id: root

    property int cycles: 5
    property int cycle: 0

    readonly property string entryPath: "/tmp/opencode/xdg-data/applications/churnlaunch.desktop"
    readonly property string body: "[Desktop Entry]\nType=Application\nName=ChurnLaunch\nExec=/tmp/opencode/selfrewrite.sh " + entryPath + "\nComment=e2e probe\n"

    Process {
        id: sh
        property var next: null
        command: ["sh", "-c", ""]
        stdout: StdioCollector {}
        onExited: function(code) { if (next) next() }
        function run(cmd, then) { next = then; command = ["sh", "-c", cmd]; running = true }
    }

    function listed() {
        var res = LauncherService.results
        if (!res) return false
        for (var i = 0; i < res.length; i++)
            if (String(res[i].id) === "churnlaunch") return true
        return false
    }

    Timer { id: step; interval: 400; property var next; onTriggered: next() }

    Component.onCompleted: {
        sh.run("printf '" + body + "' > " + entryPath, function() { startCycle() })
    }
    function finish() {
        console.log("[DEBUG-rs3] DONE")
        LauncherService.close()
        sh.run("rm -f " + entryPath, function() { Qt.quit() })
    }

    function startCycle() {
        cycle++
        if (cycle > cycles) { finish(); return }
        // Fresh open + search.
        sh.run("rm -f " + entryPath + "; sleep 1.2; printf '" + body + "' > " + entryPath,
               function() {
            LauncherService.close()
            step.next = openAndSearch
            step.interval = 300
            step.restart()
        })
    }
    function openAndSearch() {
        LauncherService.open()
        LauncherService.query = "churnlaunch"
        waitReady(function() {
            if (!listed()) { fail("entry missing pre-launch c" + cycle); return nextCycle() }
            pass("visible pre-launch c" + cycle)
            // LAUNCH via the session like Enter does.
            var target = null
            for (var i = 0; i < LauncherService.results.length; i++)
                if (String(LauncherService.results[i].id) === "churnlaunch") target = LauncherService.results[i]
            waitSettled(function() {
                LauncherService.execute(target)
                waitClosed(function() {
                    // Reopen immediately and measure invisible window.
                    reopenProbe(0)
                })
            })
        })
    }
    function waitSettled(cont) { step.next = cont; step.interval = 250; step.restart() }
    function waitClosed(cont) {
        var t = Qt.createQmlObject("import QtQuick; Timer { interval: 150; repeat: true; property int tries: 0 }", root, "wc")
        t.triggered.connect(function() {
            t.tries++
            if (!LauncherService.visible || t.tries > 30) { t.stop(); t.destroy(); cont() }
        })
        t.restart()
    }
    function fail(m) { console.log("[DEBUG-rs3] FAIL:", m) }
    function pass(m) { console.log("[DEBUG-rs3] PASS:", m) }

    function reopenProbe(elapsedMs) {
        LauncherService.open()
        LauncherService.query = "churnlaunch"
        waitReady(function() {
            if (listed()) {
                pass("c" + cycle + " visible again after ~" + elapsedMs + "ms")
                nextCycle()
            } else if (elapsedMs > 8000) {
                fail("c" + cycle + " still invisible after " + elapsedMs + "ms")
                nextCycle()
            } else {
                step.next = function() { LauncherService.close(); reopenProbe(elapsedMs + 700) }
                step.interval = 500
                step.restart()
            }
        })
    }
    function nextCycle() {
        step.next = startCycle
        step.interval = 400
        step.restart()
    }
    function waitReady(cont) {
        var t = Qt.createQmlObject("import QtQuick; Timer { interval: 120; repeat: true; property int tries: 0 }", root, "wr")
        t.triggered.connect(function() {
            t.tries++
            if (!LauncherService.loading || t.tries > 40) { t.stop(); t.destroy(); cont() }
        })
        t.restart()
    }
}
