pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Wi-Fi state: power toggle, scan, connect/disconnect/forget via nmcli.
Singleton {
    id: root

    // --- Core state ---
    readonly property bool wifiAvailable: _wifiAvailable
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiConnected: _wifiConnected
    readonly property bool internetConnectivity: _internetConnectivity
    readonly property string networkConnectivity: _networkConnectivity

    property bool _wifiAvailable: false
    property bool _wifiConnected: false
    property bool _internetConnectivity: false
    property string _networkConnectivity: "unknown"

    // Scan / connection interaction state
    property var networks: ({})
    property var existingProfiles: ({})
    property bool scanningActive: false
    property bool connecting: false
    property string connectingTo: ""
    property string disconnectingFrom: ""
    property string forgettingNetwork: ""
    property bool scanPending: false
    property string lastError: ""
    property string activeWifiIf: ""

    // nmcli availability (self-checked, no external ProgramCheckerService)
    property bool nmcliAvailable: false

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

    // Debounce wifi toggle to avoid duplicate toasts on transient states.
    Timer {
        id: initScanTimer
        interval: 500
        running: root.nmcliAvailable
        repeat: false
        onTriggered: if (root.wifiEnabled) scan()
    }

    Timer {
        id: delayedScanTimer
        interval: 7000
        onTriggered: scan()
    }

    // Internet connectivity check timer.
    Timer {
        id: connectivityCheckTimer
        interval: 15000
        running: root.nmcliAvailable && root.wifiConnected
        repeat: true
        onTriggered: connectivityCheckProcess.running = true
    }

    // --- Core functions ---

    function setWifiEnabled(enabled) {
        if (!root.nmcliAvailable) return
        console.info("[Network] setWifiEnabled", enabled)
        Networking.wifiEnabled = enabled
        if (!enabled) {
            root.networks = ({})
        }
    }

    function scan() {
        if (!root.nmcliAvailable || !root.wifiEnabled) return
        root.lastError = ""

        if (profileCheckProcess.running || scanProcess.running) {
            root.scanPending = true
            return
        }

        profileCheckProcess.running = true
        root.scanningActive = true
        console.info("[Network] scanning Wi-Fi…")
    }

    function connect(ssid, password, isHidden, securityKey) {
        if (!root.nmcliAvailable || root.connecting) return

        isHidden = isHidden || false
        securityKey = securityKey || ""

        var isSaved = root.networks[ssid] && root.networks[ssid].existing
        var isEnterprise = securityKey ? _isEnterprise(securityKey)
            : _isEnterprise(root.networks[ssid] ? root.networks[ssid].security : "")

        // Only support open / WPA-PSK / WEP in this精简 build; EAP rejected.
        if (isEnterprise || (securityKey && securityKey.indexOf("-eap") !== -1)) {
            root.lastError = "Enterprise (EAP) networks are not supported in this build"
            console.warn("[Network]", root.lastError)
            return
        }

        root.connecting = true
        root.connectingTo = ssid
        root.lastError = ""

        connectProcess.ssid = ssid
        connectProcess.password = password || ""
        connectProcess.isHidden = isHidden

        if (isSaved) {
            connectProcess.mode = "saved"
        } else if (securityKey === "wep" || (securityKey && securityKey !== "open" && securityKey !== "wpa-psk" && securityKey !== "wpa2-psk")) {
            connectProcess.mode = "manual"
            connectProcess.securityKey = securityKey || (root.networks[ssid] ? root.networks[ssid].security : "wpa-psk")
        } else {
            connectProcess.mode = "new"
        }

        connectProcess.running = true
    }

    function disconnect(ssid) {
        if (!root.nmcliAvailable) return
        root.disconnectingFrom = ssid
        disconnectProcess.ssid = ssid
        disconnectProcess.running = true
    }

    function forget(ssid) {
        if (!root.nmcliAvailable) return
        root.forgettingNetwork = ssid
        forgetProcess.ssid = ssid
        forgetProcess.running = true
    }

    // --- Helpers ---

    function _isEnterprise(security) {
        if (!security) return false
        var s = security.toUpperCase()
        return s.indexOf("802.1X") !== -1 || s.indexOf("EAP") !== -1 || s.indexOf("ENTERPRISE") !== -1
    }

    function isSecured(security) {
        return security && security !== "--" && security.trim() !== ""
    }

    // Signal strength → icon glyph (Nerd Font).
    function getSignalIcon(signal, isConnected) {
        if (isConnected) {
            if (root._networkConnectivity === "limited") return "\uf2d2"   // wifi-exclamation
            if (root._networkConnectivity === "portal" || root._networkConnectivity === "unknown") return "\uf2d4" // wifi-question
        }
        if (signal >= 80) return "\uf1eb" // wifi (full)
        if (signal >= 60) return "\uf2eb" // wifi-3
        if (signal >= 35) return "\uf2ea" // wifi-2
        if (signal >= 15) return "\uf2e9" // wifi-1
        return "\uf2e8"                    // wifi-0
    }

    function getSignalLabel(signal) {
        if (signal >= 80) return "Excellent"
        if (signal >= 60) return "Good"
        if (signal >= 35) return "Fair"
        if (signal >= 15) return "Poor"
        return "Weak"
    }

    function getIcon() {
        if (!root.wifiEnabled) return "\uf2a0" // wifi-off
        if (root.wifiConnected) {
            var connectedNet = Object.values(root.networks).find(n => n.connected)
            var s = connectedNet ? connectedNet.signal : 0
            return getSignalIcon(s, true)
        }
        if (root.connecting || Object.keys(root.networks).length > 0) return "\uf2d4" // wifi-question
        return "\uf2e8" // wifi-0
    }

    function getStatusText() {
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
            nets[ssid].existing = true
        } else if (connected) {
            nets[ssid] = { ssid: ssid, security: "--", signal: 100, connected: true, existing: true }
        }
        root.networks = ({})
        root.networks = nets
    }

    // --- Processes ---

    // Check nmcli availability once at startup.
    Process {
        id: nmcliCheckProcess
        running: false
        command: ["sh", "-c", "command -v nmcli"]
        onExited: function (code) {
            root.nmcliAvailable = (code === 0)
            console.info("[Network] nmcli available:", root.nmcliAvailable)
        }
    }

    // Device status + active Wi-Fi details.
    Process {
        id: deviceStatusProcess
        running: false
        command: ["sh", "-c",
            "nmcli -t -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS device show; echo \"------\"; nmcli -t -f IN-USE,SIGNAL,RATE device wifi list"]
        environment: ({ "LC_ALL": "C" })

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
                var activeWifiIf = ""

                for (var b = 0; b < blocks.length; b++) {
                    var name = "", type = "", stateStr = ""
                    for (var l = 0; l < blocks[b].length; l++) {
                        var bl = blocks[b][l]
                        if (bl.startsWith("GENERAL.DEVICE:")) name = bl.substring(15).trim()
                        else if (bl.startsWith("GENERAL.TYPE:")) type = bl.substring(13).trim()
                        else if (bl.startsWith("GENERAL.STATE:")) stateStr = bl.substring(14).trim()
                    }
                    if (stateStr.indexOf("(unmanaged)") !== -1) continue
                    var isConnected = stateStr.indexOf("(connected)") !== -1
                    if (type === "wifi") {
                        wifiAvailable = true
                        if (isConnected && !activeWifiIf) activeWifiIf = name
                    }
                }

                root._wifiAvailable = wifiAvailable
                root._wifiConnected = activeWifiIf !== ""
                root.activeWifiIf = activeWifiIf
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
            onStreamFinished: if (text.trim()) console.warn("[Network] connectivity error:", text)
        }
    }

    // Get existing profiles first, then scan.
    Process {
        id: profileCheckProcess
        running: false
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var profiles = {}
                var ls = text.split("\n")
                for (var i = 0; i < ls.length; i++) {
                    var l = ls[i]
                    if (l && l.trim()) profiles[l.trim()] = true
                }
                root.existingProfiles = profiles
                scanProcess.running = true
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() && root.scanningActive) {
                    delayedScanTimer.interval = 5000
                    delayedScanTimer.restart()
                }
            }
        }
    }

    // Scan for Wi-Fi networks.
    Process {
        id: scanProcess
        running: false
        command: ["nmcli", "-t", "-f", "SSID,SECURITY,SIGNAL,IN-USE", "device", "wifi", "list", "--rescan", "yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                var map = {}
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line) continue
                    var parts = line.split(":")
                    if (parts.length < 4) continue
                    var inUse = parts[parts.length - 1]
                    var signal = parseInt(parts[parts.length - 2]) || 0
                    var security = parts[parts.length - 3]
                    if (security) security = security.replace("WPA2 WPA3", "WPA2/WPA3").replace("WPA1 WPA2", "WPA1/WPA2")
                    var ssid = parts.slice(0, parts.length - 3).join(":")
                    if (!ssid) continue
                    var isConnected = (inUse === "*")
                    if (!map[ssid]) {
                        map[ssid] = {
                            ssid: ssid,
                            security: security || "--",
                            signal: signal,
                            connected: isConnected,
                            existing: !!root.existingProfiles[ssid]
                        }
                    } else {
                        if (isConnected) {
                            map[ssid].connected = true
                            map[ssid].signal = signal
                            connectivityCheckProcess.running = true
                        } else if (!map[ssid].connected && signal > map[ssid].signal) {
                            map[ssid].signal = signal
                        }
                    }
                }
                root.networks = map
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
                    console.warn("[Network] scan error:", text)
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

    // Connect to a Wi-Fi network.
    Process {
        id: connectProcess
        property string mode: "new"
        property string ssid: ""
        property string password: ""
        property bool isHidden: false
        property string securityKey: "wpa-psk"
        running: false

        command: {
            if (mode === "saved") {
                return ["nmcli", "-t", "connection", "up", "id", ssid]
            } else if (mode === "manual") {
                var nmArgs = ["connection", "add", "type", "wifi", "con-name", ssid, "ssid", ssid, "--", "802-11-wireless.hidden", isHidden ? "yes" : "no"]
                if (securityKey === "wpa-psk" || securityKey === "wpa2-psk") {
                    nmArgs.push("wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", password)
                } else if (securityKey === "sae") {
                    nmArgs.push("wifi-sec.key-mgmt", "sae", "wifi-sec.psk", password)
                } else if (securityKey === "wep") {
                    nmArgs.push("wifi-sec.key-mgmt", "none", "wifi-sec.wep-key0", password)
                }
                var script = `
                    SSID="$1"
                    shift
                    UUID=$(nmcli -t -f NAME,UUID,TYPE connection show | awk -F: -v target="$SSID" '$1 == target && $3 == "802-11-wireless" { print $2; exit }')
                    if [ -n "$UUID" ]; then nmcli connection delete uuid "$UUID" 2>/dev/null || true; fi
                    nmcli "$@"
                    nmcli connection up id "$SSID"
                `
                return ["sh", "-c", script, "--", ssid].concat(nmArgs)
            } else {
                var cmd = ["nmcli", "-t", "device", "wifi", "connect", ssid]
                if (isHidden) cmd.push("hidden", "yes")
                if (password) cmd.push("password", password)
                if (root.activeWifiIf) cmd.push("ifname", root.activeWifiIf)
                return cmd
            }
        }

        environment: ({ "LC_ALL": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                var output = text.trim()
                if (!output || (output.indexOf("successfully activated") === -1 && output.indexOf("Connection successfully") === -1)) return
                root._wifiConnected = true
                root._updateNetworkStatus(connectProcess.ssid, true)
                root.connecting = false
                root.connectingTo = ""
                console.info("[Network] connected to '" + connectProcess.ssid + "'")
                delayedScanTimer.interval = 5000
                delayedScanTimer.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    root.connecting = false
                    root.connectingTo = ""
                    if (text.indexOf("Secrets were required") !== -1 || text.indexOf("no secrets provided") !== -1) {
                        root.lastError = "Incorrect password"
                        root.forget(connectProcess.ssid)
                    } else if (text.indexOf("No network with SSID") !== -1) {
                        root.lastError = "Network not found"
                    } else if (text.indexOf("Timeout") !== -1) {
                        root.lastError = "Connection timeout"
                    } else {
                        root.lastError = "Connection failed"
                    }
                    console.warn("[Network] connect error (" + connectProcess.mode + "):", text)
                }
            }
        }
    }

    // Disconnect.
    Process {
        id: disconnectProcess
        property string ssid: ""
        running: false
        command: ["nmcli", "connection", "down", "id", ssid]
        stdout: StdioCollector {
            onStreamFinished: {
                console.info("[Network] disconnected from '" + disconnectProcess.ssid + "'")
                root._wifiConnected = false
                root._updateNetworkStatus(disconnectProcess.ssid, false)
                root.disconnectingFrom = ""
                delayedScanTimer.interval = 3000
                delayedScanTimer.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.disconnectingFrom = ""
                if (text.trim()) console.warn("[Network] disconnect error:", text)
                delayedScanTimer.interval = 5000
                delayedScanTimer.restart()
            }
        }
    }

    // Forget.
    Process {
        id: forgetProcess
        property string ssid: ""
        running: false
        environment: ({ "LC_ALL": "C" })
        command: {
            var script = `
                ssid="$1"
                UUID=$(nmcli -t -f NAME,UUID,TYPE connection show | awk -F: -v target="$ssid" '$1 == target && $3 == "802-11-wireless" { print $2; exit }')
                if [ -n "$UUID" ]; then nmcli connection delete uuid "$UUID" 2>/dev/null; fi
            `
            return ["sh", "-c", script, "--", ssid]
        }
        stdout: StdioCollector {
            onStreamFinished: {
                console.info("[Network] forgot '" + forgetProcess.ssid + "'")
                var nets = root.networks
                if (nets[forgetProcess.ssid]) {
                    nets[forgetProcess.ssid].existing = false
                    root.networks = ({})
                    root.networks = nets
                }
                root.forgettingNetwork = ""
                delayedScanTimer.interval = 5000
                delayedScanTimer.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.forgettingNetwork = ""
                if (text.trim()) console.warn("[Network] forget error:", text)
                delayedScanTimer.interval = 5000
                delayedScanTimer.restart()
            }
        }
    }
}
