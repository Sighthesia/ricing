import QtQuick
import "../lazerbar"
import "widgets" as ClockWidgets
import "./BarTrayMenuLogic.js" as Logic

// Content body for volume, brightness, media, notifications, tray and clock.
// Bound via BarPopupHost contentData; intent actionKind/payload drive visible kind.
Item {
    id: root

    property string actionKind: ""
    property var payload: null
    signal dismissRequested()

    // Expanding the panel is the moment a stale list hurts most, so the
    // network body asks the service for a fresh read of the radio. The popup
    // is constructed already bound to its kind, which fires no change signal,
    // so the first read is requested from onCompleted too.
    onActionKindChanged: if (root.actionKind === "network") root.refreshWifi()
    onPayloadChanged: if (root.actionKind === "network") root.refreshWifi()
    Component.onCompleted: if (root.actionKind === "network") root.refreshWifi()

    implicitWidth: root.actionKind === "media" ? 420 : 260
    implicitHeight: root.actionKind === "context" ? 0 : contentColumn.implicitHeight + 16
    width: implicitWidth
    height: implicitHeight
    visible: root.actionKind !== "context"
    clip: false

    // Live services win over the hover-intent snapshot so the open popup
    // keeps tracking volume and brightness without being rebuilt.
    readonly property var volumeService: payload && payload.volumeService ? payload.volumeService : null
    readonly property var brightnessService: payload && payload.brightnessService ? payload.brightnessService : null
    readonly property real volumeValue: {
        if (root.volumeService && root.volumeService.sinkVolume !== undefined)
            return Math.max(0, Math.min(1, Number(root.volumeService.sinkVolume)))
        if (payload && payload.volume !== undefined && payload.volume !== null)
            return Math.max(0, Math.min(1, Number(payload.volume)))
        return 0.5
    }
    readonly property bool volumeMuted: {
        if (root.volumeService && root.volumeService.sinkMuted !== undefined)
            return !!root.volumeService.sinkMuted
        if (payload && payload.muted !== undefined)
            return !!payload.muted
        return false
    }
    readonly property real brightnessValue: {
        if (root.brightnessService && root.brightnessService.brightness !== undefined)
            return Math.max(0, Math.min(1, Number(root.brightnessService.brightness)))
        if (payload && payload.brightness !== undefined && payload.brightness !== null)
            return Math.max(0, Math.min(1, Number(payload.brightness)))
        return 0.8
    }
    readonly property bool notificationDnd: {
        if (payload && payload.dndEnabled !== undefined)
            return !!payload.dndEnabled
        if (payload && payload.notificationService && payload.notificationService.dndEnabled !== undefined)
            return !!payload.notificationService.dndEnabled
        return false
    }
    // Battery keeps tracking the live service so the open popup follows
    // charge changes without being rebuilt; snapshots cover test fakes.
    readonly property var batteryService: payload && payload.batteryService ? payload.batteryService : null
    readonly property bool batteryReady: {
        if (root.batteryService && root.batteryService.ready !== undefined)
            return !!root.batteryService.ready
        if (payload && payload.ready !== undefined)
            return !!payload.ready
        return false
    }
    readonly property int batteryPct: {
        var raw = -1
        if (root.batteryService && root.batteryService.percentage !== undefined)
            raw = Number(root.batteryService.percentage)
        else if (payload && payload.percentage !== undefined && payload.percentage !== null)
            raw = Number(payload.percentage)
        if (!isFinite(raw) || raw < 0)
            return 0
        return Math.max(0, Math.min(100, Math.round(raw)))
    }
    readonly property real batteryLevel: root.batteryPct / 100
    readonly property bool batteryCharging: {
        if (root.batteryService && root.batteryService.charging !== undefined)
            return !!root.batteryService.charging
        if (payload && payload.charging !== undefined)
            return !!payload.charging
        return false
    }
    readonly property bool batteryPluggedIn: {
        if (root.batteryService && root.batteryService.pluggedIn !== undefined)
            return !!root.batteryService.pluggedIn
        if (payload && payload.pluggedIn !== undefined)
            return !!payload.pluggedIn
        return false
    }
    readonly property bool batteryAttention: {
        if (root.batteryService && (root.batteryService.low !== undefined || root.batteryService.critical !== undefined))
            return !!root.batteryService.low || !!root.batteryService.critical
        if (payload && (payload.low !== undefined || payload.critical !== undefined))
            return !!payload.low || !!payload.critical
        return false
    }
    readonly property string batteryStateText: {
        if (!root.batteryReady)
            return "Unknown"
        if (root.batteryCharging)
            return "Charging"
        if (root.batteryPluggedIn)
            return "Full"
        if (root.batteryAttention)
            return "Low"
        return "Discharging"
    }
    // Bluetooth/network popups bind the live service through the payload so
    // power, scan, and list state stay fresh while the popup is open.
    readonly property var bluetoothService: payload && payload.bluetoothService ? payload.bluetoothService : null
    readonly property bool btAvailable: {
        if (root.bluetoothService && root.bluetoothService.bluetoothAvailable !== undefined)
            return !!root.bluetoothService.bluetoothAvailable
        if (payload && payload.bluetoothAvailable !== undefined)
            return !!payload.bluetoothAvailable
        return true
    }
    readonly property bool btEnabled: {
        if (root.bluetoothService && root.bluetoothService.enabled !== undefined)
            return !!root.bluetoothService.enabled
        if (payload && payload.enabled !== undefined)
            return !!payload.enabled
        return false
    }
    readonly property bool btScanning: {
        if (root.bluetoothService && root.bluetoothService.scanningActive !== undefined)
            return !!root.bluetoothService.scanningActive
        if (payload && payload.scanningActive !== undefined)
            return !!payload.scanningActive
        return false
    }
    readonly property var btDeviceList: {
        if (!root.bluetoothService || !root.bluetoothService.devices)
            return []
        var vals = root.bluetoothService.devices.values
        if (!vals || !vals.length)
            return []
        var arr = vals.slice()
        arr.sort(function (a, b) {
            var aConn = a && a.connected ? 1 : 0
            var bConn = b && b.connected ? 1 : 0
            if (aConn !== bConn)
                return bConn - aConn
            var aPair = a && (a.paired || a.trusted) ? 1 : 0
            var bPair = b && (b.paired || b.trusted) ? 1 : 0
            if (aPair !== bPair)
                return bPair - aPair
            return String(root.btDeviceName(a)).localeCompare(String(root.btDeviceName(b)))
        })
        return arr.slice(0, 6)
    }
    readonly property var networkService: payload && payload.networkService ? payload.networkService : null
    property var pendingWifiNetwork: null
    property string wifiPassword: ""
    readonly property bool wifiEnabled: {
        if (root.networkService && root.networkService.wifiEnabled !== undefined)
            return !!root.networkService.wifiEnabled
        if (payload && payload.wifiEnabled !== undefined)
            return !!payload.wifiEnabled
        return false
    }
    readonly property bool wifiConnected: {
        if (root.networkService && root.networkService.wifiConnected !== undefined)
            return !!root.networkService.wifiConnected
        if (payload && payload.wifiConnected !== undefined)
            return !!payload.wifiConnected
        return false
    }
    readonly property bool wifiScanning: {
        if (root.networkService && root.networkService.scanningActive !== undefined)
            return !!root.networkService.scanningActive
        if (payload && payload.scanningActive !== undefined)
            return !!payload.scanningActive
        return false
    }
    readonly property bool wifiConnecting: {
        if (root.networkService && root.networkService.connecting !== undefined)
            return !!root.networkService.connecting
        if (payload && payload.connecting !== undefined)
            return !!payload.connecting
        return false
    }
    // SSID the live attempt is aimed at, so the row itself can say
    // "Connecting…" — the panel no longer carries a centered status line that
    // repeated the connected network's name.
    readonly property string wifiConnectingTo: {
        if (root.networkService && root.networkService.connectingTo !== undefined)
            return String(root.networkService.connectingTo || "")
        if (payload && payload.connectingTo !== undefined)
            return String(payload.connectingTo || "")
        return ""
    }
    readonly property string wifiError: {
        if (root.networkService && root.networkService.lastError !== undefined)
            return String(root.networkService.lastError || "")
        if (payload && payload.lastError !== undefined)
            return String(payload.lastError || "")
        return ""
    }
    // Every visible network, connected first then by signal. The list used to
    // be truncated to six rows, so on a dense urban band most of the visible
    // networks could not be reached at all; the row area is bounded and
    // scrollable instead.
    readonly property var wifiList: {
        var nets = root.networkService ? root.networkService.networks
            : (payload && payload.networks ? payload.networks : null)
        if (!nets)
            return []
        var arr = Object.keys(nets).map(function (key) { return nets[key] })
        arr.sort(function (a, b) {
            var aConn = a && a.connected ? 1 : 0
            var bConn = b && b.connected ? 1 : 0
            if (aConn !== bConn)
                return bConn - aConn
            return (Number(b && b.signal) || 0) - (Number(a && a.signal) || 0)
        })
        return arr
    }
    // SSID the current error belongs to, and whether its stored secret is
    // worth re-entering rather than just reporting another failure.
    readonly property string wifiErrorSsid: root.networkService
        && root.networkService.lastErrorSsid !== undefined
        ? String(root.networkService.lastErrorSsid || "") : ""
    readonly property bool wifiErrorIsSecret: {
        if (root.wifiError === "")
            return false
        if (root.networkService && typeof root.networkService.isCredentialFailure === "function") {
            try { return !!root.networkService.isCredentialFailure(root.wifiError) } catch (e) { return false }
        }
        return root.wifiError === "Incorrect password"
    }
    readonly property bool wifiErrorNetworkSaved: {
        if (root.wifiErrorSsid === "" || !root.networkService)
            return false
        var net = root.networkService.networks ? root.networkService.networks[root.wifiErrorSsid] : null
        return !!(net && net.existing)
    }
    readonly property bool ethAvailable: {
        if (root.networkService && root.networkService.ethernetAvailable !== undefined)
            return !!root.networkService.ethernetAvailable
        if (payload && payload.ethAvailable !== undefined)
            return !!payload.ethAvailable
        return false
    }
    readonly property bool ethConnected: {
        if (root.networkService && root.networkService.ethernetConnected !== undefined)
            return !!root.networkService.ethernetConnected
        if (payload && payload.ethConnected !== undefined)
            return !!payload.ethConnected
        return false
    }
    readonly property string ethName: {
        if (root.networkService && root.networkService.activeEthernetConnection !== undefined)
            return String(root.networkService.activeEthernetConnection || "")
        if (payload && payload.ethName !== undefined)
            return String(payload.ethName || "")
        return ""
    }
    readonly property int mediaPositionMs: {
        if (payload && payload.mediaControlService && payload.mediaControlService.positionMs !== undefined)
            return Math.max(0, Number(payload.mediaControlService.positionMs))
        if (payload && payload.mediaService && payload.mediaService.positionMs !== undefined)
            return Math.max(0, Number(payload.mediaService.positionMs))
        if (payload && payload.positionMs !== undefined && payload.positionMs !== null)
            return Math.max(0, Number(payload.positionMs))
        return 0
    }
    readonly property int mediaLengthMs: {
        if (payload && payload.mediaControlService && payload.mediaControlService.lengthMs !== undefined)
            return Math.max(0, Number(payload.mediaControlService.lengthMs))
        if (payload && payload.mediaService && payload.mediaService.lengthMs !== undefined)
            return Math.max(0, Number(payload.mediaService.lengthMs))
        if (payload && payload.lengthMs !== undefined && payload.lengthMs !== null)
            return Math.max(0, Number(payload.lengthMs))
        return 0
    }
    readonly property string mediaTitle: {
        if (payload && payload.mediaControlService && payload.mediaControlService.title !== undefined
                && String(payload.mediaControlService.title) !== "")
            return String(payload.mediaControlService.title)
        if (payload && payload.mediaService && payload.mediaService.title !== undefined
                && String(payload.mediaService.title) !== "")
            return String(payload.mediaService.title)
        if (payload && payload.title !== undefined && String(payload.title) !== "")
            return String(payload.title)
        return ""
    }
    readonly property string mediaArtist: {
        if (payload && payload.mediaControlService && payload.mediaControlService.artist !== undefined
                && String(payload.mediaControlService.artist) !== "")
            return String(payload.mediaControlService.artist)
        if (payload && payload.mediaService && payload.mediaService.artist !== undefined
                && String(payload.mediaService.artist) !== "")
            return String(payload.mediaService.artist)
        if (payload && payload.artist !== undefined)
            return String(payload.artist || "")
        return ""
    }
    readonly property string mediaArtUrl: {
        if (payload && payload.mediaControlService && payload.mediaControlService.artUrl !== undefined
                && String(payload.mediaControlService.artUrl) !== "")
            return String(payload.mediaControlService.artUrl)
        if (payload && payload.mediaService && payload.mediaService.artUrl !== undefined
                && String(payload.mediaService.artUrl) !== "")
            return String(payload.mediaService.artUrl)
        if (payload && payload.artUrl !== undefined)
            return String(payload.artUrl || "")
        return ""
    }
    readonly property bool mediaPlaying: {
        if (payload && payload.mediaControlService && payload.mediaControlService.playbackState !== undefined)
            return String(payload.mediaControlService.playbackState) === "playing"
        if (payload && payload.mediaService && payload.mediaService.playbackState !== undefined)
            return String(payload.mediaService.playbackState) === "playing"
        if (payload && payload.playing !== undefined)
            return !!payload.playing
        if (payload && payload.isPlaying !== undefined)
            return !!payload.isPlaying
        return false
    }
    readonly property real mediaProgress: {
        if (root.mediaLengthMs <= 0)
            return 0
        return Math.max(0, Math.min(1, root.mediaPositionMs / root.mediaLengthMs))
    }
    readonly property bool mediaCanSeek: {
        if (payload && payload.mediaControlService && payload.mediaControlService.canSeek !== undefined)
            return !!payload.mediaControlService.canSeek
        if (payload && payload.mediaService && payload.mediaService.canSeek !== undefined)
            return !!payload.mediaService.canSeek
        if (payload && payload.canSeek !== undefined)
            return !!payload.canSeek
        return root.mediaLengthMs > 0
    }
    // Spectrum values flow through the hover payload so this file stays
    // free of direct service imports for qmltestrunner isolation.
    readonly property var mediaSpectrumService:
        payload && payload.spectrumService ? payload.spectrumService : null
    readonly property var mediaSpectrumValues: {
        if (root.mediaSpectrumService && root.mediaSpectrumService.values !== undefined)
            return root.mediaSpectrumService.values
        if (payload && payload.spectrumValues !== undefined && payload.spectrumValues !== null)
            return payload.spectrumValues
        return []
    }
    readonly property int mediaSpectrumWaveDuration: {
        var bpm = 0
        if (root.mediaSpectrumService && root.mediaSpectrumService.bpm !== undefined)
            bpm = Number(root.mediaSpectrumService.bpm)
        if (isFinite(bpm) && bpm > 0)
            return Math.round(Math.max(240, Math.min(1200, 60000 / bpm)))
        return MotionTokens.beatWave
    }
    readonly property var trayMenuHandle: Logic.menuHandleFromPayload(payload)
    readonly property var trayMenuContent: trayMenu

    function formatMediaTime(milliseconds) {
        var seconds = Math.floor(Math.max(0, Number(milliseconds)) / 1000)
        var minutes = Math.floor(seconds / 60)
        seconds %= 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    function handleVolumeValue(v) {
        var nv = Math.max(0, Math.min(1, Number(v)))
        if (!isFinite(nv))
            nv = 0
        if (payload && typeof payload.onVolumeChanged === "function") {
            payload.onVolumeChanged(nv)
            return
        }
        if (payload && payload.volumeService && typeof payload.volumeService.setSinkVolume === "function") {
            payload.volumeService.setSinkVolume(nv)
            return
        }
        if (payload && typeof payload.onValueChanged === "function") {
            payload.onValueChanged(nv)
            return
        }
        // Fallback no-op when no injected service; real shell wires payload to
        // VolumeService.setSinkVolume / toggleSinkMute, so no direct import is
        // needed for qmltestrunner isolation.
    }

    function handleToggleMute() {
        if (payload && typeof payload.onToggleMute === "function") {
            payload.onToggleMute()
            return
        }
        if (payload && typeof payload.onToggleRequested === "function") {
            payload.onToggleRequested()
            return
        }
        if (payload && payload.volumeService && typeof payload.volumeService.toggleSinkMute === "function") {
            payload.volumeService.toggleSinkMute()
            return
        }
    }

    function handleBrightnessValue(v) {
        var nv = Math.max(0, Math.min(1, Number(v)))
        if (!isFinite(nv))
            nv = 0
        if (payload && typeof payload.onBrightnessChanged === "function") {
            payload.onBrightnessChanged(nv)
            return
        }
        if (payload && payload.brightnessService && typeof payload.brightnessService.setBrightness === "function") {
            payload.brightnessService.setBrightness(nv)
            return
        }
        if (payload && typeof payload.onValueChanged === "function") {
            payload.onValueChanged(nv)
            return
        }
    }

    function handleMediaPrevious() {
        if (payload && typeof payload.onPrevious === "function") {
            payload.onPrevious()
            return
        }
        if (payload && payload.mediaService && typeof payload.mediaService.previous === "function") {
            payload.mediaService.previous()
            return
        }
    }

    function handleMediaPlayPause() {
        if (payload && typeof payload.onPlayPause === "function") {
            payload.onPlayPause()
            return
        }
        if (payload && payload.mediaService && typeof payload.mediaService.playPause === "function") {
            payload.mediaService.playPause()
            return
        }
    }

    function handleMediaNext() {
        if (payload && typeof payload.onNext === "function") {
            payload.onNext()
            return
        }
        if (payload && payload.mediaService && typeof payload.mediaService.next === "function") {
            payload.mediaService.next()
            return
        }
    }

    function handleMediaSeek(progressValue) {
        var clamped = Math.max(0, Math.min(1, Number(progressValue)))
        if (!isFinite(clamped))
            return
        if (payload && typeof payload.onSeek === "function") {
            payload.onSeek(clamped)
            return
        }
        if (payload && payload.mediaControlService && typeof payload.mediaControlService.seekToProgress === "function") {
            payload.mediaControlService.seekToProgress(clamped)
            return
        }
        if (payload && payload.mediaService && typeof payload.mediaService.setProgress === "function") {
            payload.mediaService.setProgress(clamped)
            return
        }
    }

    function handleToggleDnd() {
        if (payload && typeof payload.onToggleDnd === "function") {
            payload.onToggleDnd()
            return
        }
        if (payload && payload.notificationService && typeof payload.notificationService.dndEnabled !== "undefined") {
            try { payload.notificationService.dndEnabled = !payload.notificationService.dndEnabled } catch (e) {}
            return
        }
    }

    function handleClearNotifications() {
        if (payload && typeof payload.onMarkAllRead === "function") {
            payload.onMarkAllRead()
            return
        }
        if (payload && payload.notificationService && typeof payload.notificationService.markAllRead === "function") {
            payload.notificationService.markAllRead()
            return
        }
    }

    function handleBluetoothPower(enabled) {
        if (payload && typeof payload.onBluetoothPower === "function") {
            payload.onBluetoothPower(!!enabled)
            return
        }
        if (root.bluetoothService && typeof root.bluetoothService.setBluetoothEnabled === "function") {
            try { root.bluetoothService.setBluetoothEnabled(!!enabled) } catch (e) {}
        }
    }

    // Foot refresh, same contract as the network panel's Rescan: one bounded
    // scan rather than a mode the user has to think about switching off. Falls
    // back to the old toggle when the service predates startScan.
    function handleBluetoothRescan() {
        if (payload && typeof payload.onBluetoothRescan === "function") {
            payload.onBluetoothRescan()
            return
        }
        var service = root.bluetoothService
        if (!service)
            return
        if (typeof service.startScan === "function") {
            try { service.startScan() } catch (e) {}
            return
        }
        if (typeof service.setScanActive === "function") {
            try { service.setScanActive(true) } catch (e) {}
        }
    }

    // Stable display name for a bluetooth device object.
    function btDeviceName(device) {
        if (!device)
            return "Unknown device"
        var name = device.name || device.deviceName || ""
        if (name !== "")
            return String(name)
        return String(device.address || "Unknown device")
    }

    function btDeviceStatus(device) {
        if (!device)
            return ""
        if (device.connected)
            return "Connected"
        if (device.paired || device.trusted)
            return "Paired"
        return "Available"
    }

    // Tap a device row: disconnect when connected, otherwise connect or pair.
    function handleBluetoothDeviceTap(device) {
        if (!device)
            return
        if (payload && typeof payload.onDeviceTap === "function") {
            payload.onDeviceTap(device)
            return
        }
        var service = root.bluetoothService
        if (!service)
            return
        try {
            if (service.canDisconnect && service.canDisconnect(device)) {
                service.disconnectDevice(device)
                return
            }
            if (service.canConnect && service.canConnect(device)) {
                service.connectDeviceWithTrust(device)
                return
            }
            if (service.canPair && service.canPair(device))
                service.pairDevice(device)
        } catch (e) {}
    }

    function handleWifiPower(enabled) {
        if (payload && typeof payload.onWifiPower === "function") {
            payload.onWifiPower(!!enabled)
            return
        }
        if (root.networkService && typeof root.networkService.setWifiEnabled === "function") {
            try { root.networkService.setWifiEnabled(!!enabled) } catch (e) {}
        }
    }

    function handleWifiRescan() {
        if (payload && typeof payload.onRescan === "function") {
            payload.onRescan()
            return
        }
        if (root.networkService && typeof root.networkService.scan === "function") {
            try { root.networkService.scan() } catch (e) {}
        }
    }

    // Re-read the radio when the network popup actually becomes visible. The
    // panel used to render whatever the shell's startup scan had found, so
    // networks that appeared later only showed up after a manual rescan.
    function refreshWifi() {
        var service = root.networkService
        if (!service)
            return
        if (typeof service.refreshForOpen === "function") {
            try { service.refreshForOpen(); return } catch (e) {}
        }
        if (typeof service.scan === "function") {
            try { service.scan() } catch (e) {}
        }
    }

    // A saved profile whose stored secret no longer works: drop the profile so
    // the next tap asks for the password again.
    function handleForgetFailed() {
        var service = root.networkService
        if (!service || root.wifiErrorSsid === "")
            return
        if (typeof service.forget === "function") {
            try { service.forget(root.wifiErrorSsid) } catch (e) {}
        }
        root.pendingWifiNetwork = null
        root.wifiPassword = ""
    }

    // Label a wi-fi network's signal strength.
    function wifiSignalLabel(signal) {
        if (root.networkService && typeof root.networkService.getSignalLabel === "function") {
            try { return String(root.networkService.getSignalLabel(Number(signal) || 0) || "") } catch (e) {}
        }
        var s = Number(signal) || 0
        if (s >= 80) return "Excellent"
        if (s >= 60) return "Good"
        if (s >= 35) return "Fair"
        if (s >= 15) return "Poor"
        return "Weak"
    }

    // Tap a network row: disconnect the active one, otherwise connect.
    // An unsaved secured network collects its password first; a saved one
    // whose stored secret was rejected comes back through the same row instead
    // of failing forever on the stale profile.
    function handleNetworkTap(network) {
        if (!network || !network.ssid)
            return
        if (payload && typeof payload.onConnect === "function") {
            payload.onConnect(String(network.ssid))
            return
        }
        var service = root.networkService
        if (!service)
            return
        var ssid = String(network.ssid)
        try {
            if (network.connected && typeof service.disconnect === "function") {
                service.disconnect(ssid)
            } else if (typeof service.needsPasswordFor === "function"
                    && service.needsPasswordFor(ssid)) {
                root.pendingWifiNetwork = network
                root.wifiPassword = ""
                wifiPasswordInput.forceActiveFocus()
            } else if (!network.existing && service.isSecured
                    && service.isSecured(String(network.security || "--"))) {
                root.pendingWifiNetwork = network
                root.wifiPassword = ""
                wifiPasswordInput.forceActiveFocus()
            } else if (typeof service.connect === "function") {
                service.connect(ssid, "", false, String(network.security || ""))
            }
        } catch (e) {}
    }

    function cancelWifiPassword() {
        root.pendingWifiNetwork = null
        root.wifiPassword = ""
        wifiPasswordInput.focus = false
    }

    function submitWifiPassword() {
        var network = root.pendingWifiNetwork
        if (!network || !root.wifiPassword || !root.networkService || root.wifiConnecting)
            return
        root.networkService.connect(String(network.ssid), root.wifiPassword, false,
            String(network.security || "wpa-psk"))
        root.cancelWifiPassword()
    }

    function handleTrayActivate() {
        if (payload && typeof payload.onActivate === "function") {
            payload.onActivate()
            return
        }
        if (payload && payload.trayModel && typeof payload.trayModel.activate === "function") {
            payload.trayModel.activate()
            return
        }
        if (payload && typeof payload.activate === "function") {
            payload.activate()
            return
        }
        try {
            if (payload && payload.trayItem && typeof payload.trayItem.activate === "function")
                payload.trayItem.activate()
        } catch (e) {}
    }

    function handleTraySecondary() {
        if (payload && typeof payload.onSecondaryActivate === "function") {
            payload.onSecondaryActivate()
            return
        }
        if (payload && typeof payload.onSecondary === "function") {
            payload.onSecondary()
            return
        }
        if (payload && payload.trayModel && typeof payload.trayModel.secondaryActivate === "function") {
            payload.trayModel.secondaryActivate()
            return
        }
        if (payload && typeof payload.secondaryActivate === "function") {
            payload.secondaryActivate()
            return
        }
        try {
            if (payload && payload.trayItem && typeof payload.trayItem.secondaryActivate === "function")
                payload.trayItem.secondaryActivate()
        } catch (e) {}
    }

    function handleTrayMenuDismiss() {
        if (payload && typeof payload.onDismiss === "function")
            payload.onDismiss()
        root.dismissRequested()
    }

    // Root content container; always visible when actionKind is known.
    Column {
        id: contentColumn
        objectName: "actionsRoot"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 8
        visible: true

        // Volume content uses the settings slider and mute rows directly.
        Item {
            id: volumeContent
            objectName: "volumeContent"
            width: parent.width
            height: volumeSlider.height
            visible: root.actionKind === "volume"

            BarPopupSlider {
                id: volumeSlider
                objectName: "volumeSlider"
                width: parent.width
                value: root.volumeValue
                muted: root.volumeMuted
                label: "Volume"
                showMute: true
                onValueCommitted: function(v) { root.handleVolumeValue(v) }
                onToggleRequested: root.handleToggleMute()
            }
        }

        // Brightness content reuses the same settings slider card without mute.
        Item {
            id: brightnessContent
            objectName: "brightnessContent"
            width: parent.width
            height: brightnessSlider.height
            visible: root.actionKind === "brightness"

            BarPopupSlider {
                id: brightnessSlider
                objectName: "brightnessSlider"
                width: parent.width
                value: root.brightnessValue
                muted: false
                label: "Brightness"
                showMute: false
                onValueCommitted: function(v) { root.handleBrightnessValue(v) }
            }
        }

        // Clock content: live rolling HH:MM:SS plus the month calendar.
        // The card ticks on its own timer; reset the viewed month on open
        // so every hover starts at today like the old popup did.
        Item {
            id: clockContent
            objectName: "clockContent"
            width: parent.width
            height: clockPopup.height
            visible: root.actionKind === "clock"
            onVisibleChanged: {
                if (visible)
                    clockPopup.resetView()
            }

            ClockWidgets.ClockPopupContent {
                id: clockPopup
                objectName: "clockPopup"
                width: parent.width
            }
        }

        // Media content: large cover left, title/artist plus icon transport
        // right, draggable progress and spectrum along the bottom.
        Item {
            id: mediaContent
            objectName: "mediaContent"
            width: parent.width
            height: mediaColumn.height + 16
            visible: root.actionKind === "media"

            // Scrub preview while dragging so the fill tracks the pointer
            // instead of lagging one service round-trip behind.
            property bool scrubbing: false
            property real scrubValue: 0
            readonly property real effectiveProgress:
                mediaContent.scrubbing ? mediaContent.scrubValue : root.mediaProgress

            // Settings-row card hosts the whole media surface.
            Rectangle {
                objectName: "mediaCard"
                anchors.fill: parent
                radius: 6
                color: mediaCardHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: mediaCardHover; blocking: false }

            Column {
                id: mediaColumn
                objectName: "mediaColumn"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 8

                // Top: cover art beside the track identity and transport.
                Row {
                    width: parent.width
                    spacing: 10

                    // Large cover art on the left; the music glyph fills in
                    // while no usable artwork is reported.
                    Rectangle {
                        id: mediaCoverFrame
                        objectName: "mediaCoverFrame"
                        width: 104
                        height: 104
                        radius: 6
                        color: LazerTheme.settingsTrack
                        clip: true

                        Image {
                            id: mediaCoverImage
                            objectName: "mediaCoverImage"
                            anchors.fill: parent
                            source: root.mediaArtUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: root.mediaArtUrl !== "" && status !== Image.Error
                            opacity: visible ? 1 : 0

                            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                        }

                        Text {
                            objectName: "mediaCoverFallback"
                            anchors.centerIn: parent
                            text: "\u266B"
                            visible: !mediaCoverImage.visible
                            color: LazerTheme.textMuted
                            font.pixelSize: 32
                        }
                    }

                    // Track identity over the spectrum; transport controls
                    // live in the bottom row under the progress bar.
                    Item {
                        width: parent.width - mediaCoverFrame.width - 10
                        height: mediaCoverFrame.height

                        Text {
                            id: mediaTitleItem
                            objectName: "mediaTitleText"
                            width: parent.width
                            text: root.mediaTitle !== "" ? root.mediaTitle : "Unknown title"
                            color: LazerTheme.textPrimary
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.NoWrap
                        }

                        Text {
                            objectName: "mediaArtistText"
                            anchors.top: mediaTitleItem.bottom
                            anchors.topMargin: 2
                            width: parent.width
                            text: root.mediaArtist !== "" ? root.mediaArtist : "Unknown artist"
                            color: LazerTheme.textMuted
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                        }

                        // Spectrum fills the cover's right flank instead of
                        // costing a full strip between cover and progress.
                        DockzoneSpectrum {
                            id: mediaSpectrum
                            objectName: "mediaSpectrum"
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 40
                            values: root.mediaSpectrumValues
                            barColor: LazerTheme.lightScheme
                                ? Qt.rgba(LazerTheme.accentColor.r, LazerTheme.accentColor.g,
                                    LazerTheme.accentColor.b, 0.58)
                                : LazerTheme.accentColor
                            waveColor: LazerTheme.flashWash
                            waveStrength: LazerTheme.lightScheme ? 1.0 : 0.55
                            waveDuration: root.mediaSpectrumWaveDuration
                        }
                    }
                }

                // Draggable seek bar with a generous hit area.
                Item {
                    id: mediaSeekArea
                    objectName: "mediaSeekArea"
                    width: parent.width
                    height: 20
                    enabled: root.mediaCanSeek

                    function seekFromX(x) {
                        var ratio = Math.max(0, Math.min(1, Number(x) / Math.max(1, width)))
                        if (!isFinite(ratio))
                            return
                        mediaContent.scrubbing = true
                        mediaContent.scrubValue = ratio
                    }

                    Rectangle {
                        objectName: "mediaProgressTrack"
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.14)
                        clip: true

                        Rectangle {
                            objectName: "mediaProgressFill"
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * mediaContent.effectiveProgress
                            radius: 2
                            color: LazerTheme.accentColor

                            Behavior on width {
                                enabled: !MotionTokens.reducedMotion && !mediaContent.scrubbing
                                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    // Small thumb marks the playhead; thumb radius stays
                    // in the 4-6px detail band of the sharp language.
                    Rectangle {
                        objectName: "mediaProgressThumb"
                        width: 10
                        height: 10
                        radius: 5
                        x: Math.max(0, Math.min(mediaSeekArea.width - width,
                            mediaSeekArea.width * mediaContent.effectiveProgress - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        color: LazerTheme.settingsSliderThumb
                        visible: root.mediaCanSeek
                    }

                    MouseArea {
                        objectName: "mediaProgressTap"
                        anchors.fill: parent
                        enabled: root.mediaCanSeek
                        hoverEnabled: true
                        cursorShape: root.mediaCanSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: mouse => mediaSeekArea.seekFromX(mouse.x)
                        onPositionChanged: mouse => {
                            if (pressed)
                                mediaSeekArea.seekFromX(mouse.x)
                        }
                        onReleased: mouse => {
                            mediaSeekArea.seekFromX(mouse.x)
                            root.handleMediaSeek(mediaContent.scrubValue)
                            mediaContent.scrubbing = false
                        }
                    }
                }

                // Bottom row: current/total time with icon transport between.
                Item {
                    width: parent.width
                    height: 32

                    Text {
                        objectName: "mediaPositionText"
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatMediaTime(
                            mediaContent.scrubbing
                                ? mediaContent.scrubValue * root.mediaLengthMs
                                : root.mediaPositionMs)
                        color: LazerTheme.textMuted
                        font.pixelSize: 10
                    }

                    Text {
                        objectName: "mediaLengthText"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatMediaTime(root.mediaLengthMs)
                        color: LazerTheme.textMuted
                        font.pixelSize: 10
                    }

                    // Icon transport buttons.
                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        IconButton {
                            id: mediaPrevButton
                            objectName: "mediaPrevButton"
                            implicitWidth: 32
                            implicitHeight: 32
                            width: 32
                            height: 32
                            source: Qt.resolvedUrl("../lazerbar/icons/previous.svg")
                            accessibleName: "Previous track"
                            onClicked: root.handleMediaPrevious()
                        }

                        IconButton {
                            id: mediaPlayPauseButton
                            objectName: "mediaPlayPauseButton"
                            implicitWidth: 32
                            implicitHeight: 32
                            width: 32
                            height: 32
                            source: root.mediaPlaying
                                ? Qt.resolvedUrl("../lazerbar/icons/pause.svg")
                                : Qt.resolvedUrl("../lazerbar/icons/play.svg")
                            accessibleName: root.mediaPlaying ? "Pause" : "Play"
                            onClicked: root.handleMediaPlayPause()
                        }

                        IconButton {
                            id: mediaNextButton
                            objectName: "mediaNextButton"
                            implicitWidth: 32
                            implicitHeight: 32
                            width: 32
                            height: 32
                            source: Qt.resolvedUrl("../lazerbar/icons/next.svg")
                            accessibleName: "Next track"
                            onClicked: root.handleMediaNext()
                        }
                    }
                }
            }

            // Beat-driven wavefront sweeps the popup spectrum like the pill.
            Connections {
                target: root.mediaSpectrumService
                ignoreUnknownSignals: true
                function onBeat() { mediaSpectrum.triggerWave() }
            }
        }

        // Notifications content: DND toggle and clear.
        Item {
            id: notificationsContent
            objectName: "notificationsContent"
            width: parent.width
            height: 52
            visible: root.actionKind === "notifications"

            // Settings-row card hosts both notification actions.
            Rectangle {
                objectName: "notificationsCard"
                anchors.fill: parent
                radius: 6
                color: notificationsCardHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: notificationsCardHover; blocking: false }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    id: dndButton
                    objectName: "notificationDndButton"
                    width: 72
                    height: 32
                    radius: 6
                    color: root.notificationDnd ? LazerTheme.settingsSelected : (dndHover.hovered ? LazerTheme.hoverFill : "transparent")
                    border.width: root.notificationDnd ? 1.5 : 0
                    border.color: root.notificationDnd ? LazerTheme.settingsAccent : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                    Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: root.notificationDnd ? "DND On" : "DND Off"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: dndHover }
                    TapHandler {
                        objectName: "notificationDndTap"
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleToggleDnd()
                    }
                }

                Rectangle {
                    id: clearButton
                    objectName: "notificationClearButton"
                    width: 72
                    height: 32
                    radius: 6
                    color: clearHover.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: clearHover }
                    TapHandler {
                        objectName: "notificationClearTap"
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleClearNotifications()
                    }
                }
            }
        }

        // Battery content: percentage readout plus state and level bar.
        Item {
            id: batteryContent
            objectName: "batteryContent"
            width: parent.width
            height: batteryCard.height
            visible: root.actionKind === "battery"

            // Settings-row card hosts the battery readout.
            Rectangle {
                id: batteryCard
                objectName: "batteryCard"
                width: parent.width
                height: 64
                radius: 6
                color: batteryCardHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: batteryCardHover; blocking: false }

            Text {
                objectName: "batteryPctText"
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.batteryReady ? root.batteryPct + "%" : "—"
                color: LazerTheme.textPrimary
                font.pixelSize: 18
                font.bold: true
            }

            Text {
                objectName: "batteryStateText"
                anchors.top: parent.top
                anchors.topMargin: 32
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.batteryStateText
                color: root.batteryCharging ? LazerTheme.osuGreen
                    : (root.batteryAttention ? LazerTheme.osuPink : LazerTheme.textMuted)
                font.pixelSize: 10
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 32
                height: 3
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.14)
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * root.batteryLevel
                    radius: 1.5
                    color: root.batteryCharging ? LazerTheme.osuGreen
                        : (root.batteryAttention ? LazerTheme.osuPink : LazerTheme.accentColor)

                    Behavior on width {
                        enabled: !MotionTokens.reducedMotion
                        NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
                    }
                }
            }
        }

        // Bluetooth content: power/scan toggles plus the device list.
        Item {
            id: bluetoothContent
            objectName: "bluetoothContent"
            width: parent.width
            height: btColumn.height
            visible: root.actionKind === "bluetooth"

            Column {
                id: btColumn
                objectName: "btColumn"
                width: parent.width
                spacing: 8

                LazerSettingsRow {
                    id: btPowerRow
                    objectName: "btPowerRow"
                    width: parent.width
                    labelText: "Bluetooth"
                    currentValue: root.btEnabled

                    LazerSettingsToggle {
                        id: btPowerToggle
                        objectName: "btPowerToggle"
                        checked: root.btEnabled
                        onToggled: function(next) { root.handleBluetoothPower(next) }
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: !root.btAvailable
                    text: "No adapter"
                    color: LazerTheme.textMuted
                    font.pixelSize: 11
                }

                // Empty-state line, and a claim about results rather than about
                // progress: "no devices found" would be a claim about a search
                // that has not finished, so a live scan states the fact here
                // instead. The ring is not — scan progress is reported in one
                // place only, the foot, as it is for the network panel.
                Text {
                    objectName: "btEmptyText"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.btAvailable && root.btEnabled
                        && root.btDeviceList.length === 0
                    text: root.btScanning ? "Scanning…" : "No devices found"
                    color: LazerTheme.textMuted
                    font.pixelSize: 11
                }

                Repeater {
                    id: btRepeater
                    model: root.btAvailable && root.btEnabled ? root.btDeviceList : []

                    delegate: Rectangle {
                        id: btDeviceRow

                        required property var modelData
                        required property int index

                        objectName: "btDeviceRow" + index
                        width: btColumn.width
                        height: 36
                        radius: 6
                        color: btRowHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard

                        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                        HoverHandler { id: btRowHover }
                        TapHandler {
                            objectName: "btDeviceTap" + btDeviceRow.index
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.handleBluetoothDeviceTap(btDeviceRow.modelData)
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 110
                            text: root.btDeviceName(btDeviceRow.modelData)
                            color: LazerTheme.textPrimary
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.btDeviceStatus(btDeviceRow.modelData)
                            color: btDeviceRow.modelData && btDeviceRow.modelData.connected
                                ? LazerTheme.osuGreen : LazerTheme.textMuted
                            font.pixelSize: 10
                        }
                    }
                }

                // Foot refresh, the same shape and contract as the network
                // panel's: the list is the content, the refresh action reads as
                // the foot, and the ring that rides the label is the only
                // report of scan progress in the panel.
                Rectangle {
                    id: btRescanButton
                    objectName: "btRescanButton"
                    width: parent.width
                    height: 32
                    radius: 6
                    visible: root.btAvailable && root.btEnabled
                    color: btRescanHover.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        LazerLoadingRing {
                            objectName: "btScanRing"
                            width: 16
                            height: 16
                            // Hold the slot and fade via `active`; a `visible`
                            // flip would drop it from the Row and slide the
                            // label sideways as the scan starts.
                            active: root.btScanning
                            running: active
                        }

                        Text {
                            objectName: "btRescanLabel"
                            text: root.btScanning ? "Scanning…" : "Rescan"
                            color: LazerTheme.textPrimary
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    HoverHandler { id: btRescanHover }
                    TapHandler {
                        objectName: "btRescanTap"
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        enabled: !root.btScanning
                        onTapped: root.handleBluetoothRescan()
                    }
                }
            }
        }

        // Network content: wired link, wi-fi power, status, rescan, plus
        // the wireless network list.
        Item {
            id: networkContent
            objectName: "networkContent"
            width: parent.width
            height: wifiColumn.height
            visible: root.actionKind === "network"

            // Row metrics for the bounded network list.
            readonly property int wifiRowHeight: 36
            readonly property int wifiRowGap: 6
            readonly property int wifiMaxVisibleRows: 5
            readonly property int wifiListContentHeight: root.wifiList.length > 0
                ? root.wifiList.length * wifiRowHeight
                    + (root.wifiList.length - 1) * wifiRowGap
                : 0
            readonly property int wifiListViewportHeight: Math.min(wifiListContentHeight,
                wifiMaxVisibleRows * wifiRowHeight + (wifiMaxVisibleRows - 1) * wifiRowGap)

            Column {
                id: wifiColumn
                objectName: "wifiColumn"
                width: parent.width
                spacing: 8

                // Wired link reads as a static card: no tap action exists.
                Rectangle {
                    id: ethernetRow
                    objectName: "ethernetRow"
                    width: parent.width
                    height: 36
                    radius: 6
                    visible: root.ethAvailable
                    color: LazerTheme.settingsCard

                    Text {
                        objectName: "ethernetNameText"
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 120
                        text: root.ethName !== "" ? root.ethName : "Wired"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        objectName: "ethernetStatusText"
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.ethConnected ? "Connected" : "Not connected"
                        color: root.ethConnected ? LazerTheme.osuGreen : LazerTheme.textMuted
                        font.pixelSize: 10
                    }
                }

                LazerSettingsRow {
                    id: wifiPowerRow
                    objectName: "wifiPowerRow"
                    width: parent.width
                    labelText: "Wi-Fi"
                    currentValue: root.wifiEnabled

                    LazerSettingsToggle {
                        id: wifiPowerToggle
                        objectName: "wifiPowerToggle"
                        checked: root.wifiEnabled
                        onToggled: function(next) { root.handleWifiPower(next) }
                    }
                }

                Text {
                    objectName: "wifiErrorText"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.wifiError !== ""
                    // Leave room for the recovery affordance when one shows.
                    height: root.wifiError === "" ? 0
                        : (root.wifiErrorIsSecret && root.wifiErrorNetworkSaved ? 30 : 24)
                    text: root.wifiError
                    color: LazerTheme.osuPink
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                // A saved profile with a rejected secret cannot recover on its
                // own; forgetting it is the only way back to a password prompt.
                Rectangle {
                    id: wifiForgetButton
                    objectName: "wifiForgetButton"
                    width: parent.width
                    height: visible ? 24 : 0
                    visible: root.wifiError !== "" && root.wifiErrorIsSecret
                        && root.wifiErrorNetworkSaved
                    radius: 6
                    color: forgetHover.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Forget saved profile and retry"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 10
                        font.bold: true
                    }

                    HoverHandler { id: forgetHover }
                    TapHandler {
                        objectName: "wifiForgetTap"
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleForgetFailed()
                    }
                }

                // Collect credentials only for an unsaved secured network.
                Rectangle {
                    id: wifiPasswordPanel
                    objectName: "wifiPasswordPanel"
                    width: parent.width
                    height: root.pendingWifiNetwork ? 74 : 0
                    visible: root.pendingWifiNetwork !== null
                    color: LazerTheme.settingsCard
                    clip: true

                    TextInput {
                        id: wifiPasswordInput
                        objectName: "wifiPasswordInput"
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: wifiPasswordConnect.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        height: 32
                        text: root.wifiPassword
                        echoMode: TextInput.Password
                        color: LazerTheme.textPrimary
                        selectionColor: LazerTheme.settingsAccent
                        clip: true

                        onTextChanged: root.wifiPassword = text
                        Keys.onReturnPressed: root.submitWifiPassword()
                        Keys.onEnterPressed: root.submitWifiPassword()
                    }

                    // Submit credentials without exposing the password in the UI.
                    Rectangle {
                        id: wifiPasswordConnect
                        anchors.right: wifiPasswordCancel.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 58
                        height: 32
                        color: LazerTheme.settingsAccent

                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            color: LazerTheme.textPrimary
                            font.pixelSize: 10
                        }

                        TapHandler { onTapped: root.submitWifiPassword() }
                    }

                    // Dismiss the credential prompt without changing network state.
                    Rectangle {
                        id: wifiPasswordCancel
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 32
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: LazerTheme.textMuted
                            font.pixelSize: 10
                        }

                        TapHandler { onTapped: root.cancelWifiPassword() }
                    }
                }

                // Bounded, scrollable row area. The panel has to stay inside
                // the popup's geometry budget, but the list must still reach
                // every network the radio reported — six hardcoded rows left
                // the rest of a dense band unreachable.
                ListView {
                    id: wifiListView
                    objectName: "wifiListView"
                    width: parent.width
                    height: root.wifiEnabled ? networkContent.wifiListViewportHeight : 0
                    visible: root.wifiEnabled && count > 0
                    model: root.wifiEnabled ? root.wifiList : []
                    spacing: networkContent.wifiRowGap
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    // A list that already fits must not swallow wheel events;
                    // an overlong one scrolls, without a fling that would keep
                    // the panel moving after the pointer has left it.
                    interactive: networkContent.wifiListContentHeight > height
                    cacheBuffer: height * 2
                    flickDeceleration: 4000
                    maximumFlickVelocity: 200

                    delegate: Rectangle {
                        id: wifiNetRow

                        required property var modelData
                        required property int index

                        objectName: "wifiNetRow" + wifiNetRow.index
                        width: wifiListView.width
                        height: networkContent.wifiRowHeight
                        radius: 6
                        color: wifiRowHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                        border.width: wifiNetRow.modelData && wifiNetRow.modelData.connected ? 1.5 : 0
                        border.color: wifiNetRow.modelData && wifiNetRow.modelData.connected
                            ? LazerTheme.settingsAccent : "transparent"

                        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                        Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }

                        HoverHandler { id: wifiRowHover }
                        TapHandler {
                            objectName: "wifiNetTap" + wifiNetRow.index
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.handleNetworkTap(wifiNetRow.modelData)
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 110
                            text: wifiNetRow.modelData ? String(wifiNetRow.modelData.ssid || "") : ""
                            color: LazerTheme.textPrimary
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            // The row is the only place a network is named, so
                            // the in-flight attempt is reported here rather than
                            // in a separate centered status line.
                            text: {
                                var data = wifiNetRow.modelData
                                if (!data) return ""
                                if (data.connected) return "Connected"
                                if (root.wifiConnecting && root.wifiConnectingTo === String(data.ssid || ""))
                                    return "Connecting…"
                                return root.wifiSignalLabel(data.signal)
                            }
                            color: wifiNetRow.modelData && wifiNetRow.modelData.connected
                                ? LazerTheme.osuGreen
                                : (root.wifiConnecting
                                    && root.wifiConnectingTo === String((wifiNetRow.modelData || {}).ssid || "")
                                    ? LazerTheme.settingsAccent : LazerTheme.textMuted)
                            font.pixelSize: 10
                        }
                    }
                }

                // Rescan sits last: the list is the panel's content, and the
                // refresh action reads as the foot of it. It also carries the
                // transient state the removed centered line used to show.
                Rectangle {
                    id: wifiRescanButton
                    objectName: "wifiRescanButton"
                    width: parent.width
                    height: 32
                    radius: 6
                    visible: root.wifiEnabled
                    color: rescanHover.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    // Label and ring travel as one centred unit. The ring holds
                    // its slot while idle so the text does not shift the moment
                    // a scan starts. The ring rides the label rather than taking
                    // a row of its own: this button already carries the panel's
                    // transient state, and a separate status line for the same
                    // fact is what the foot layout was built to avoid.
                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        // 16px is deliberate — at that size the ring's triangle
                        // field is skipped and the arc turns alone, which is what
                        // a 32px button can carry without reading as speckle.
                        LazerLoadingRing {
                            objectName: "wifiScanRing"
                            width: 16
                            height: 16
                            // Stay in the Row at all times. `active` already fades
                            // the ring, whereas flipping `visible` drops its slot
                            // and slides the label sideways the moment a scan
                            // starts — the opposite of what the shared centre
                            // unit is for.
                            active: root.wifiScanning && !root.wifiConnecting
                            running: active
                        }

                        Text {
                            objectName: "wifiRescanLabel"
                            text: {
                                if (root.wifiConnecting) return "Connecting…"
                                if (root.wifiScanning) return "Scanning…"
                                return "Rescan"
                            }
                            color: LazerTheme.textPrimary
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    HoverHandler { id: rescanHover }
                    TapHandler {
                        objectName: "wifiRescanTap"
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        enabled: !root.wifiScanning && !root.wifiConnecting
                        onTapped: root.handleWifiRescan()
                    }
                }
            }
        }

        // Tray content renders the native menu supplied by the tray item.
        // Cover the contentColumn's 8px outer margin so the primary menu's
        // dark face has no blue surround, while the second level still
        // reveals over the blue section behind the popup.
        Item {
            id: trayContent
            objectName: "trayContent"
            width: parent.width
            height: visible ? trayMenu.implicitHeight : 0
            visible: root.actionKind === "tray"
            // The submenu belongs to this menu instance: retract it when
            // the intent moves on instead of leaving it stale.
            onVisibleChanged: {
                if (!visible) {
                    trayMenu.closeSubmenu()
                    trayMenu.forgetCursor()
                }
            }

            Rectangle {
                objectName: "trayContentBackground"
                anchors.fill: parent
                anchors.margins: -8
                color: LazerTheme.settingsSection
                visible: root.actionKind === "tray"
            }

            // Native menu rows own their own hover and activation behavior.
            BarTrayMenuContent {
                id: trayMenu
                width: parent.width
                menuHandle: root.trayMenuHandle
                trayItem: root.payload && root.payload.trayItem ? root.payload.trayItem : null
                entries: root.payload && root.payload.entries !== undefined
                        ? root.payload.entries : null
                useStubEntries: !!(root.payload && root.payload.useStubEntries)
                onDismissRequested: root.handleTrayMenuDismiss()
            }
        }

        // Fallback for unknown kinds keeps a visible placeholder.
        Rectangle {
            id: fallbackContent
            objectName: "fallbackContent"
            width: parent.width
            height: 32
            radius: 6
            color: LazerTheme.settingsCard
            visible: root.actionKind !== "volume" && root.actionKind !== "brightness" && root.actionKind !== "media" && root.actionKind !== "notifications" && root.actionKind !== "tray" && root.actionKind !== "battery" && root.actionKind !== "bluetooth" && root.actionKind !== "network" && root.actionKind !== "clock" && root.actionKind !== ""

            Text {
                anchors.centerIn: parent
                text: root.actionKind === "" ? "No action" : root.actionKind
                color: LazerTheme.textMuted
                font.pixelSize: 11
            }
        }
    }
}
