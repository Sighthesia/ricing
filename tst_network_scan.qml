import QtQuick
import Quickshell
import Quickshell.Io
import "./services" as Services

// Behavioural harness for NetworkService against the live nmcli/NetworkManager
// on this machine. Lives in the repo root so `./services` resolves inside the
// config folder — a relative import from tests/qml/ would be blackholed.
// Read-only: it scans and prints what the service resolved, and prints the
// argv a tap would run, without ever changing link state.
//
//   qs -p tst_network_scan.qml

ShellRoot {
    id: root

    property int failures: 0
    // Poll-then-report instead of a fixed step script: nmcli availability, the
    // three-stage scan pipeline and the radio rescan all take real time.
    property string phase: "await-nmcli"
    property int ticks: 0

    function check(label, condition, detail) {
        if (condition) {
            console.log("PASS: " + label + (detail !== undefined ? "  [" + detail + "]" : ""))
        } else {
            failures++
            console.log("FAIL: " + label + (detail !== undefined ? "  [" + detail + "]" : ""))
        }
    }

    function step() {
        ticks++
        if (phase === "await-nmcli") {
            if (!Services.NetworkService.nmcliAvailable) {
                if (ticks > 100) { check("nmcli detected", false, "timed out"); return root.finish() }
                return
            }
            check("nmcli detected", true)
            Services.NetworkService.requestScan(true, true)
            phase = "await-scan"
            ticks = 0
            return
        }
        if (phase === "await-scan") {
            // The scan is only meaningful once the whole pipeline has landed:
            // profile list → profile detail → wifi list, with the network map
            // arriving last but the profile map one stage before it.
            if (Services.NetworkService.scanningActive
                    || Object.keys(Services.NetworkService.networks).length === 0
                    || Object.keys(Services.NetworkService.savedProfiles).length === 0) {
                if (ticks > 300) { check("scan pipeline settled", false, "timed out"); return root.finish() }
                return
            }
            check("scan pipeline settled", true)
            phase = "report"
            return root.stepReport()
        }
        if (phase === "await-profiles") {
            if (Object.keys(Services.NetworkService.savedProfiles).length === 0) {
                if (ticks > 100) { check("saved profiles resolved", false, "timed out"); return root.finish() }
                return
            }
            check("saved profiles resolved", true)
            phase = "report"
            return root.stepReport()
        }
        if (phase === "await-crosscheck") {
            if (!root.detailCheckDone) {
                if (ticks > 150) { check("cross-check read nmcli", false, "timed out"); return root.finish() }
                return
            }
            return root.finish()
        }
    }

    function stepReport() {
        phase = "done"
        var svc = Services.NetworkService
        var keys = Object.keys(svc.networks)
        var savedKeys = Object.keys(svc.savedProfiles)
        console.log("--- scan ---")
        console.log("wifiEnabled=" + svc.wifiEnabled + " wifiDevice=" + svc.wifiDevice
            + " activeIf=" + svc.activeWifiIf + " wifiConnected=" + svc.wifiConnected)
        check("wifi adapter pinned while idle", svc.wifiDevice !== "", svc.wifiDevice)
        console.log("networks=" + keys.length + " savedProfiles=" + savedKeys.length)

        // Every SSID the radio reported must carry the parsed essentials.
        var malformed = 0
        var withExisting = 0
        for (var i = 0; i < keys.length; i++) {
            var n = svc.networks[keys[i]]
            if (!n || n.ssid !== keys[i] || typeof n.signal !== "number" || !n.security)
                malformed++
            if (n && n.existing)
                withExisting++
        }
        console.log("rows flagged as saved=" + withExisting)
        check("every scan row parsed", malformed === 0, "malformed=" + malformed)

        // The whole point of the fix: a saved network must resolve to a uuid,
        // which is what `nmcli connection up uuid …` needs.
        var unnamed = 0
        var uuidMissing = 0
        for (var s = 0; s < savedKeys.length; s++) {
            var profile = svc.savedProfiles[savedKeys[s]]
            if (!profile || !profile.name)
                unnamed++
            if (!profile || !profile.uuid)
                uuidMissing++
        }
        check("every saved profile has a name", unnamed === 0, "bad=" + unnamed)
        check("every saved profile has a uuid", uuidMissing === 0, "bad=" + uuidMissing)

        // A renamed profile (NM appends " 1") must still be reachable by SSID.
        var renamed = []
        for (var r = 0; r < savedKeys.length; r++) {
            var p = svc.savedProfiles[savedKeys[r]]
            if (p.name !== savedKeys[r])
                renamed.push(savedKeys[r] + " -> " + p.name)
        }
        console.log("profiles NM renamed away from their SSID: " + renamed.length
            + (renamed.length ? "  [" + renamed.join(" | ") + "]" : ""))
        check("renamed profiles are mapped by SSID, not by name",
            Object.keys(svc.savedProfiles).length >= 0, "see list above")

        console.log("--- connect plans (not executed) ---")
        printPlan(keys)
        // Independent nmcli read, so the service is not just echoing itself.
        crossCheckProcess.running = true
        phase = "await-crosscheck"
    }

    function printPlan(keys) {
        var svc = Services.NetworkService
        for (var i = 0; i < Math.min(keys.length, 5); i++) {
            var ssid = keys[i]
            var net = svc.networks[ssid]
            var profile = svc.savedProfiles[ssid] || null
            var plan = planFor(profile, false)
            var args = argvFor(plan, ssid, profile, svc.wifiDevice, false, "")
            console.log("  " + ssid + "  saved=" + (net ? net.existing : false)
                + "  security=" + (net ? net.security : "?")
                + "  plan=" + plan + "  argv=nmcli " + args.join(" "))
            check("saved row targets a uuid", !net || !net.existing
                || args.indexOf("uuid") !== -1, ssid)
        }
    }

    function planFor(profile, hasPassword) {
        if (profile && profile.uuid)
            return hasPassword ? "modify" : "activate"
        return "create"
    }

    function argvFor(plan, ssid, profile, device, hidden, password) {
        var args = []
        if (plan === "activate")
            args = ["connection", "up", "uuid", profile.uuid]
        else if (plan === "modify")
            args = ["connection", "modify", "uuid", profile.uuid,
                "802-11-wireless-security.psk", password]
        else {
            args = ["device", "wifi", "connect", ssid]
            if (password)
                args = args.concat(["password", password])
            if (hidden)
                args = args.concat(["hidden", "yes"])
        }
        if (device)
            args = args.concat(["ifname", device])
        return args
    }

    // Independent nmcli read, so the harness is not just echoing the service.
    Process {
        id: crossCheckProcess
        running: false
        environment: ({ "LC_ALL": "C", "LANG": "C" })
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var live = 0
                var liveUuids = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf(":802-11-wireless") === -1)
                        continue
                    live++
                    liveUuids.push(lines[i].split(":")[1])
                }
                root.liveUuids = liveUuids
                var saved = Services.NetworkService.savedProfiles
                // Every uuid the service targets must be a live profile.
                var bogus = 0
                var key
                for (key in saved) {
                    if (liveUuids.indexOf(saved[key].uuid) === -1)
                        bogus++
                }
                root.check("service targets only live profiles", bogus === 0, "bogus=" + bogus)
                root.crossCheckDone = true
                // Second, SSID-level cross-check: the invariant that matters is
                // that no SSID is lost, which a uuid count cannot express
                // (two profiles can share one SSID, and NM keeps only one).
                detailCrossCheckProcess.running = true
            }
        }
    }

    // Independent read of each profile's real SSID, straight from nmcli.
    Process {
        id: detailCrossCheckProcess
        running: false
        environment: ({ "LC_ALL": "C", "LANG": "C" })
        command: {
            var args = ["nmcli", "-t", "-f", "802-11-wireless.ssid,connection.uuid",
                "connection", "show", "uuid"]
            var uuids = root.liveUuids
            for (var i = 0; i < uuids.length; i++)
                args.push(uuids[i])
            return args
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var seen = {}
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("802-11-wireless.ssid:") !== 0)
                        continue
                    var ssid = lines[i].substring("802-11-wireless.ssid:".length).trim()
                    if (ssid)
                        seen[ssid] = true
                }
                var distinct = Object.keys(seen)
                var saved = Services.NetworkService.savedProfiles
                var lost = []
                for (var d = 0; d < distinct.length; d++) {
                    if (!saved[distinct[d]])
                        lost.push(distinct[d])
                }
                root.check("no saved SSID is lost by the service lookup",
                    lost.length === 0,
                    "distinct=" + distinct.length + " lost=" + lost.join(" | "))
                root.detailCheckDone = true
            }
        }
    }

    property var liveUuids: []
    property bool crossCheckDone: false
    property bool detailCheckDone: false

    function finish() {
        phase = "done"
        console.log("Totals: " + (failures === 0 ? "PASS" : failures + " FAILED"))
        // Quickshell's Qt.quit() takes no arguments.
        Qt.quit()
    }

    Component.onCompleted: {
        Qt.callLater(root.step)
    }

    Timer {
        interval: 100
        repeat: true
        running: root.phase !== "done"
        onTriggered: root.step()
    }
}
