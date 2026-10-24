import QtQuick
import "../lazerbar"
import "widgets" as ClockWidgets
import "widgets/BatteryMetrics.js" as BatteryMetrics
import "./BarTrayMenuLogic.js" as Logic
import "../../services" as Services

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
    //
    // The mixer is the only kind whose content depends on a process-backed
    // read, and that read is worthless the moment the panel closes, so opening
    // the kind starts one read plus a bounded poll and closing it stops both.
    // QML allows one handler per property, so both kinds share these.
    onActionKindChanged: {
        if (root.actionKind === "network")
            root.refreshWifi()
        root.syncRoutePolling()
    }
    onPayloadChanged: {
        if (root.actionKind === "network")
            root.refreshWifi()
        root.syncRoutePolling()
    }
    onVisibleChanged: root.syncRoutePolling()
    Component.onCompleted: {
        if (root.actionKind === "network")
            root.refreshWifi()
        root.syncRoutePolling()
    }

    // The service this body started polling on, kept so the stop always reaches
    // the same instance even if the payload is swapped mid-flight.
    property var lastPolledVolumeService: null

    function syncRoutePolling() {
        var shouldPoll = visible && root.actionKind === "volume" && !!root.volumeService
        if (shouldPoll) {
            root.stopRoutePolling()
            if (typeof root.volumeService.setRoutePolling === "function") {
                root.volumeService.setRoutePolling(true)
                root.lastPolledVolumeService = root.volumeService
            }
            return
        }
        root.stopRoutePolling()
    }

    // Public because a body cannot observe the host hiding the whole surface:
    // its own `visible` stays true while the popup closes, so a body-side
    // visibility handler alone would leave pactl polling for the life of the
    // shell. The host calls this on close.
    function stopRoutePolling() {
        if (root.lastPolledVolumeService
                && typeof root.lastPolledVolumeService.setRoutePolling === "function")
            root.lastPolledVolumeService.setRoutePolling(false)
        root.lastPolledVolumeService = null
    }

    // The window hint's width is the body's own, because the body is what knows
    // how many columns there are: a workspace with no windows takes no slot, so
    // the panel is one, two or three columns wide. A number kept here as well
    // would be a second answer to the same question, and the two would disagree
    // the moment a neighbour workspace ran empty.
    //
    // The body's own inset has to be added back. It reports the width of its
    // columns, but it is laid out inside `contentColumn`, which insets each side
    // by `contentInset`. Measuring the body and handing that number to the host
    // as the surface width asks the panel to be 540 wide while only 524 of it
    // has room for content - so the right column is drawn past the edge of the
    // surface and clipped. The body must never be told to stretch to fill: it
    // sizes itself from its columns, and a stretched body would just move the
    // clipping to whichever column happened to be narrowest.
    // Volume is wider than the default card because an application mixer row has
    // to hold an app name, a media name, a slider, a percentage and a route chip
    // on one line each - at 260 the names elide to nothing.
    implicitWidth: root.actionKind === "media" ? 420
        : (root.actionKind === "volume" ? 360
            : (root.actionKind === "window-hint"
                ? (windowHintBody.implicitWidth > 0
                    ? windowHintBody.implicitWidth + root.contentInset * 2 : 260)
                : 260))
    implicitHeight: root.actionKind === "context" ? 0 : contentColumn.implicitHeight + 16
    width: implicitWidth
    height: implicitHeight
    visible: root.actionKind !== "context"
    clip: false

    // The horizontal inset the content column applies to itself, named because
    // the window hint's surface width has to account for it (see `implicitWidth`).
    // Declared here rather than in the column so the two cannot drift: a body
    // measured without this term is 16px narrower than the space it is given, and
    // the overflow is clipped rather than reported.
    readonly property int contentInset: 8

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

    // Device lists and mixer state read live off the injected service, with no
    // snapshot fallback: an empty list means "none right now", and inventing one
    // from the payload would show a device that is not there. Fakes in the test
    // suite simply omit these and the sections render their empty states.
    readonly property var audioSinks: root.volumeService && root.volumeService.sinks !== undefined
        ? (root.volumeService.sinks || []) : []
    readonly property var audioSources: root.volumeService && root.volumeService.sources !== undefined
        ? (root.volumeService.sources || []) : []
    readonly property var audioStreams: root.volumeService && root.volumeService.streams !== undefined
        ? (root.volumeService.streams || []) : []
    readonly property var defaultAudioSinkNode: root.volumeService
        && root.volumeService.defaultSinkNode !== undefined ? root.volumeService.defaultSinkNode : null
    readonly property var defaultAudioSourceNode: root.volumeService
        && root.volumeService.defaultSourceNode !== undefined ? root.volumeService.defaultSourceNode : null

    // Published for the host and the harnesses, matching the `readonly property
    // Item` convention the settings rows use: an id is not reachable from
    // outside the component that declares it.
    readonly property Item volumeContentItem: volumeContent
    readonly property Item volumeScrollItem: volumeScroll
    readonly property Item volumeMasterCardItem: volumeSlider
    readonly property real volumeViewportCap: volumeContent.viewportCap

    // Thin pass-throughs so the mixer component stays free of service imports.
    function streamAppName(stream) {
        if (root.volumeService && typeof root.volumeService.streamAppName === "function")
            return root.volumeService.streamAppName(stream)
        return ""
    }
    function streamMediaName(stream) {
        if (root.volumeService && typeof root.volumeService.streamMediaName === "function")
            return root.volumeService.streamMediaName(stream)
        return ""
    }
    function streamLevel(stream) {
        if (root.volumeService && typeof root.volumeService.streamLevel === "function")
            return root.volumeService.streamLevel(stream)
        return 0
    }
    function streamMuted(stream) {
        if (root.volumeService && typeof root.volumeService.streamMuted === "function")
            return root.volumeService.streamMuted(stream)
        return true
    }
    function streamRouteLabel(stream) {
        if (root.volumeService && typeof root.volumeService.streamRouteLabel === "function")
            return root.volumeService.streamRouteLabel(stream)
        return ""
    }
    function setStreamVolume(stream, value) {
        if (payload && typeof payload.onStreamVolume === "function") {
            payload.onStreamVolume(stream, value)
            return
        }
        if (root.volumeService && typeof root.volumeService.setStreamVolume === "function")
            root.volumeService.setStreamVolume(stream, value)
    }
    function toggleStreamMute(stream) {
        if (payload && typeof payload.onStreamMute === "function") {
            payload.onStreamMute(stream)
            return
        }
        if (root.volumeService && typeof root.volumeService.toggleStreamMute === "function")
            root.volumeService.toggleStreamMute(stream)
    }
    function moveStreamToSink(stream, sink) {
        if (payload && typeof payload.onStreamRoute === "function") {
            payload.onStreamRoute(stream, sink)
            return
        }
        if (root.volumeService && typeof root.volumeService.moveStreamToSink === "function")
            root.volumeService.moveStreamToSink(stream, sink)
    }
    function handleAudioSink(device) {
        if (!device) return
        if (payload && typeof payload.onAudioSink === "function") {
            payload.onAudioSink(device)
            return
        }
        if (root.volumeService && typeof root.volumeService.setAudioSink === "function")
            root.volumeService.setAudioSink(device)
    }
    function handleAudioSource(device) {
        if (!device) return
        if (payload && typeof payload.onAudioSource === "function") {
            payload.onAudioSource(device)
            return
        }
        if (root.volumeService && typeof root.volumeService.setAudioSource === "function")
            root.volumeService.setAudioSource(device)
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
    readonly property real batteryChargeRate: {
        var raw = root.batteryService && root.batteryService.chargeRate !== undefined
            ? Number(root.batteryService.chargeRate)
            : (payload && payload.chargeRate !== undefined ? Number(payload.chargeRate) : 0)
        return isFinite(raw) && raw > 0 ? raw : 0
    }
    readonly property real batteryDischargeRate: {
        var raw = root.batteryService && root.batteryService.dischargeRate !== undefined
            ? Number(root.batteryService.dischargeRate)
            : (payload && payload.dischargeRate !== undefined ? Number(payload.dischargeRate) : 0)
        return isFinite(raw) && raw > 0 ? raw : 0
    }
    readonly property real batteryTimeToEmpty: {
        var raw = root.batteryService && root.batteryService.timeToEmpty !== undefined
            ? Number(root.batteryService.timeToEmpty)
            : (payload && payload.timeToEmpty !== undefined ? Number(payload.timeToEmpty) : 0)
        return isFinite(raw) && raw > 0 ? raw : 0
    }
    readonly property real batteryTimeToFull: {
        var raw = root.batteryService && root.batteryService.timeToFull !== undefined
            ? Number(root.batteryService.timeToFull)
            : (payload && payload.timeToFull !== undefined ? Number(payload.timeToFull) : 0)
        return isFinite(raw) && raw > 0 ? raw : 0
    }
    readonly property bool batteryChargeMode: root.batteryCharging || root.batteryPluggedIn
    readonly property string batteryRateLabel: root.batteryChargeMode
        ? Services.Tr.q("popup.battery.chargeRate") : Services.Tr.q("popup.battery.dischargeRate")
    readonly property string batteryRateText: BatteryMetrics.formatRate(root.batteryChargeMode
        ? root.batteryChargeRate : root.batteryDischargeRate)
    readonly property string batteryTimeLabel: root.batteryChargeMode
        ? Services.Tr.q("popup.battery.timeToFull") : Services.Tr.q("popup.battery.remaining")
    readonly property string batteryTimeText: root.batteryPluggedIn && !root.batteryCharging
        ? Services.Tr.q("widget.battery.full") : BatteryMetrics.formatDuration(root.batteryChargeMode
            ? root.batteryTimeToFull : root.batteryTimeToEmpty)
    readonly property string batteryStateText: {
        if (!root.batteryReady)
            return Services.Tr.q("common.unknown")
        if (root.batteryCharging)
            return Services.Tr.q("widget.battery.charging")
        if (root.batteryPluggedIn)
            return Services.Tr.q("widget.battery.full")
        if (root.batteryAttention)
            return Services.Tr.q("widget.battery.low")
        return Services.Tr.q("widget.battery.discharging")
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
        return root.wifiError === "net.error.incorrectPassword"
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

    // Wired ports, each carrying the saved profiles that belong to it. A wired
    // profile is activated exactly the way a wireless one is — by tapping the
    // row — so the panel shows them as rows rather than as a status card that
    // can only report what is already up.
    readonly property var wiredGroups: {
        var groups = root.networkService && root.networkService.wiredGroups !== undefined
            ? root.networkService.wiredGroups
            : (payload && payload.wiredGroups ? payload.wiredGroups : null)
        return groups || []
    }
    // uuid of the wired profile currently in flight, in either direction.
    readonly property string wiredActivating: {
        if (root.networkService && root.networkService.wiredActivating !== undefined)
            return String(root.networkService.wiredActivating || "")
        if (payload && payload.wiredActivating !== undefined)
            return String(payload.wiredActivating || "")
        return ""
    }
    readonly property string wiredDeactivating: {
        if (root.networkService && root.networkService.wiredDeactivating !== undefined)
            return String(root.networkService.wiredDeactivating || "")
        if (payload && payload.wiredDeactivating !== undefined)
            return String(payload.wiredDeactivating || "")
        return ""
    }
    // The live link's own addressing, for the foot block. Wired wins when it is
    // up: on a machine with both, the wired link is the deliberate one.
    readonly property var linkDetails: {
        var details = root.networkService && root.networkService.linkDetails !== undefined
            ? root.networkService.linkDetails
            : (payload && payload.linkDetails ? payload.linkDetails : null)
        return details || null
    }
    readonly property bool linkDetailsVisible: root.linkDetails !== null
        && String(root.linkDetails.device || "") !== ""
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
    // free of direct service imports.
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
        // needed to reach the service.
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
            return Services.Tr.q("popup.bluetooth.unknownDevice")
        var name = device.name || device.deviceName || ""
        if (name !== "")
            return String(name)
        return String(device.address || Services.Tr.q("popup.bluetooth.unknownDevice"))
    }

    function btDeviceStatus(device) {
        if (!device)
            return ""
        if (device.connected)
            return Services.Tr.q("common.connected")
        if (device.paired || device.trusted)
            return Services.Tr.q("popup.bluetooth.paired")
        return Services.Tr.q("common.available")
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
        if (s >= 80) return Services.Tr.q("popup.network.excellent")
        if (s >= 60) return Services.Tr.q("popup.network.good")
        if (s >= 35) return Services.Tr.q("popup.network.fair")
        if (s >= 15) return Services.Tr.q("popup.network.poor")
        return Services.Tr.q("popup.network.weak")
    }

    // A wireless row's right-hand readout: strength as a percentage plus the
    // link rate. The qualitative word alone cannot answer the question a row is
    // actually asked — "is this the 5 GHz band, and what will it give me" — so
    // the numbers lead and the word is only the fallback for a service that
    // reports neither.
    function wifiRowMeta(net) {
        if (!net)
            return ""
        var parts = []
        var signal = parseInt(net.signal, 10)
        if (isFinite(signal) && signal > 0)
            parts.push(signal + "%")
        var rate = net.rate !== undefined && net.rate !== null ? String(net.rate) : ""
        if (rate !== "")
            parts.push(rate)
        if (parts.length === 0)
            return root.wifiSignalLabel(net.signal)
        return parts.join(" · ")
    }

    // A wired profile's second line: the address it will hand out, or the
    // method when it has none yet. A static-IP profile exists precisely to
    // carry an address, so that address has to be readable before it is up.
    function wiredProfileMeta(profile) {
        if (!profile)
            return ""
        var addresses = profile.addresses ? profile.addresses : []
        if (addresses.length > 0)
            return addresses.join(", ")
        if (profile.methodLabel !== undefined)
            return Services.Tr.q(String(profile.methodLabel || ""))
        var method = String(profile.method || "").toLowerCase()
        if (method === "" || method === "auto")
            return Services.Tr.q("popup.network.dhcp")
        if (method === "manual")
            return Services.Tr.q("popup.network.manual")
        return method
    }

    // A port's header state, from the service so the precedence lives in one
    // place. The fallback keeps a service that predates it readable: "No cable"
    // is the answer a present-but-silent port needs, because it separates
    // "nothing plugged in" from "plugged in, nothing activated".
    function wiredPortState(group) {
        if (root.networkService && typeof root.networkService.wiredPortState === "function") {
            try {
                var state = root.networkService.wiredPortState(group)
                // The service answers with an i18n key. Copy rather than mutate:
                // the object it hands back is not necessarily writable, and a
                // failed write inside this try left the raw key on screen.
                if (state)
                    return { text: Services.Tr.q(String(state.text || "")), tone: state.tone }
            } catch (e) {}
        }
        if (!group)
            return { text: "", tone: "idle" }
        // Same precedence the service uses, so the no-service fallback cannot
        // name a state the service would not.
        if (group.managed === false)
            return { text: Services.Tr.q("net.port.notManaged"), tone: "idle" }
        if (String(group.carrier || "") === "off")
            return { text: Services.Tr.q("popup.network.noCable"), tone: "idle" }
        if (group.connected)
            return { text: Services.Tr.q("common.connected"), tone: "active" }
        var reason = String(group.reason || "")
        if (reason.indexOf("Carrier") !== -1 || reason.indexOf("40 ") === 0)
            return { text: Services.Tr.q("popup.network.noCable"), tone: "idle" }
        return { text: Services.Tr.q("common.disconnected"), tone: "idle" }
    }

    function wiredPortStateColor(tone) {
        return tone === "active" ? LazerTheme.osuGreen : LazerTheme.textMuted
    }

    // Port groups are the one list that can grow past what fits, and a machine
    // with several NICs (a laptop plus a USB adapter) reaches that quickly.
    readonly property int wiredMaxVisibleGroups: 3
    readonly property var wiredVisibleGroups: root.wiredGroups.length > 0
        ? root.wiredGroups.slice(0, wiredMaxVisibleGroups) : []

    // Tap a wired profile row: the running one goes down, anything else comes
    // up. Routed through the service so it can pre-flight the port's carrier
    // instead of leaving an activation queued inside NetworkManager.
    function handleWiredProfileTap(profile) {
        if (!profile || !profile.uuid)
            return
        if (payload && typeof payload.onWiredToggle === "function") {
            payload.onWiredToggle(String(profile.uuid))
            return
        }
        var service = root.networkService
        if (!service)
            return
        if (typeof service.toggleWiredProfile === "function") {
            try { service.toggleWiredProfile(String(profile.uuid)) } catch (e) {}
            return
        }
        // A service without the combined entry point still gets the direction
        // the row is asking for.
        try {
            if (profile.active && typeof service.disconnectWired === "function")
                service.disconnectWired(String(profile.uuid))
            else if (typeof service.activateWired === "function")
                service.activateWired(String(profile.uuid))
        } catch (e) {}
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

    // A window hint activation is forwarded to the intent's callback rather
    // than run here: this body stays free of Quickshell so the component suite
    // can still instantiate it, and the bar keeps ownership of the niri
    // round-trip. The hint is a hold-to-see surface, so an activation
    // deliberately leaves the menu open - mod is still held and the refreshed
    // snapshot is the confirmation.
    function handleHintWindow(windowId) {
        var target = String(windowId || "").trim()
        if (target === "")
            return
        if (payload && typeof payload.onHintWindow === "function")
            payload.onHintWindow(target)
    }

    // Root content container; always visible when actionKind is known.
    Column {
        id: contentColumn
        objectName: "actionsRoot"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.contentInset
        anchors.rightMargin: root.actionKind === "tray" ? 0 : root.contentInset
        anchors.topMargin: 8
        spacing: 8
        visible: true

        // Volume content: the master slider and mute, then the two device
        // lists, then the per-application mixer. One bounded scroll body holds
        // all three because the panel's height is the layer-shell surface
        // height - free-growing sections would resize the committed surface on
        // every hotplug and every stream appearing.
        Item {
            id: volumeContent
            objectName: "volumeContent"
            width: parent.width
            height: volumeScroll.height
            visible: root.actionKind === "volume"
            // A section can grow while the panel is open (a device appears, an
            // app starts playing). The height follows one bounded number, so
            // the host sees a single geometry change per step rather than a
            // cascade of per-section ones.
            readonly property real viewportCap: 540

            // Bounded scroll body. `interactive` only when it actually
            // overflows, so a short panel leaves the wheel to the bar widget's
            // own volume step instead of trapping it on a dead list.
            Flickable {
                id: volumeScroll
                objectName: "volumeScroll"
                width: parent.width
                height: Math.min(contentHeight, volumeContent.viewportCap)
                contentWidth: width
                contentHeight: volumeColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                flickDeceleration: 4000
                maximumFlickVelocity: 200

                Column {
                    id: volumeColumn
                    objectName: "volumeColumn"
                    width: volumeScroll.width
                    // Wider than the 4px gap inside a list: the space between
                    // two sections has to read as "a different kind of thing",
                    // not as one more row of the list above it.
                    spacing: 12

                    // Master level and mute: the settings card this panel has
                    // always opened with. It was briefly restyled into a 38px
                    // strip to match the list rows below it, and that was a
                    // mistake - the strip needed a level glyph on the left and a
                    // mute glyph on the right, so the same speaker appeared twice
                    // on one row, directly under a panel header that already
                    // showed a third one. A labelled settings card carries the
                    // same information with no glyphs at all.
                    BarPopupSlider {
                        id: volumeSlider
                        objectName: "volumeSlider"
                        width: parent.width
                        value: root.volumeValue
                        muted: root.volumeMuted
                        label: Services.Tr.q("widget.volume")
                        showMute: true
                        onValueCommitted: function(v) { root.handleVolumeValue(v) }
                        onToggleRequested: root.handleToggleMute()
                    }

                    // Output devices. Tapping a row makes it the default sink.
                    BarAudioDeviceList {
                        id: outputDeviceList
                        objectName: "outputDeviceList"
                        width: parent.width
                        sectionTitle: Services.Tr.q("popup.audio.output")
                        devices: root.audioSinks
                        currentDevice: root.defaultAudioSinkNode
                        emptyText: Services.Tr.q("popup.audio.noOutputDevices")
                        onDeviceActivated: function (device) { root.handleAudioSink(device) }
                    }

                    // Input devices, same component so the two pickers cannot
                    // drift apart in row metrics or selection treatment.
                    BarAudioDeviceList {
                        id: inputDeviceList
                        objectName: "inputDeviceList"
                        width: parent.width
                        sectionTitle: Services.Tr.q("popup.audio.input")
                        devices: root.audioSources
                        currentDevice: root.defaultAudioSourceNode
                        emptyText: Services.Tr.q("popup.audio.noInputDevices")
                        onDeviceActivated: function (device) { root.handleAudioSource(device) }
                    }

                    // Per-application mixer: level, mute and output route.
                    BarAudioMixer {
                        id: audioMixer
                        objectName: "audioMixer"
                        width: parent.width
                        streams: root.audioStreams
                        sinks: root.audioSinks
                        defaultSink: root.defaultAudioSinkNode
                        appNameOf: function (stream) { return root.streamAppName(stream) }
                        mediaNameOf: function (stream) { return root.streamMediaName(stream) }
                        levelOf: function (stream) { return root.streamLevel(stream) }
                        mutedOf: function (stream) { return root.streamMuted(stream) }
                        routeLabelOf: function (stream) { return root.streamRouteLabel(stream) }
                        streamVolumeSink: function (stream, value) { root.setStreamVolume(stream, value) }
                        streamMuteSink: function (stream) { root.toggleStreamMute(stream) }
                        routeMoveSink: function (stream, sink) { root.moveStreamToSink(stream, sink) }
                    }
                }
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
                label: Services.Tr.q("widget.brightness")
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
                            text: root.mediaTitle !== "" ? root.mediaTitle : Services.Tr.q("popup.media.unknownTitle")
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
                            text: root.mediaArtist !== "" ? root.mediaArtist : Services.Tr.q("popup.media.unknownArtist")
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
                            accessibleName: Services.Tr.q("popup.media.previousTrack")
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
                            accessibleName: root.mediaPlaying ? Services.Tr.q("popup.media.pause") : Services.Tr.q("popup.media.play")
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
                            accessibleName: Services.Tr.q("popup.media.nextTrack")
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
                        text: root.notificationDnd ? Services.Tr.q("popup.notifications.dndOn") : Services.Tr.q("popup.notifications.dndOff")
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
                        text: Services.Tr.q("common.clear")
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

        // Battery content: percentage, power metrics, state, and level bar.
        Item {
            id: batteryContent
            objectName: "batteryContent"
            width: parent.width
            height: batteryCard.height
            visible: root.actionKind === "battery"

            // Settings-row card hosts the live battery readout and estimates.
            Rectangle {
                id: batteryCard
                objectName: "batteryCard"
                width: parent.width
                height: 116
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

            // Charge or discharge rate row. Positioned from the card's own top
            // rather than from the state label's measured bottom: the card is a
            // fixed-height surface with known typography, and a sibling-bottom
            // anchor chain resolved to y=0 here, stacking these rows on top of
            // the centred percentage.
            Item {
                id: batteryRateRow
                objectName: "batteryRateRow"
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.top: parent.top
                anchors.topMargin: 52
                height: 16

                Text {
                    objectName: "batteryRateLabelText"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryRateLabel
                    color: LazerTheme.textMuted
                    font.pixelSize: 10
                }

                Text {
                    objectName: "batteryRateValueText"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryReady ? root.batteryRateText : "—"
                    color: LazerTheme.textPrimary
                    font.pixelSize: 10
                }
            }

            // Remaining or time-to-full estimate row sits above the level bar.
            Item {
                id: batteryTimeRow
                objectName: "batteryTimeRow"
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.top: parent.top
                anchors.topMargin: 68
                height: 16

                Text {
                    objectName: "batteryTimeLabelText"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryTimeLabel
                    color: LazerTheme.textMuted
                    font.pixelSize: 10
                }

                Text {
                    objectName: "batteryTimeValueText"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryReady ? root.batteryTimeText : "—"
                    color: LazerTheme.textPrimary
                    font.pixelSize: 10
                }
            }

            // Level bar remains the final visual anchor in the expanded card.
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
                    labelText: Services.Tr.q("widget.bluetooth")
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
                    text: Services.Tr.q("cc.bluetooth.noAdapter")
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
                    text: root.btScanning ? Services.Tr.q("common.scanning") : Services.Tr.q("popup.bluetooth.noDevices")
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

                    // The label is what gets centred, not the ring+label pair.
                    // The ring holds its slot while idle, so a centred pair
                    // would leave the text sitting ~11px right of centre for as
                    // long as no scan is running — "centred" and "does not move
                    // when a scan starts" only coexist if the ring is laid out
                    // against the label rather than in front of it.
                    Text {
                        id: btRescanLabelItem
                        objectName: "btRescanLabel"
                        anchors.centerIn: parent
                        text: root.btScanning ? Services.Tr.q("common.scanning") : Services.Tr.q("popup.rescan")
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    LazerLoadingRing {
                        objectName: "btScanRing"
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        x: btRescanLabelItem.x - 6 - width
                        // Anchored to the label's edge, so the text does not
                        // depend on the ring's state at all.
                        active: root.btScanning
                        running: active
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

        // Network content: wired ports, wi-fi power, status, rescan, plus
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

                // The live link's own addressing, straight under the identity rail
                // that already names it — so the rail says which link, and this
                // card says what it came up with. It used to sit above the
                // refresh action as bare text on the section face, which read as
                // a stray footnote: the foot of this panel belongs to the list
                // and the action that refreshes it.
                Rectangle {
                    id: linkDetails
                    objectName: "linkDetails"
                    width: parent.width
                    height: visible ? linkDetailsColumn.height + 16 : 0
                    // Collapse by height, not by visibility alone: a Column
                    // measures an invisible child at its full geometry, so a
                    // hidden card would still hold its slot.
                    visible: root.linkDetailsVisible
                    radius: 6
                    color: LazerTheme.settingsCard

                    Column {
                        id: linkDetailsColumn

                        y: 8
                        width: parent.width
                        spacing: 1

                        // The port the numbers belong to. The rail above names
                        // the profile, so this is the only place the interface
                        // appears — and it is what tells two links apart when
                        // both a wired and a wireless one are up.
                        Text {
                            id: linkDetailsCaption
                            objectName: "linkDetailsCaption"
                            width: parent.width - 20
                            x: 10
                            height: 12
                            text: String((root.linkDetails || {}).device || "")
                            color: LazerTheme.textMuted
                            font.pixelSize: 9
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        // Label left, value right — the battery card's readout
                        // contract, so the pair reads as the same kind of thing
                        // everywhere in this shell.
                        Item {
                            id: linkIpRow
                            objectName: "linkIpRow"
                            width: parent.width - 20
                            x: 10
                            height: 14

                            Text {
                                id: linkIpLabelText
                                objectName: "linkIpLabelText"
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: Services.Tr.q("popup.network.ipAddress")
                                color: LazerTheme.textMuted
                                font.pixelSize: 10
                            }

                            Text {
                                objectName: "linkIpValueText"
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: linkIpLabelText.right
                                anchors.leftMargin: 8
                                horizontalAlignment: Text.AlignRight
                                text: String((root.linkDetails || {}).ip4 || "") || "—"
                                color: LazerTheme.textPrimary
                                font.pixelSize: 10
                                elide: Text.ElideLeft
                                maximumLineCount: 1
                            }
                        }

                        Item {
                            id: linkGatewayRow
                            objectName: "linkGatewayRow"
                            width: parent.width - 20
                            x: 10
                            height: 14

                            Text {
                                id: linkGatewayLabelText
                                objectName: "linkGatewayLabelText"
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: Services.Tr.q("popup.network.gateway")
                                color: LazerTheme.textMuted
                                font.pixelSize: 10
                            }

                            Text {
                                objectName: "linkGatewayValueText"
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: linkGatewayLabelText.right
                                anchors.leftMargin: 8
                                horizontalAlignment: Text.AlignRight
                                text: String((root.linkDetails || {}).gateway || "") || "—"
                                color: LazerTheme.textPrimary
                                font.pixelSize: 10
                                elide: Text.ElideLeft
                                maximumLineCount: 1
                            }
                        }

                        Item {
                            id: linkDnsRow
                            objectName: "linkDnsRow"
                            width: parent.width - 20
                            x: 10
                            height: 14

                            Text {
                                id: linkDnsLabelText
                                objectName: "linkDnsLabelText"
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: Services.Tr.q("popup.network.dns")
                                color: LazerTheme.textMuted
                                font.pixelSize: 10
                            }

                            Text {
                                objectName: "linkDnsValueText"
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: linkDnsLabelText.right
                                anchors.leftMargin: 8
                                horizontalAlignment: Text.AlignRight
                                text: {
                                    var dns = (root.linkDetails || {}).dns
                                    if (!dns || dns.length === 0)
                                        return "—"
                                    return dns.join(", ")
                                }
                                color: LazerTheme.textPrimary
                                font.pixelSize: 10
                                elide: Text.ElideLeft
                                maximumLineCount: 1
                            }
                        }
                    }
                }

                // Wired ports, one card per interface, each listing the saved
                // profiles that belong to it. The card is the port — its name
                // and its link state; the rows inside are the profiles, because
                // a profile is the thing a tap acts on. This replaces a static
                // card that could only report a link that was already up.
                Repeater {
                    id: wiredGroupRepeater
                    objectName: "wiredGroupRepeater"
                    model: root.wiredVisibleGroups

                    delegate: Rectangle {
                        id: wiredGroupCard

                        required property var modelData
                        required property int index

                        objectName: "wiredGroupCard" + wiredGroupCard.index
                        width: wifiColumn.width
                        // The column already owns the only 8px inset. Matching
                        // the card height to that offset prevents an extra foot
                        // of empty space below the final wired profile row.
                        height: wiredGroupColumn.height + 8
                        radius: 6
                        color: LazerTheme.settingsCard

                        Column {
                            id: wiredGroupColumn

                            y: 8
                            width: parent.width
                            spacing: 4

                            // Port header: the interface and what its link is
                            // doing. The name elides rather than pushing the
                            // state word off the card.
                            Item {
                                id: wiredPortHeader
                                objectName: "wiredPortHeader" + wiredGroupCard.index
                                width: parent.width
                                height: 16

                                Text {
                                    id: wiredPortNameText
                                    objectName: "wiredPortNameText" + wiredGroupCard.index
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20 - 96
                                    text: String(wiredGroupCard.modelData.device || "") !== ""
                                        ? String(wiredGroupCard.modelData.device)
                                        : Services.Tr.q("popup.network.otherProfiles")
                                    color: LazerTheme.textPrimary
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    id: wiredPortStateText
                                    objectName: "wiredPortStateText" + wiredGroupCard.index
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.wiredPortState(wiredGroupCard.modelData).text
                                    color: root.wiredPortStateColor(
                                        root.wiredPortState(wiredGroupCard.modelData).tone)
                                    font.pixelSize: 10
                                }
                            }

                            // One row per saved profile on this port.
                            Repeater {
                                id: wiredProfileRepeater
                                model: wiredGroupCard.modelData.profiles || []

                                delegate: Rectangle {
                                    id: wiredProfileRow

                                    required property var modelData
                                    required property int index

                                    objectName: "wiredProfileRow" + wiredGroupCard.index
                                        + "_" + wiredProfileRow.index
                                    width: wiredGroupColumn.width
                                    // Leave balanced space around the centered two-line
                                    // identity while keeping the action on this row axis.
                                    height: 32
                                    color: wiredProfileHover.hovered
                                        ? LazerTheme.settingsCardHover : "transparent"

                                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                                    // The running profile is marked with a thin
                                    // colour band, not a rounded outline: a band
                                    // states a fact, an outline decorates.
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 2
                                        height: 20
                                        color: wiredProfileRow.modelData.active
                                            ? LazerTheme.settingsAccent : "transparent"

                                        Behavior on color {
                                            ColorAnimation { duration: MotionTokens.fast }
                                        }
                                    }

                                    // Keep the two-line profile identity centered on the same
                                    // row axis as its action and active indicator.
                                    Item {
                                        id: wiredProfileTextBlock
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.right: wiredProfileStateText.left
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 26

                                        Text {
                                            id: wiredProfileNameText
                                            objectName: "wiredProfileNameText"
                                                + wiredGroupCard.index + "_" + wiredProfileRow.index
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            height: 14
                                            text: String(wiredProfileRow.modelData.name || "")
                                            color: LazerTheme.textPrimary
                                            font.pixelSize: 11
                                            font.bold: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        Text {
                                            id: wiredProfileMetaText
                                            objectName: "wiredProfileMetaText"
                                                + wiredGroupCard.index + "_" + wiredProfileRow.index
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: wiredProfileNameText.bottom
                                            height: 12
                                            text: root.wiredProfileMeta(wiredProfileRow.modelData)
                                            color: LazerTheme.textMuted
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }

                                    // What a tap will do, stated on the row
                                    // rather than left to be read off the border.
                                    Text {
                                        id: wiredProfileStateText
                                        objectName: "wiredProfileStateText"
                                            + wiredGroupCard.index + "_" + wiredProfileRow.index
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        readonly property bool busy: root.wiredActivating
                                                === String(wiredProfileRow.modelData.uuid || "")
                                            || root.wiredDeactivating
                                                === String(wiredProfileRow.modelData.uuid || "")
                                        text: {
                                            var uuid = String(wiredProfileRow.modelData.uuid || "")
                                            if (root.wiredActivating === uuid)
                                                return Services.Tr.q("common.connecting")
                                            if (root.wiredDeactivating === uuid)
                                                return Services.Tr.q("popup.network.disconnecting")
                                            return wiredProfileRow.modelData.active
                                                ? Services.Tr.q("common.disconnect") : Services.Tr.q("common.connect")
                                        }
                                        color: wiredProfileStateText.busy
                                            ? LazerTheme.settingsAccent
                                            : (wiredProfileRow.modelData.active
                                                ? LazerTheme.osuGreen : LazerTheme.textMuted)
                                        font.pixelSize: 10
                                    }

                                    HoverHandler { id: wiredProfileHover }
                                    TapHandler {
                                        objectName: "wiredProfileTap"
                                            + wiredGroupCard.index + "_" + wiredProfileRow.index
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        // One attempt at a time: a second tap on
                                        // the row that is already moving would be
                                        // a second nmcli run fighting the first.
                                        enabled: !wiredProfileStateText.busy
                                        onTapped: root.handleWiredProfileTap(wiredProfileRow.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                LazerSettingsRow {
                    id: wifiPowerRow
                    objectName: "wifiPowerRow"
                    width: parent.width
                    labelText: Services.Tr.q("popup.network.title")
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
                    text: Services.Tr.q(root.wifiError)
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
                        text: Services.Tr.q("popup.network.forgetAndRetry")
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
                            text: Services.Tr.q("common.connect")
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
                            text: Services.Tr.q("common.cancel")
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
                            // in a separate centered status line. Otherwise the
                            // readout is the numbers the row is scanned for:
                            // strength and rate, not a word about strength.
                            text: {
                                var data = wifiNetRow.modelData
                                if (!data) return ""
                                if (root.wifiConnecting
                                        && root.wifiConnectingTo === String(data.ssid || ""))
                                    return Services.Tr.q("common.connecting")
                                return root.wifiRowMeta(data)
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
                                if (root.wifiConnecting) return Services.Tr.q("common.connecting")
                                if (root.wifiScanning) return Services.Tr.q("common.scanning")
                                return Services.Tr.q("popup.rescan")
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
                x: -8
                y: -8
                width: trayMenu.primaryMenuWidth + 16
                height: parent.height + 16
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

        // Mod-key window hint: the active workspace's windows, clickable to
        // focus, with the neighbouring workspaces either side of it. The snapshot
        // travels on the intent payload so a refresh while mod is held updates the
        // rows in place.
        Item {
            id: windowHintContent
            objectName: "windowHintContent"
            // The body's own measured width, not the full column: the panel is
            // exactly as wide as its columns, and letting it fill would stretch
            // the last one instead of leaving the panel the size it asked for.
            width: windowHintBody.implicitWidth
            height: windowHintBody.implicitHeight
            visible: root.actionKind === "window-hint"

            BarWindowHintContent {
                id: windowHintBody
                objectName: "windowHintBody"
                // The active workspace's band has to reach to `bandInset` from the
                // SURFACE, which is further out than this body's own edge. Declared
                // here because `contentInset` is this component's number, not the
                // body's - the body cannot know how far its host inset it.
                surfaceInset: root.contentInset
                hint: root.payload ? root.payload.hint : null
                onWindowActivated: windowId => root.handleHintWindow(windowId)
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
            visible: root.actionKind !== "volume" && root.actionKind !== "brightness" && root.actionKind !== "media" && root.actionKind !== "notifications" && root.actionKind !== "tray" && root.actionKind !== "battery" && root.actionKind !== "bluetooth" && root.actionKind !== "network" && root.actionKind !== "clock" && root.actionKind !== "window-hint" && root.actionKind !== ""

            Text {
                anchors.centerIn: parent
                text: root.actionKind === "" ? Services.Tr.q("popup.noAction") : root.actionKind
                color: LazerTheme.textMuted
                font.pixelSize: 11
            }
        }
    }
}
