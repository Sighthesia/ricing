pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "./network/NetworkLogic.js" as Logic
import "./" as Services

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

    // Every device NetworkManager reports, with its own addressing.
    readonly property var devices: _devices
    // Saved 802-3-ethernet profiles, and the same profiles grouped under the
    // port each belongs to — this is what the panel's wired rows read.
    readonly property var wiredProfiles: _wiredProfiles
    readonly property var wiredGroups: _wiredGroups
    // The link the details block describes: wired when it is up, else wireless.
    readonly property var linkDetails: _linkDetails

    property bool _wifiAvailable: false
    property bool _wifiConnected: false
    property bool _ethernetAvailable: false
    property bool _ethernetConnected: false
    property string _activeEthernetIf: ""
    property string _activeEthernetConnection: ""
    property var _ethernetInterfaces: []
    property bool _internetConnectivity: false
    property string _networkConnectivity: "unknown"
    property var _devices: []
    property var _wiredProfiles: []
    property var _wiredGroups: []
    property var _linkDetails: ({
        device: "", type: "", connection: "", ip4: "", gateway: "", dns: []
    })

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
    // uuid of the connection each kind of link is actually running. This is the
    // only reliable handle for "disconnect this": NetworkManager renames
    // duplicate profiles ("SSID 1"), so the SSID a scan reports is frequently
    // not the id `nmcli connection down` accepts — which is why tapping the
    // connected row used to do nothing at all.
    property string activeWifiUuid: ""
    property string activeEthernetUuid: ""
    // Wi-Fi interface name, tracked whether or not a link is up, so a connect
    // can be pinned to the right adapter on multi-radio machines.
    property string wifiDevice: ""
    // Wired profile uuid in flight, and which of the two directions it is.
    property string wiredActivating: ""
    property string wiredDeactivating: ""

    // nmcli availability (self-checked, no external ProgramCheckerService)
    property bool nmcliAvailable: false

    // --- Internal bookkeeping ---
    // A full radio rescan is expensive and can stall the shell during chrome
    // bootstrap; startup reads NetworkManager's cached results and deliberate
    // popup refreshes still opt into a real scan.
    property bool _rescanRequested: false
    property int _deviceWaitTries: 0
    property bool _awaitingDevice: false
    // The profile map was ranked before the adapter name was known.
    property bool _profilesResolvedBlind: false
    property real _lastOpenRefreshAt: 0
    property string _connectStderr: ""
    property string _wiredStderr: ""
    // Immutable snapshot of the wired attempt in flight, for the same reason
    // `_job` exists on the wireless side.
    property string _wiredJob: ""
    // Whether that attempt started on a port the kernel reports as having no
    // carrier, and which port — captured at submit time because the device table
    // can move underneath a four-second wait.
    property bool _wiredNoCable: false
    property string _wiredDevice: ""
    // True while an nmcli process for a wired attempt is still running. The
    // in-flight marker clears when the watchdog gives up on the row, but NM's
    // queued activation lives on for another two minutes after that.
    property bool _wiredBusy: false
    // Immutable snapshot of the attempt in flight. onExited reads this instead
    // of the live Process properties, which a fast second tap would already
    // have overwritten — that cross-talk reported the first attempt's exit
    // code as the second attempt's result.
    property var _job: null

    readonly property var cEnvironment: ({ "LC_ALL": "C", "LANG": "C" })

    // nmcli has no --wait on this version, so a request that never completes
    // would leave the row spinning forever. Cap the attempt ourselves.
    Timer {
        id: connectWatchdog
        interval: 60000
        repeat: false
        onTriggered: {
            if (!root.connecting || !root._job)
                return
            console.warn("[Network] connect timed out for '" + root._job.ssid + "'")
            root._finishConnect(false, "net.error.timeout")
        }
    }

    // nmcli has no --wait on this version, so a request that never completes
    // would leave the row spinning forever. Cap the attempt ourselves. The
    // interval is set per attempt: a port with no carrier gets a short leash,
    // because nothing is going to arrive on its own there. This covers both
    // wired directions — a deactivation cannot hang on a carrier wait, but the
    // row it holds is frozen for as long as the marker is set, so it needs the
    // same guarantee.
    Timer {
        id: wiredWatchdog
        interval: 30000
        repeat: false
        onTriggered: {
            if (!root.wiredActivating && !root.wiredDeactivating)
                return
            var label = root.wiredActivating !== "" ? root.wiredActivating : root.wiredDeactivating
            console.warn("[Network] wired attempt on '" + label + "' timed out after "
                + interval + "ms")
            root._finishWired(false, root.wiredActivating !== ""
                ? root._wiredTimeoutMessage() : "net.error.deactivationTimeout")
        }
    }

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
        // Do not wake the radio during startup. The first popup open requests a
        // fresh scan through refreshForOpen(); this pass only warms cached data.
        onTriggered: if (root.wifiEnabled) root.requestScan(false, false)
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
        root._refreshProfiles()
        root.scanningActive = true
        console.info("[Network] scanning Wi-Fi (rescan=" + root._rescanRequested + ")…")
    }

    // The saved-profile chain, which feeds both the wireless lookup and the
    // wired profile list. Deliberately independent of the radio: with Wi-Fi
    // switched off the wireless scan is skipped, but a wired profile still has
    // to be resolvable — that is exactly the state a direct-connect setup is
    // used in.
    function _refreshProfiles() {
        if (!root.nmcliAvailable)
            return
        if (profileCheckProcess.running || profileDetailProcess.running)
            return
        profileCheckProcess.running = true
    }

    // Profiles are in; the wireless list follows only when the radio is on.
    function _afterProfiles() {
        if (root.wifiEnabled)
            root._startScan()
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
        // Profiles first, unconditionally: the wired rows are built from them
        // and a radio-off start used to leave every wired profile unlisted.
        root._refreshProfiles()
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
            root._setError("net.error.enterprise", ssid)
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

    // Deactivate a wireless profile. The handle is a uuid wherever one can be
    // resolved: the running connection's own uuid first (that is literally the
    // link being torn down), then the saved profile's. Only a machine with no
    // profile at all falls back to the name, and `nmcli` refuses that loudly
    // instead of silently doing nothing.
    function disconnect(ssid) {
        if (!root.nmcliAvailable || !ssid) return
        var net = root.networks[ssid] || null
        var profile = root.savedProfiles[ssid] || null
        var uuid = ""
        if (net && net.connected && root.activeWifiUuid)
            uuid = root.activeWifiUuid
        else if (net && net.savedUuid)
            uuid = net.savedUuid
        else if (profile)
            uuid = profile.uuid
        if (uuid === "") {
            // Refusing outright beats running a command that would report
            // success while leaving the link up.
            root._setError("net.error.noSavedProfile", ssid)
            return
        }
        console.info("[Network] disconnect '" + ssid + "' via uuid " + uuid)
        root.disconnectingFrom = ssid
        disconnectProcess.ssid = ssid
        disconnectProcess.uuid = uuid
        Qt.callLater(function () {
            if (disconnectProcess.running)
                return
            disconnectProcess.running = true
        })
    }

    // --- Wired profiles ---

    function _wiredGroupForProfile(uuid) {
        var groups = root._wiredGroups
        for (var i = 0; i < groups.length; i++) {
            var profiles = groups[i].profiles || []
            for (var j = 0; j < profiles.length; j++) {
                if (profiles[j].uuid === uuid)
                    return groups[i]
            }
        }
        return null
    }

    // Bring a saved wired profile up, or take the running one down. Both are
    // uuid-only, for the same reason the wireless disconnect is: a profile name
    // is not a handle NetworkManager guarantees to keep.
    function toggleWiredProfile(uuid) {
        if (!root.nmcliAvailable || !uuid)
            return
        var target = String(uuid)
        if (root.wiredActivating === target || root.wiredDeactivating === target)
            return
        // One attempt at a time. `wiredActivating` clears when the watchdog gives
        // up on the row, but the nmcli behind it is still running — NM queues an
        // activation on a port with no carrier and cancels it 120s later — so
        // this is what actually stops a second one from starting.
        if (root._wiredBusy)
            return
        var group = root._wiredGroupForProfile(target)
        var profiles = group ? (group.profiles || []) : []
        var profile = null
        for (var i = 0; i < profiles.length; i++) {
            if (profiles[i].uuid === target)
                profile = profiles[i]
        }
        if (profile && profile.active) {
            root.disconnectWired(target)
            return
        }
        root.activateWired(target)
    }

    function activateWired(uuid) {
        if (!root.nmcliAvailable || !uuid || root._wiredBusy)
            return
        var target = String(uuid)
        var group = root._wiredGroupForProfile(target)
        var profiles = group ? (group.profiles || []) : []
        var profile = null
        for (var i = 0; i < profiles.length; i++) {
            if (profiles[i].uuid === target)
                profile = profiles[i]
        }
        if (profile && profile.stalePin) {
            // Activating it would be refused with a mismatching interface name
            // that names an adapter the user cannot see or change from here.
            root._setError("net.error.stalePin", "")
            return
        }
        // A port with no carrier is attempted anyway. Refusing here used to make
        // the row a dead end: NetworkManager queues such an activation and
        // completes it the moment a cable appears, so "plug it in, then tap" is
        // a flow the user can actually finish. What changes is the leash — a
        // short one, and a message that says what to do — so the failure is a
        // few seconds of "Connecting…" instead of two silent minutes.
        var noCable = !!(group && group.carrier === "off")
        root.wiredActivating = target
        root._wiredJob = target
        root._wiredNoCable = noCable
        root._wiredDevice = group ? String(group.device || "") : ""
        root._clearError()
        wiredWatchdog.interval = Logic.wiredActivationTimeout(group ? group.carrier : "")
        wiredWatchdog.restart()
        console.info("[Network] activating wired profile '" + target + "'"
            + (noCable ? " on " + root._wiredDevice + " (no carrier, short leash)" : ""))
        // One turn of separation from the state assignment, so the Process
        // starts against this profile rather than the previous one.
        Qt.callLater(root._startWiredUp)
    }

    function disconnectWired(uuid) {
        if (!root.nmcliAvailable || !uuid || root._wiredBusy)
            return
        var target = String(uuid)
        root.wiredDeactivating = target
        root._wiredJob = target
        root._wiredNoCable = false
        root._wiredDevice = ""
        root._clearError()
        wiredWatchdog.restart()
        console.info("[Network] deactivating wired profile '" + target + "'")
        Qt.callLater(root._startWiredDown)
    }

    // A no-cable timeout has to name the port and the fix: "Activation timeout"
    // tells the user nothing they can act on, and this is the one failure a
    // direct-connect setup hits routinely.
    function _wiredTimeoutMessage() {
        if (root._wiredNoCable)
            return Services.Tr.q("net.error.noCableOn",
                { port: root._wiredDevice || Services.Tr.q("net.error.thisPort") })
        return "net.error.activationTimeout"
    }

    function _startWiredUp() {
        if (wiredUpProcess.running || !root._wiredJob)
            return
        root._wiredBusy = true
        wiredUpProcess.running = true
    }

    function _startWiredDown() {
        if (wiredDownProcess.running || !root._wiredJob)
            return
        root._wiredBusy = true
        wiredDownProcess.running = true
    }

    // Single settle point for both wired directions, so the in-flight markers
    // and the follow-up device read cannot be applied by two different handlers.
    function _finishWired(ok, message) {
        var target = root._wiredJob
        wiredWatchdog.stop()
        root.wiredActivating = ""
        root.wiredDeactivating = ""
        root._wiredJob = ""
        if (!ok)
            root._setError(message, "")
        // The device table is the authority for whether the link came up, and
        // it also carries the addressing the details block shows.
        if (!deviceStatusProcess.running)
            deviceStatusProcess.running = true
        console.info("[Network] wired profile '" + (target || "") + "' "
            + (ok ? "activated" : "failed: " + message))
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
        return Services.Tr.q(Logic.signalLabel(signal))
    }

    // A wired port's header state. The panel asks the service rather than
    // repeating the precedence, because carrier-over-connected is a decision
    // with a reason behind it (NM and the kernel genuinely disagree on this
    // machine) and two copies of that rule will drift.
    function wiredPortState(group) {
        return Logic.linkStateLabel(group)
    }

    // A name where there is one (a connection profile, an SSID) and a
    // translated phrase where there is not, so callers never receive half a
    // sentence in one language glued to a name in another.
    function getStatusText() {
        if (root.ethernetConnected)
            return root.activeEthernetConnection !== ""
                ? root.activeEthernetConnection : Services.Tr.q("common.wired")
        if (root.connecting)
            return root.connectingTo
                ? Services.Tr.q("widget.network.connecting", { ssid: root.connectingTo })
                : Services.Tr.q("widget.network.connectingGeneric")
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
                if (!text.trim()) {
                    root.savedProfiles = ({})
                    root._applyWiredProfiles(Logic.parseWiredProfiles(text, ""))
                }
                Qt.callLater(root._afterProfiles)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("[Network] profile list stderr:", text.trim())
                if (profileDetailProcess.running || scanProcess.running)
                    return
                // Keep the previous map: see the note in the stdout handler.
                Qt.callLater(root._afterProfiles)
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
    // adapter that no longer exists is dead weight that NM refuses outright,
    // and the ipv4 fields ride along because a wired profile is only useful to
    // the user if the address it will hand out is visible before it is up.
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
                + "802-11-wireless-security.key-mgmt,connection.interface-name,"
                + "ipv4.method,ipv4.addresses,ipv4.gateway,connection.autoconnect",
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
                root._applyWiredProfiles(Logic.parseWiredProfiles(
                    profileCheckProcess.baseText, text))
                profileDetailProcess.detailApplied = true
                Qt.callLater(root._afterProfiles)
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
                // A rejected detail batch still names the profiles, which is
                // enough to activate one — only the addressing is missing.
                root._applyWiredProfiles(Logic.parseWiredProfiles(
                    profileCheckProcess.baseText, ""))
                Qt.callLater(root._afterProfiles)
            }
        }
    }

    // Publish the wired profile list and re-derive the port groups from it.
    // Both happen together because the groups are a join of the profiles with
    // the device table, and the two land in whichever order nmcli answers.
    function _applyWiredProfiles(profiles) {
        root._wiredProfiles = profiles || []
        root._republishWired()
    }

    function _republishWired() {
        root._wiredGroups = Logic.groupWiredProfiles(root._devices, root._wiredProfiles)
    }

    // Device status, with each device's own addressing. The wireless list this
    // used to run as a second command in the same shell was parsed by nobody:
    // the RATE it asked for was thrown away, and the scan already carries it.
    Process {
        id: deviceStatusProcess
        running: false
        environment: root.cEnvironment
        command: ["nmcli", "-t", "-f",
            "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.REASON,"
            + "GENERAL.CONNECTION,GENERAL.CON-UUID,WIRED-PROPERTIES.CARRIER,"
            + "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS",
            "device", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                var devices = Logic.parseDeviceTable(text)
                // Loopback alone guarantees a row, so an empty table is a failed
                // read, not a machine with no network devices. Keep the last
                // good one: a wiped table would read as "no ports, no links".
                if (devices.length === 0) {
                    if (text.trim())
                        console.warn("[Network] device table parsed to nothing")
                    return
                }

                var wifiAvailable = false
                var wifiDevice = ""
                var activeWifiIf = ""
                var activeWifiUuid = ""
                var ethAvailable = false
                var activeEthIf = ""
                var activeEthConn = ""
                var activeEthUuid = ""
                var ethList = []

                for (var b = 0; b < devices.length; b++) {
                    var device = devices[b]
                    if (!device.managed)
                        continue
                    if (device.type === "wifi") {
                        wifiAvailable = true
                        // Track the adapter whether or not it holds a link, so a
                        // connect can still be pinned to it while idle.
                        if (!wifiDevice && device.device) wifiDevice = device.device
                        if (device.connected && !activeWifiIf) {
                            activeWifiIf = device.device
                            activeWifiUuid = device.uuid
                        }
                    } else if (device.type === "ethernet") {
                        ethAvailable = true
                        ethList.push({
                            name: device.device,
                            connection: device.connection,
                            connected: device.connected
                        })
                        if (device.connected && !activeEthIf) {
                            activeEthIf = device.device
                            activeEthConn = device.connection
                            activeEthUuid = device.uuid
                        }
                    }
                }

                root._devices = devices
                root._wifiAvailable = wifiAvailable
                root._wifiConnected = activeWifiIf !== ""
                root.activeWifiIf = activeWifiIf
                root.activeWifiUuid = activeWifiUuid
                root.wifiDevice = wifiDevice
                root._ethernetAvailable = ethAvailable
                root._ethernetConnected = activeEthIf !== ""
                root._activeEthernetIf = activeEthIf
                root._activeEthernetConnection = activeEthConn
                root.activeEthernetUuid = activeEthUuid
                root._ethernetInterfaces = ethList
                root._linkDetails = Logic.activeLinkDetails(devices)
                root._republishWired()

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
        command: ["nmcli", "-t", "-f", "SSID,SECURITY,SIGNAL,RATE,IN-USE", "device", "wifi",
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

    // Disconnect. The exit code is the authority here, not the stdout stream:
    // `nmcli connection down` prints nothing on success, so the old
    // stdout-close handler also "succeeded" for a command that had failed.
    Process {
        id: disconnectProcess
        property string ssid: ""
        property string uuid: ""
        running: false
        environment: root.cEnvironment
        command: ["nmcli"].concat(Logic.downArgs(uuid, uuid !== ""))
        onExited: function (code) {
            var target = disconnectProcess.ssid
            if (code === 0) {
                console.info("[Network] disconnected from '" + target + "'")
                root._wifiConnected = false
                root.activeWifiUuid = ""
                root._updateNetworkStatus(target, false)
            } else {
                root._setError(Logic.classifyConnectError(root._connectStderr), target)
                console.warn("[Network] disconnect failed for '" + target + "'")
            }
            root.disconnectingFrom = ""
            delayedScanTimer.interval = code === 0 ? 3000 : 5000
            delayedScanTimer.restart()
            if (!deviceStatusProcess.running)
                deviceStatusProcess.running = true
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // Fires on stream close even when empty, so this only ever
                // captures a real diagnostic.
                if (!text.trim()) return
                root._connectStderr = text
                console.warn("[Network] disconnect error:", text.trim())
            }
        }
    }

    // Bring a saved wired profile up. Its own Process: the two directions have
    // different argv shapes, and one Process flipping `command` between two
    // `running` writes can start with the previous turn's argv.
    Process {
        id: wiredUpProcess
        running: false
        environment: root.cEnvironment
        command: ["nmcli"].concat(Logic.upArgs(root._wiredJob))
        onExited: function (code) {
            // The attempt is over for real now, so the busy guard can lift even
            // if the watchdog already gave up on the row.
            root._wiredBusy = false
            if (!root._wiredJob) return
            if (code === 0)
                root._finishWired(true, "")
            else
                root._finishWired(false, Logic.classifyConnectError(root._wiredStderr))
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return
                root._wiredStderr = text
                console.warn("[Network] wired activation error: " + text.trim())
            }
        }
    }

    // Take the running wired profile down.
    Process {
        id: wiredDownProcess
        running: false
        environment: root.cEnvironment
        command: ["nmcli"].concat(Logic.downArgs(root._wiredJob, true))
        onExited: function (code) {
            root._wiredBusy = false
            if (!root._wiredJob) return
            if (code === 0)
                root._finishWired(true, "")
            else
                root._finishWired(false, Logic.classifyConnectError(root._wiredStderr))
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return
                root._wiredStderr = text
                console.warn("[Network] wired deactivation error: " + text.trim())
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
