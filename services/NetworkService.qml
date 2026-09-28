pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "./network/NetworkLogic.js" as Logic

// Network state: wired link plus Wi-Fi power toggle, scan,
// connect/disconnect/forget via nmcli.
//
// Every nmcli call runs under LC_ALL=C. This machine's user locale is
// zh_CN, and nmcli localises its diagnostics — under that locale the English
// needles for "unknown connection" / "secrets were required" never match, so
// every failure collapsed into the same useless "Connection failed" line.
// Parsing also lives in NetworkLogic.js so it can be unit tested.
Singleton {
    id: root

    // --- Core state ---
    readonly property bool wifiAvailable: _wifiAvailable
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiConnected: _wifiConnected
    readonly property bool ethernetAvailable: _ethernetAvailable
    readonly property bool ethernetConnected: _ethernetConnected
    readonly property string activeEthernetIf: _activeEthernetIf
    readonly property string activeEthernetConnection: _activeEthernetConnection
    readonly property var ethernetInterfaces: _ethernetInterfaces
    readonly property bool internetConnectivity: _internetConnectivity
    readonly property string networkConnectivity: _networkConnectivity

    property bool _wifiAvailable: false
    property bool _wifiConnected: false
    property bool _ethernetAvailable: false
    property bool _ethernetConnected: false
    property string _activeEthernetIf: ""
    property string _activeEthernetConnection: ""
    property var _ethernetInterfaces: []
    property bool _internetConnectivity: false
    property string _networkConnectivity: "unknown"

    // Scan / connection interaction state
    property var networks: ({})
    // Saved profiles keyed by SSID (never by name — see NetworkLogic.js).
    property var savedProfiles: ({})
    property bool scanningActive: false
    property bool connecting: false
    property string connectingTo: ""
    property string disconnectingFrom: ""
    property string forgettingNetwork: ""
    property bool scanPending: false
    property string lastError: ""
    // SSID the current error belongs to, so the popup can offer a recovery
    // action (re-enter the password / forget the stale profile).
    property string lastErrorSsid: ""
    property string activeWifiIf: ""
    // Wi-Fi interface name, tracked whether or not a link is up, so a connect
    // can be pinned to the right adapter on multi-radio machines.
    property string wifiDevice: ""

    // nmcli availability (self-checked, no external ProgramCheckerService)
    property bool nmcliAvailable: false

    // --- Internal bookkeeping ---
    // A full radio rescan is expensive; the background tick reuses NM's cached
    // scan results and only a deliberate refresh pays for a real one.
    property bool _rescanRequested: true
    property int _deviceWaitTries: 0
    property bool _awaitingDevice: false
    // The profile map was ranked before the adapter name was known.
    property bool _profilesResolvedBlind: false
    property real _lastOpenRefreshAt: 0
    property string _connectStderr: ""
    // Immutable snapshot of the attempt in flight. onExited reads this instead
    // of the live Process properties, which a fast second tap would already
    // have overwritten — that cross-talk reported the first attempt's exit
    // code as the second attempt's result.
    property var _job: null

    readonly property var cEnvironment: ({ "LC_ALL": "C", "LANG": "C" })

    Component.onCompleted: {
        console.info("[Network] Service started")
        nmcliCheckProcess.running = true
    }

    // Start initial checks when nmcli becomes available.
    Connections {
        target: root
        function onNmcliAvailableChanged() {
            if (root.nmcliAvailable) {
                deviceStatusProcess.running = true
                connectivityCheckProcess.running = true
            }
        }
    }

    // First list after nmcli shows up. The radio power is not reported
    // synchronously, so a Wi-Fi-off start must not consume the only attempt.
    Timer {
        id: initScanTimer
        interval: 500
        running: root.nmcliAvailable
        repeat: false
        onTriggered: if (root.wifiEnabled) root.requestScan(true, false)
    }

    // Powering the radio back on must rebuild the list; the cached scan results
    // from before the toggle are useless.
    Connections {
        target: root
        function onWifiEnabledChanged() {
            if (root.nmcliAvailable && root.wifiEnabled)
                powerOnScanTimer.restart()
        }
    }

    // A profile map ranked before the adapter name was known can point at a
    // profile NetworkManager still has pinned to a device that is gone, which
    // activation refuses outright. Re-resolve the moment the name arrives.
    Connections {
        target: root
        function onWifiDeviceChanged() {
            if (root.wifiDevice === "" || !root._profilesResolvedBlind)
                return
            root._profilesResolvedBlind = false
            console.info("[Network] adapter '" + root.wifiDevice
                + "' now known, re-resolving saved profiles")
            root.requestScan(false, false)
        }
    }

    Timer {
        id: powerOnScanTimer
        interval: 900
        repeat: false
        onTriggered: root.requestScan(true, false)
    }

    // Starts the profile → detail → scan chain a turn after its inputs land.
    Timer {
        id: scanKickTimer
        interval: 0
        repeat: false
        onTriggered: root._runScanPipeline()
    }

    Timer {
        id: delayedScanTimer
        interval: 7000
        onTriggered: root.requestScan(false, false)
    }

    // Internet connectivity check timer.
    Timer {
        id: connectivityCheckTimer
        interval: 15000
        running: root.nmcliAvailable && (root.wifiConnected || root.ethernetConnected)
        repeat: true
        onTriggered: {
            connectivityCheckProcess.running = true
            // Wired links come and go outside our own actions; re-read the
            // device table on the same cadence while any link is up.
            if (!deviceStatusProcess.running)
                deviceStatusProcess.running = true
        }
    }

    // Slow device poll so cable plug/unplug converges while offline too.
    Timer {
        id: devicePollTimer
        interval: 30000
        running: root.nmcliAvailable
        repeat: true
        onTriggered: {
            if (!deviceStatusProcess.running)
                deviceStatusProcess.running = true
        }
    }

    // Background list upkeep. The popup used to render whatever the startup
    // scan had found, so networks that appeared (or profiles that were added
    // elsewhere) never showed up until a manual rescan. Uses NM's cached scan
    // results — cheap enough to run while the shell lives.
    Timer {
        id: backgroundScanTimer
        interval: 45000
        running: root.nmcliAvailable && root.wifiEnabled
        repeat: true
        onTriggered: {
            if (!root.connecting)
                root.requestScan(false, false)
        }
    }

    // nmcli has no --wait on this version, so an AP that never answers would
    // leave the row spinning forever. Cap the attempt ourselves.
    Timer {
        id: connectWatchdog
        interval: 60000
        repeat: false
        onTriggered: {
            if (!root.connecting || !root._job)
                return
            console.warn("[Network] connect timed out for '" + root._job.ssid + "'")
            root._finishConnect(false, "Connection timeout")
        }
    }

    // --- Core functions ---

    function setWifiEnabled(enabled) {
        if (!root.nmcliAvailable) return
        console.info("[Network] setWifiEnabled", enabled)
        Networking.wifiEnabled = enabled
        if (enabled) {
            powerOnScanTimer.restart()
        } else {
            root.networks = ({})
            root.scanningActive = false
        }
    }

    // `rescan` asks NetworkManager for a fresh radio scan; `clearError` is
    // reserved for deliberate user actions so a background tick never wipes a
    // message the user has not read yet.
    function requestScan(rescan, clearError) {
        if (!root.nmcliAvailable || !root.wifiEnabled)
            return
        if (rescan === true)
            root._rescanRequested = true
        if (clearError === true)
            root._clearError()
        // QML re-evaluates a `command` binding lazily, so a Process started in
        // the same turn its inputs are assigned can launch with the previous
        // turn's argv. One turn of separation is what makes the pipeline
        // deterministic.
        scanKickTimer.restart()
    }

    function _runScanPipeline() {
        if (!root.nmcliAvailable || !root.wifiEnabled)
            return
        if (profileCheckProcess.running || profileDetailProcess.running || scanProcess.running) {
            root.scanPending = true
            return
        }
        // Which duplicate profile a tap should target is decided by the adapter
        // name, so never resolve the profile map before that name is known: a
        // blind pick lands on a profile NetworkManager still has pinned to a
        // device that no longer exists, and activation is refused with
        // "device … is not compatible". Read the device table first.
        if (!root.wifiDevice && root._deviceWaitTries < 3) {
            root._deviceWaitTries++
            root._awaitingDevice = true
            if (!deviceStatusProcess.running)
                deviceStatusProcess.running = true
            else
                scanKickTimer.restart()
            return
        }
        root._deviceWaitTries = 0
        profileCheckProcess.running = true
        root.scanningActive = true
        console.info("[Network] scanning Wi-Fi (rescan=" + root._rescanRequested + ")…")
    }

    // Back-compat alias for the popup's Rescan button and the old call sites.
    function scan() {
        root.requestScan(true, true)
    }

    // Called when the network popup becomes visible. Throttled so a cursor
    // sweeping across the bar cannot queue a scan per hover frame, but always
    // a real rescan so newly visible networks actually appear.
    function refreshForOpen() {
        if (!root.nmcliAvailable)
            return
        var now = Date.now()
        if (now - root._lastOpenRefreshAt < 8000)
            return
        root._lastOpenRefreshAt = now
        if (root.wifiEnabled) {
            root.requestScan(true, false)
        } else if (!deviceStatusProcess.running) {
            deviceStatusProcess.running = true
        }
    }

    function connect(ssid, password, isHidden, securityKey) {
        if (!root.nmcliAvailable)
            return
        if (!ssid)
            return
        if (root.connecting) {
            // A second tap while an attempt is live is a no-op, not a silent
            // second nmcli run fighting the first one.
            console.info("[Network] connect ignored, already busy with '"
                + root.connectingTo + "'")
            return
        }

        isHidden = isHidden || false
        var known = root.networks[ssid] || null
        var requestedSecurity = securityKey || (known ? known.security : "")
        var profile = root.savedProfiles[ssid] || null

        if (Logic.isEnterprise(requestedSecurity)
                || (profile && Logic.isEnterpriseKeyMgmt(profile.keyMgmt))) {
            root._setError("Enterprise (EAP) network — not supported", ssid)
            console.warn("[Network] EAP rejected for '" + ssid + "'")
            return
        }

        root.connecting = true
        root.connectingTo = ssid
        root._clearError()
        connectWatchdog.restart()

        var hasPassword = password != null && String(password) !== ""
        var stalePin = Logic.isStaleAdapterPin(profile, root.wifiDevice)
        root._job = {
            ssid: ssid,
            password: hasPassword ? String(password) : "",
            hidden: isHidden,
            uuid: profile ? profile.uuid : "",
            savedName: profile ? profile.name : "",
            device: root.wifiDevice,
            repoint: stalePin,
            plan: Logic.connectPlan(profile, hasPassword, root.wifiDevice)
        }
        if (stalePin) {
            console.info("[Network] '" + ssid + "' is pinned to '" + profile.ifname
                + "', re-pointing it at '" + root.wifiDevice + "'")
        }
        console.info("[Network] connect '" + ssid + "' plan=" + root._job.plan
            + (profile ? " profile=" + profile.name : ""))
        // One turn of separation from the _job assignment, so the Process
        // starts against this job's argv rather than the previous one's.
        Qt.callLater(root._startConnectJob)
    }

    // Does tapping this row need a password first? An unsaved secured network
    // always does — but an open one must still connect straight away. A saved
    // network only asks again after its stored secret was the thing that
    // failed, so a credential prompt becomes the recovery path.
    function needsPasswordFor(ssid) {
        var network = ssid ? root.networks[ssid] : null
        if (!network)
            return false
        if (!network.existing)
            return Logic.isSecured(network.security)
        return root.lastErrorSsid === ssid && root.isCredentialFailure(root.lastError)
    }

    function disconnect(ssid) {
        if (!root.nmcliAvailable || !ssid) return
        root.disconnectingFrom = ssid
        disconnectProcess.ssid = ssid
        Qt.callLater(function () {
            if (disconnectProcess.running)
                return
            disconnectProcess.running = true
        })
    }

    function forget(ssid) {
        if (!root.nmcliAvailable || !ssid) return
        var profile = root.savedProfiles[ssid]
        root.forgettingNetwork = ssid
        forgetProcess.ssid = ssid
        // uuid, not name: the profile we mean may live under a " 1" suffixed
        // name, and deleting by name could hit a different network.
        forgetProcess.uuid = profile ? profile.uuid : ""
        Qt.callLater(function () {
            if (forgetProcess.running)
                return
            forgetProcess.running = true
        })
    }

    // --- Helpers ---

    function _clearError() {
        root.lastError = ""
        root.lastErrorSsid = ""
    }

    function _setError(message, ssid) {
        root.lastError = message
        root.lastErrorSsid = ssid || ""
        console.warn("[Network] " + message)
    }

    function isSecured(security) { return Logic.isSecured(security) }
    function isCredentialFailure(message) { return Logic.isCredentialFailure(message) }

    // Signal strength → icon glyph (Nerd Font).
    function getSignalIcon(signal, isConnected) {
        return Logic.signalIcon(signal, isConnected, root._networkConnectivity)
    }

    function getSignalLabel(signal) {
        return Logic.signalLabel(signal)
    }

    function getStatusText() {
        if (root.ethernetConnected)
            return root.activeEthernetConnection !== "" ? root.activeEthernetConnection : "Wired"
        if (root.connecting) return root.connectingTo ? "Connecting " + root.connectingTo : "Connecting"
        if (!root.wifiEnabled) return ""
        if (root.wifiConnected) {
            var connectedNet = Object.values(root.networks).find(n => n.connected)
            return connectedNet ? connectedNet.ssid : ""
        }
        return ""
    }

    // Update a single network's connected flag without disturbing others.
    function _updateNetworkStatus(ssid, connected) {
        var nets = root.networks
        for (var key in nets) {
            if (nets[key].connected && key !== ssid) nets[key].connected = false
        }
        if (nets[ssid]) {
            nets[ssid].connected = connected
        } else if (connected) {
            nets[ssid] = { ssid: ssid, security: "--", signal: 100, connected: true, existing: true }
        }
        root.networks = ({})
        root.networks = nets
    }

    // --- Connect job plumbing ---

    // Two commands in the worst case: rewrite a stale secret, then activate.
    // They are separate Processes on purpose — a single Process re-reading a
    // `command` binding between two runs in one event-loop turn can start with
    // the previous turn's argv, which silently ran the modify step twice.
    // Keeping them apart also means no shell ever re-parses an SSID or a
    // password on the way to nmcli.
    function _startConnectJob() {
        var job = root._job
        if (!job) return
        if (job.plan === "modify") {
            connectModifyProcess.running = true
        } else {
            connectProcess.running = true
        }
    }

    function _connectCommand() {
        var job = root._job
        if (!job) return ["true"]
        if (job.plan === "activate")
            return Logic.activateArgs(job.uuid, job.device)
        return Logic.createArgs(job.ssid, job.password, job.hidden, job.device)
    }

    // Single authoritative settle point. Both phases report here, and the
    // captured stderr is dropped when a new attempt starts so a stale message
    // can never explain a fresh failure.
    function _finishConnect(ok, message) {
        var job = root._job
        connectWatchdog.stop()
        root.connecting = false
        root.connectingTo = ""
        root._job = null
        if (ok) {
            root._wifiConnected = true
            root._updateNetworkStatus(job ? job.ssid : "", true)
            console.info("[Network] connected to '" + (job ? job.ssid : "") + "'")
        } else {
            root._setError(message, job ? job.ssid : "")
        }
        // A rescan right after settling republishes signal strength and the
        // IN-USE flag; the device table settles the authoritative link state.
        delayedScanTimer.interval = ok ? 5000 : 2000
        delayedScanTimer.restart()
        if (!deviceStatusProcess.running)
            deviceStatusProcess.running = true
    }

    // --- Processes ---

    // Check nmcli availability once at startup.
    Process {
        id: nmcliCheckProcess
        running: false
        command: ["sh", "-c", "command -v nmcli"]
        environment: root.cEnvironment
        onExited: function (code) {
            root.nmcliAvailable = (code === 0)
            console.info("[Network] nmcli available:", root.nmcliAvailable)
        }
    }

    // Saved profiles, in two steps: the generic listing gives name/uuid/type,
    // then the per-uuid detail call reveals the real SSID each profile holds.
    // Matching on name alone missed every profile NetworkManager had renamed
    // with a " 1" suffix, which is why saved networks read as "unknown".
    // Saved profiles, in two steps: the generic listing supplies name/uuid/type
    // (the detailed form rejects NAME), then a self-describing detail call
    // reveals which SSID each profile actually holds. Matching on name alone
    // missed every profile NetworkManager had renamed with a " 1" suffix, which
    // is why saved networks read as unknown and connects went nowhere.
    Process {
        id: profileCheckProcess
        property var allUuids: []
        property string baseText: ""
        running: false
        environment: root.cEnvironment
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var uuids = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = Logic.splitTerse(lines[i].trim(), 3)
                    if (parts.length < 3) continue
                    if (parts[1].trim()) uuids.push(parts[1].trim())
                }
                profileCheckProcess.allUuids = uuids
                profileCheckProcess.baseText = text
                profileDetailProcess.detailApplied = false
                if (uuids.length > 0) {
                    Qt.callLater(root._startProfileDetail)
                    return
                }
                // No profiles at all is the only state worth publishing as an
                // empty map. An empty map is exactly what makes every saved
                // network read as unsaved, so a hiccup that merely parsed
                // nothing must leave the previous map in place.
                if (!text.trim())
                    root.savedProfiles = ({})
                Qt.callLater(root._startScan)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("[Network] profile list stderr:", text.trim())
                if (profileDetailProcess.running || scanProcess.running)
                    return
                // Keep the previous map: see the note in the stdout handler.
                Qt.callLater(root._startScan)
            }
        }
    }

    function _startProfileDetail() {
        if (profileDetailProcess.running)
            return
        profileDetailProcess.running = true
    }

    function _startScan() {
        if (scanProcess.running)
            return
        scanProcess.running = true
    }

    // One self-identifying field line per requested field, grouped per
    // connection. Passing the uuid as a field is what makes the mapping
    // order-independent; relying on row order silently crossed profiles.
    // `connection.interface-name` rides along because a profile pinned to an
    // adapter that no longer exists is dead weight that NM refuses outright.
    Process {
        id: profileDetailProcess
        // Set once a stdout result has been applied, so the stderr handler can
        // tell "the call failed" from "the call printed nothing to stderr".
        property bool detailApplied: false
        running: false
        environment: root.cEnvironment
        command: {
            var args = ["nmcli", "-t", "-f",
                "802-11-wireless.ssid,connection.uuid,"
                + "802-11-wireless-security.key-mgmt,connection.interface-name",
                "connection", "show", "uuid"]
            var uuids = profileCheckProcess.allUuids || []
            for (var i = 0; i < uuids.length; i++)
                args.push(uuids[i])
            return args
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.savedProfiles = Logic.parseProfileList(
                    profileCheckProcess.baseText, text, root.wifiDevice).bySsid
                // Ranked blind if the adapter name was not known yet; flag it so
                // the map is rebuilt once the name lands, rather than waiting for
                // the next background tick with a wrong pick in place.
                root._profilesResolvedBlind = (root.wifiDevice === "")
                profileDetailProcess.detailApplied = true
                Qt.callLater(root._startScan)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("[Network] profile detail stderr:", text.trim())
                // Whole batch rejected (a profile vanished between the two
                // calls): fall back to name matching rather than losing every
                // saved network.
                // StdioCollector finishes on stream close, not on content, so
                // this handler also runs after a clean stdout. Falling back
                // there would throw away the SSID-keyed map and put the shell
                // right back to matching profiles by name.
                if (!text.trim() || profileDetailProcess.detailApplied)
                    return
                root.savedProfiles = Logic.parseProfileList(
                    profileCheckProcess.baseText, "", root.wifiDevice).bySsid
                Qt.callLater(root._startScan)
            }
        }
    }

    // Device status + active Wi-Fi details.
    Process {
        id: deviceStatusProcess
        running: false
        command: ["sh", "-c",
            "nmcli -t -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS device show; echo \"------\"; nmcli -t -f IN-USE,SIGNAL,RATE device wifi list"]
        environment: root.cEnvironment

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("------")
                var deviceText = parts[0]
                var wifiText = parts[1] || ""

                var lines = deviceText.split("\n")
                var blocks = []
                var cur = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line) continue
                    if (line.startsWith("GENERAL.DEVICE:")) {
                        if (cur.length > 0) blocks.push(cur)
                        cur = [line]
                    } else if (cur.length > 0) {
                        cur.push(line)
                    }
                }
                if (cur.length > 0) blocks.push(cur)

                var wifiAvailable = false
                var wifiDevice = ""
                var activeWifiIf = ""
                var ethAvailable = false
                var activeEthIf = ""
                var activeEthConn = ""
                var ethList = []

                for (var b = 0; b < blocks.length; b++) {
                    var name = "", type = "", stateStr = "", conn = ""
                    for (var l = 0; l < blocks[b].length; l++) {
                        var bl = blocks[b][l]
                        if (bl.startsWith("GENERAL.DEVICE:")) name = bl.substring(15).trim()
                        else if (bl.startsWith("GENERAL.TYPE:")) type = bl.substring(13).trim()
                        else if (bl.startsWith("GENERAL.STATE:")) stateStr = bl.substring(14).trim()
                        else if (bl.startsWith("GENERAL.CONNECTION:")) conn = bl.substring(19).trim()
                    }
                    if (stateStr.indexOf("(unmanaged)") !== -1) continue
                    var isConnected = stateStr.indexOf("(connected)") !== -1
                    if (type === "wifi") {
                        wifiAvailable = true
                        // Track the adapter whether or not it holds a link, so a
                        // connect can still be pinned to it while idle.
                        if (!wifiDevice && name) wifiDevice = name
                        if (isConnected && !activeWifiIf) activeWifiIf = name
                    } else if (type === "ethernet") {
                        ethAvailable = true
                        if (conn === "--") conn = ""
                        ethList.push({ name: name, connection: conn, connected: isConnected })
                        if (isConnected && !activeEthIf) {
                            activeEthIf = name
                            activeEthConn = conn
                        }
                    }
                }

                root._wifiAvailable = wifiAvailable
                root._wifiConnected = activeWifiIf !== ""
                root.activeWifiIf = activeWifiIf
                root.wifiDevice = wifiDevice
                root._ethernetAvailable = ethAvailable
                root._ethernetConnected = activeEthIf !== ""
                root._activeEthernetIf = activeEthIf
                root._activeEthernetConnection = activeEthConn
                root._ethernetInterfaces = ethList

                // The profile step was held back waiting for the adapter name;
                // now it can rank duplicate profiles correctly.
                if (root._awaitingDevice) {
                    root._awaitingDevice = false
                    if (!root.wifiDevice)
                        root._deviceWaitTries = 0
                    if (!root.scanningActive)
                        scanKickTimer.restart()
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("[Network] device show stderr:", text.trim())
        }
    }

    // Connectivity check.
    Process {
        id: connectivityCheckProcess
        running: false
        environment: root.cEnvironment
        command: ["nmcli", "networking", "connectivity", "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                var r = text.trim()
                if (!r) return
                root._networkConnectivity = (r === "none") ? "unknown" : r
                root._internetConnectivity = (r === "full")
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("[Network] connectivity error:", text.trim())
        }
    }

    // Scan for Wi-Fi networks. The list is only replaced once this finishes,
    // so the popup keeps showing the previous scan while a rescan runs.
    Process {
        id: scanProcess
        running: false
        environment: root.cEnvironment
        command: ["nmcli", "-t", "-f", "SSID,SECURITY,SIGNAL,IN-USE", "device", "wifi",
            "list", "--rescan", root._rescanRequested ? "yes" : "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                var map = Logic.parseWifiList(text, root.savedProfiles)
                root.networks = map
                // A freshly created profile must count as saved straight away,
                // otherwise the next tap would ask for the password again.
                var seen = Object.keys(map)
                for (var i = 0; i < seen.length; i++) {
                    if (map[seen[i]].connected)
                        connectivityCheckProcess.running = true
                }
                if (root.scanPending) {
                    root.scanPending = false
                    delayedScanTimer.interval = 100
                    delayedScanTimer.restart()
                }
                root.scanningActive = false
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.warn("[Network] scan error:", text.trim())
                    if (root.scanPending) {
                        root.scanPending = false
                        delayedScanTimer.interval = 3000
                    } else if (root.scanningActive) {
                        delayedScanTimer.interval = 10000
                    }
                    delayedScanTimer.restart()
                }
                root.scanningActive = false
            }
        }
    }

    // Repair a saved profile before activating it: re-point an adapter pin
    // that points at a device which no longer exists, and/or rewrite a secret
    // the user retyped. Only the properties that need changing are written.
    Process {
        id: connectModifyProcess
        running: false
        environment: root.cEnvironment
        command: {
            var job = root._job
            if (!job || !job.uuid) return ["true"]
            return ["nmcli"].concat(Logic.modifyArgs(
                job.uuid, job.password, job.device, job.repoint))
        }
        onExited: function (code) {
            var job = root._job
            if (!job) return
            if (code === 0) {
                console.info("[Network] profile repaired for '" + job.ssid + "'")
                connectProcess.running = true
            } else {
                root._finishConnect(false, Logic.classifyConnectError(root._connectStderr))
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return
                root._connectStderr = text
                console.warn("[Network] connect repair error: " + text.trim())
            }
        }
    }

    // Bring a saved profile up, or create one for an unknown SSID.
    Process {
        id: connectProcess
        running: false
        environment: root.cEnvironment
        command: ["nmcli"].concat(root._connectCommand())
        onExited: function (code) {
            if (!root._job) return
            if (code === 0) {
                root._finishConnect(true, "")
            } else {
                root._finishConnect(false, Logic.classifyConnectError(root._connectStderr))
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return
                root._connectStderr = text
                console.warn("[Network] connect error: " + text.trim())
            }
        }
    }

    // Disconnect.
    Process {
        id: disconnectProcess
        property string ssid: ""
        running: false
        environment: root.cEnvironment
        command: Logic.downArgs(ssid)
        stdout: StdioCollector {
            onStreamFinished: {
                console.info("[Network] disconnected from '" + disconnectProcess.ssid + "'")
                root._wifiConnected = false
                root._updateNetworkStatus(disconnectProcess.ssid, false)
                root.disconnectingFrom = ""
                delayedScanTimer.interval = 3000
                delayedScanTimer.restart()
                if (!deviceStatusProcess.running)
                    deviceStatusProcess.running = true
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // Fires on stream close even when empty; clearing state here
                // would cut a successful disconnect short.
                if (!text.trim()) return
                root.disconnectingFrom = ""
                console.warn("[Network] disconnect error:", text.trim())
                delayedScanTimer.interval = 5000
                delayedScanTimer.restart()
            }
        }
    }

    // Forget.
    Process {
        id: forgetProcess
        property string ssid: ""
        property string uuid: ""
        running: false
        environment: root.cEnvironment
        command: {
            if (forgetProcess.uuid)
                return ["nmcli"].concat(Logic.deleteArgs(forgetProcess.uuid))
            // No uuid resolved: fall back to the legacy name+type lookup.
            var script = ''
                + 'ssid="$1"\n'
                + 'UUID=$(nmcli -t -f NAME,UUID,TYPE connection show '
                + "| awk -F: -v target=\"$ssid\" '$1 == target && $3 == \"802-11-wireless\" "
                + '{ print $2; exit }\')\n'
                + 'if [ -n "$UUID" ]; then nmcli connection delete uuid "$UUID" 2>/dev/null; fi\n'
            return ["sh", "-c", script, "--", forgetProcess.ssid]
        }
        stdout: StdioCollector {
            onStreamFinished: {
                console.info("[Network] forgot '" + forgetProcess.ssid + "'")
                var saved = root.savedProfiles
                if (saved[forgetProcess.ssid]) {
                    delete saved[forgetProcess.ssid]
                    root.savedProfiles = ({})
                    root.savedProfiles = saved
                }
                var nets = root.networks
                if (nets[forgetProcess.ssid]) {
                    nets[forgetProcess.ssid].existing = false
                    nets[forgetProcess.ssid].savedUuid = ""
                    nets[forgetProcess.ssid].savedName = ""
                    root.networks = ({})
                    root.networks = nets
                }
                if (root.lastErrorSsid === forgetProcess.ssid)
                    root._clearError()
                root.forgettingNetwork = ""
                delayedScanTimer.interval = 5000
                delayedScanTimer.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // Same as disconnect: an empty stream still closes.
                if (!text.trim()) return
                root.forgettingNetwork = ""
                console.warn("[Network] forget error:", text.trim())
                delayedScanTimer.interval = 5000
                delayedScanTimer.restart()
            }
        }
    }
}
