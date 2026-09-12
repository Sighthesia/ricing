import QtQuick
import "../lazerbar"
import "./BarTrayMenuLogic.js" as Logic

// Content body for volume, brightness, media, notifications and tray.
// Bound via BarPopupHost contentData; intent actionKind/payload drive visible kind.
Item {
    id: root

    property string actionKind: ""
    property var payload: null
    signal dismissRequested()

    implicitWidth: 260
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
    readonly property string wifiStatusText: {
        if (root.networkService && typeof root.networkService.getStatusText === "function") {
            try { return String(root.networkService.getStatusText() || "") } catch (e) { return "" }
        }
        if (payload && payload.statusText !== undefined)
            return String(payload.statusText || "")
        return ""
    }
    readonly property string wifiError: {
        if (root.networkService && root.networkService.lastError !== undefined)
            return String(root.networkService.lastError || "")
        if (payload && payload.lastError !== undefined)
            return String(payload.lastError || "")
        return ""
    }
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
        return arr.slice(0, 6)
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

    function handleBluetoothScan(active) {
        if (payload && typeof payload.onBluetoothScan === "function") {
            payload.onBluetoothScan(!!active)
            return
        }
        if (root.bluetoothService && typeof root.bluetoothService.setScanActive === "function") {
            try { root.bluetoothService.setScanActive(!!active) } catch (e) {}
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
    // Saved and open networks connect directly; secured unknowns report
    // through the service's lastError line below the list.
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
        try {
            if (network.connected && typeof service.disconnect === "function")
                service.disconnect(String(network.ssid))
            else if (!network.existing && service.isSecured && service.isSecured(String(network.security || "--"))) {
                root.pendingWifiNetwork = network
                root.wifiPassword = ""
                wifiPasswordInput.forceActiveFocus()
            }
            else if (typeof service.connect === "function")
                service.connect(String(network.ssid), "", false, String(network.security || ""))
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

        // Media content: progress plus previous / playPause / next.
        Item {
            id: mediaContent
            objectName: "mediaContent"
            width: parent.width
            height: 72
            visible: root.actionKind === "media"

            // Settings-row card hosts the transport controls.
            Rectangle {
                objectName: "mediaCard"
                anchors.fill: parent
                radius: 6
                color: mediaCardHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
            HoverHandler { id: mediaCardHover; blocking: false }

            // Existing media timeline data remains visible alongside controls.
            Text {
                objectName: "mediaProgressText"
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.formatMediaTime(root.mediaPositionMs) + " / "
                    + root.formatMediaTime(root.mediaLengthMs)
                color: LazerTheme.textMuted
                font.pixelSize: 10
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: 8

                // Previous button.
                Rectangle {
                    id: mediaPrevButton
                    objectName: "mediaPrevButton"
                    width: 48
                    height: 32
                    radius: 6
                    color: prevHover.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Prev"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: prevHover }
                    TapHandler {
                        objectName: "mediaPrevTap"
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleMediaPrevious()
                    }
                }

                // Play/Pause button.
                Rectangle {
                    id: mediaPlayPauseButton
                    objectName: "mediaPlayPauseButton"
                    width: 64
                    height: 32
                    radius: 6
                    color: playHover.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Play"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: playHover }
                    TapHandler {
                        objectName: "mediaPlayPauseTap"
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleMediaPlayPause()
                    }
                }

                // Next button.
                Rectangle {
                    id: mediaNextButton
                    objectName: "mediaNextButton"
                    width: 48
                    height: 32
                    radius: 6
                    color: nextHover.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Next"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: nextHover }
                    TapHandler {
                        objectName: "mediaNextTap"
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleMediaNext()
                    }
                }
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

                LazerSettingsRow {
                    id: btScanRow
                    objectName: "btScanRow"
                    width: parent.width
                    visible: root.btEnabled && root.btAvailable
                    height: visible ? implicitHeight + listGap : 0
                    labelText: root.btScanning ? "Scanning…" : "Scan"
                    currentValue: root.btScanning

                    LazerSettingsToggle {
                        id: btScanToggle
                        objectName: "btScanToggle"
                        checked: root.btScanning
                        onToggled: function(next) { root.handleBluetoothScan(next) }
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

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.btAvailable && root.btEnabled && root.btDeviceList.length === 0
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

            Column {
                id: wifiColumn
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
                    objectName: "wifiStatusText"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.wifiEnabled || root.ethConnected
                    text: {
                        if (root.ethConnected) return root.ethName !== "" ? root.ethName : "Wired"
                        if (root.wifiConnecting) return "Connecting…"
                        if (root.wifiStatusText !== "") return root.wifiStatusText
                        if (root.wifiScanning) return "Scanning…"
                        return "Not connected"
                    }
                    color: LazerTheme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    objectName: "wifiErrorText"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.wifiError !== ""
                    text: root.wifiError
                    color: LazerTheme.osuPink
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
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

                Rectangle {
                    id: wifiRescanButton
                    objectName: "wifiRescanButton"
                    width: parent.width
                    height: 32
                    radius: 6
                    visible: root.wifiEnabled
                    color: rescanHover.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: root.wifiScanning ? "Scanning…" : "Rescan"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: rescanHover }
                    TapHandler {
                        objectName: "wifiRescanTap"
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.handleWifiRescan()
                    }
                }

                Repeater {
                    id: wifiRepeater
                    model: root.wifiEnabled ? root.wifiList : []

                    delegate: Rectangle {
                        id: wifiNetRow

                        required property var modelData
                        required property int index

                        objectName: "wifiNetRow" + index
                        width: wifiColumn.width
                        height: 36
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
                            text: wifiNetRow.modelData && wifiNetRow.modelData.connected
                                ? "Connected" : root.wifiSignalLabel(wifiNetRow.modelData ? wifiNetRow.modelData.signal : 0)
                            color: wifiNetRow.modelData && wifiNetRow.modelData.connected
                                ? LazerTheme.osuGreen : LazerTheme.textMuted
                            font.pixelSize: 10
                        }
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
            visible: root.actionKind !== "volume" && root.actionKind !== "brightness" && root.actionKind !== "media" && root.actionKind !== "notifications" && root.actionKind !== "tray" && root.actionKind !== "battery" && root.actionKind !== "bluetooth" && root.actionKind !== "network" && root.actionKind !== ""

            Text {
                anchors.centerIn: parent
                text: root.actionKind === "" ? "No action" : root.actionKind
                color: LazerTheme.textMuted
                font.pixelSize: 11
            }
        }
    }
}
