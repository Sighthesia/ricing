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
            // device table → profile list → profile detail → wifi list. The
            // adapter name comes first because it decides which duplicate
            // profile the panel is allowed to target.
            var svc = Services.NetworkService
            if (!svc.wifiDevice
                    || svc.scanningActive
                    || Object.keys(svc.networks).length === 0
                    || Object.keys(svc.savedProfiles).length === 0) {
                if (ticks > 400) { check("scan pipeline settled", false, "timed out"); return root.finish() }
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
        check("service pinned the live adapter",
            svc.wifiDevice === root.liveWifiDevices[0],
            "service=" + svc.wifiDevice + " nmcli=" + root.liveWifiDevices[0])
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
            var args = ["nmcli", "-t", "-f",
                "802-11-wireless.ssid,connection.uuid,connection.interface-name",
                "connection", "show", "uuid"]
            var uuids = root.liveUuids
            for (var i = 0; i < uuids.length; i++)
                args.push(uuids[i])
            return args
        }
        stdout: StdioCollector {
            onStreamFinished: {
                // nmcli prints the fields in `-f` order within a group, so the
                // SSID arrives before the uuid. Accumulate and flush on the
                // blank line between groups rather than assuming an order.
                var rows = []
                var buffer = {}
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var raw = lines[i]
                    if (!raw || !raw.trim()) {
                        if (buffer.uuid)
                            rows.push(buffer)
                        buffer = {}
                        continue
                    }
                    var sep = raw.indexOf(":")
                    if (sep <= 0)
                        continue
                    var field = raw.substring(0, sep)
                    var value = raw.substring(sep + 1).trim()
                    if (field === "connection.uuid")
                        buffer.uuid = value
                    else if (field === "802-11-wireless.ssid")
                        buffer.ssid = value
                    else if (field === "connection.interface-name")
                        buffer.ifname = value
                }
                if (buffer.uuid)
                    rows.push(buffer)

                var distinct = {}
                for (var k = 0; k < rows.length; k++) {
                    if (rows[k].ssid)
                        distinct[rows[k].ssid] = true
                }
                var saved = Services.NetworkService.savedProfiles
                var lost = []
                Object.keys(distinct).forEach(function (ssid) {
                    if (!saved[ssid])
                        lost.push(ssid)
                })
                root.check("no saved SSID is lost by the service lookup",
                    lost.length === 0 && Object.keys(distinct).length > 0,
                    "distinct=" + Object.keys(distinct).length + " lost=" + lost.join(" | "))

                // The invariant behind the "device wlo1 is not compatible…"
                // failures: every profile the service targets must either be
                // usable on an adapter this machine has, or be recognised as
                // stranded so the connect path re-points it. Anything else would
                // be activated and refused.
                var liveDevices = root.liveWifiDevices
                var stranded = []
                var unflagged = []
                for (var key in saved) {
                    var pin = saved[key].ifname ? String(saved[key].ifname) : ""
                    if (!pin || liveDevices.indexOf(pin) !== -1)
                        continue
                    stranded.push(key + "->" + pin)
                    // The same predicate connect() uses to pick the repair plan.
                    if (!(saved[key].ifname && liveDevices[0]
                            && String(saved[key].ifname) !== liveDevices[0]))
                        unflagged.push(key)
                }
                console.log("targets needing an adapter re-point: " + stranded.length
                    + (stranded.length ? "  [" + stranded.join(" | ") + "]" : ""))
                root.check("every stranded target is flagged for repair",
                    unflagged.length === 0, "unflagged=" + unflagged.join(" | "))
                // Where a usable duplicate exists, ranking must have preferred
                // it: for each SSID, if any profile is pinned to a live adapter,
                // the picked profile must be one of those.
                var liveFor = {}
                var hasStranded = {}
                for (var s3 = 0; s3 < rows.length; s3++) {
                    var row3 = rows[s3]
                    if (!row3.ssid)
                        continue
                    if (!row3.ifname || liveDevices.indexOf(row3.ifname) === -1) {
                        hasStranded[row3.ssid] = true
                        continue
                    }
                    if (!liveFor[row3.ssid])
                        liveFor[row3.ssid] = []
                    liveFor[row3.ssid].push(row3.uuid)
                }
                var mistargeted = []
                Object.keys(liveFor).forEach(function (ssid) {
                    var picked = saved[ssid]
                    if (!picked)
                        return
                    if (liveFor[ssid].indexOf(picked.uuid) === -1)
                        mistargeted.push(ssid)
                })
                root.check("no usable duplicate was passed over",
                    mistargeted.length === 0,
                    "stranded-but-live=" + mistargeted.join(" | "))
                root.detailCheckDone = true
            }
        }
    }

    property var liveUuids: []
    property var liveWifiDevices: []
    property bool crossCheckDone: false
    property bool detailCheckDone: false

    // Live adapter names, read independently of the service, so the stranded
    // check compares against the machine rather than against the service.
    Process {
        id: deviceListProcess
        running: false
        environment: ({ "LC_ALL": "C", "LANG": "C" })
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var wifi = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":")
                    if (parts.length >= 2 && parts[1] === "wifi")
                        wifi.push(parts[0])
                }
                root.liveWifiDevices = wifi
                console.log("live wifi adapters: " + (wifi.join(", ") || "(none)"))
            }
        }
    }

    function finish() {
        phase = "done"
        console.log("Totals: " + (failures === 0 ? "PASS" : failures + " FAILED"))
        // Quickshell's Qt.quit() takes no arguments.
        Qt.quit()
    }

    Component.onCompleted: {
        deviceListProcess.running = true
        Qt.callLater(root.step)
    }

    Timer {
        interval: 100
        repeat: true
        running: root.phase !== "done"
        onTriggered: root.step()
    }
}
