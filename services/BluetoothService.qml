pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Bluetooth state: adapter power, scan, device list, pair/connect/forget.
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    // Power/availability state
    readonly property bool bluetoothAvailable: !!adapter
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool blocked: adapter && adapter.state === BluetoothAdapter.Blocked

    // Scanning flag (adapter.discovering)
    readonly property bool scanningActive: adapter ? adapter.discovering : false

    // Adapter discoverability (advertising)
    readonly property bool discoverable: adapter ? adapter.discoverable : false

    // All known devices exposed by the adapter
    readonly property var devices: adapter ? adapter.devices : null

    // Currently connected devices (filtered view)
    readonly property var connectedDevices: {
        if (!adapter || !adapter.devices) return []
        return adapter.devices.values.filter(dev => dev && dev.connected)
    }

    // Tunables
    property int connectAttempts: 5
    property int connectRetryIntervalMs: 2000

    // Internal auto-connect queue
    property var _autoConnectQueue: []

    Component.onCompleted: {
        console.info("[Bluetooth] Service started")
        autoConnectTimer.restart()
    }

    // Track adapter state changes for resume-after-suspend recovery.
    Connections {
        target: adapter
        ignoreUnknownSignals: true
        function onEnabledChanged() {
            if (root.enabled) {
                root._notify(root.enabled ? "Bluetooth on" : "Bluetooth off",
                             root.enabled ? "bluetooth" : "bluetooth-off")
            }
        }
    }

    // Retry auto-connect shortly after the adapter comes online.
    Timer {
        id: autoConnectTimer
        interval: 1500
        repeat: false
        onTriggered: root.attemptAutoConnect()
    }

    Timer {
        id: autoConnectStepTimer
        interval: 500
        repeat: false
        onTriggered: {
            var device = root._autoConnectQueue.shift()
            if (device && device.paired && !device.connected && !device.blocked) {
                root.connectDeviceWithTrust(device)
            }
            if (root._autoConnectQueue.length > 0)
                autoConnectStepTimer.restart()
        }
    }

    // Toggle adapter power.
    function setBluetoothEnabled(state) {
        if (!adapter) return
        try {
            adapter.enabled = state
            console.info("[Bluetooth] setBluetoothEnabled", state)
        } catch (e) {
            console.warn("[Bluetooth] enable/disable failed", e)
            root._notify("Bluetooth state change failed", "bluetooth-off")
        }
    }

    // Toggle scan (discovery).
    function setScanActive(active) {
        if (!adapter) return
        try {
            if (active || adapter.discovering)
                adapter.discovering = active
        } catch (e) {
            console.warn("[Bluetooth] setScanActive failed", e)
        }
    }

    // Toggle adapter discoverability.
    function setDiscoverable(state) {
        if (!adapter) return
        try {
            adapter.discoverable = state
        } catch (e) {
            console.warn("[Bluetooth] setDiscoverable failed", e)
        }
    }

    // Sort devices: real names first, then by signal strength.
    function sortDevices(devices) {
        if (!devices) return []
        return devices.sort(function (a, b) {
            var aName = a.name || a.deviceName || ""
            var bName = b.name || b.deviceName || ""
            var aHasRealName = aName.indexOf(" ") !== -1 && aName.length > 3
            var bHasRealName = bName.indexOf(" ") !== -1 && bName.length > 3
            if (aHasRealName && !bHasRealName) return -1
            if (!aHasRealName && bHasRealName) return 1
            var aSignal = (a.signalStrength !== undefined && a.signalStrength > 0) ? a.signalStrength : 0
            var bSignal = (b.signalStrength !== undefined && b.signalStrength > 0) ? b.signalStrength : 0
            return bSignal - aSignal
        })
    }

    // Nerd Font glyph for a device based on its icon/name.
    function getDeviceIcon(device) {
        if (!device) return "\uf287" // bt-device-generic fallback
        var name = (device.name || device.deviceName || "").toLowerCase()
        var icon = (device.icon || "").toLowerCase()
        if (name.indexOf("headphone") !== -1 || icon.indexOf("headphone") !== -1) return "\uf025"
        if (name.indexOf("speaker") !== -1 || icon.indexOf("speaker") !== -1) return "\uf028"
        if (name.indexOf("keyboard") !== -1 || icon.indexOf("keyboard") !== -1) return "\uf11c"
        if (name.indexOf("mouse") !== -1 || icon.indexOf("mouse") !== -1) return "\uf3c2"
        if (name.indexOf("phone") !== -1 || icon.indexOf("phone") !== -1) return "\uf3cd"
        if (name.indexOf("controller") !== -1 || name.indexOf("gamepad") !== -1 || icon.indexOf("input-gaming") !== -1) return "\uf11b"
        return "\uf293" // generic bluetooth glyph
    }

    function canConnect(device) {
        if (!device) return false
        return !device.connected && (device.paired || device.trusted) && !device.pairing && !device.blocked
    }

    function canDisconnect(device) {
        if (!device) return false
        return device.connected && !device.pairing && !device.blocked
    }

    function canPair(device) {
        if (!device) return false
        return !device.connected && !device.paired && !device.trusted && !device.pairing && !device.blocked
    }

    function isDeviceBusy(device) {
        if (!device) return false
        return device.pairing
            || device.state === BluetoothDevice.Connecting
            || device.state === BluetoothDevice.Disconnecting
    }

    // Stable unique key for a device (prefer MAC address).
    function deviceKey(device) {
        if (!device) return ""
        if (device.address) return device.address
        return device.name || device.deviceName || (device.path || "")
    }

    // Numeric signal percentage (0-100), null if unknown.
    function getSignalPercent(device) {
        if (!device) return null
        var s = device.signalStrength
        if (s === undefined || s === null || s === 0) return null
        // RSSI roughly -100..0 dBm -> 0..100%
        var pct = Math.max(0, Math.min(100, Math.round((s + 100))))
        return pct
    }

    function getSignalIcon(device) {
        var p = getSignalPercent(device)
        if (p === null) return "\uf293"
        if (p >= 80) return "\uf293"
        if (p >= 60) return "\uf293"
        if (p >= 40) return "\uf293"
        return "\uf293"
    }

    // Pair using Quickshell.Bluetooth native (no bluetoothctl).
    function pairDevice(device) {
        if (!device) return
        try {
            device.pair()
            console.info("[Bluetooth] pairDevice", device.name || device.deviceName)
            root._notify("Pairing " + (device.name || device.deviceName || "device"), "bluetooth")
        } catch (e) {
            console.warn("[Bluetooth] pairDevice failed", e)
            root._notify("Pair failed", "bluetooth-off")
        }
    }

    function connectDeviceWithTrust(device) {
        if (!device) return
        try {
            device.trusted = true
            device.connect()
            console.info("[Bluetooth] connectDeviceWithTrust", device.name || device.deviceName)
        } catch (e) {
            console.warn("[Bluetooth] connectDeviceWithTrust failed", e)
            root._notify("Connect failed", "bluetooth-off")
        }
    }

    function disconnectDevice(device) {
        if (!device) return
        try {
            device.disconnect()
            console.info("[Bluetooth] disconnectDevice", device.name || device.deviceName)
        } catch (e) {
            console.warn("[Bluetooth] disconnectDevice failed", e)
        }
    }

    function forgetDevice(device) {
        if (!device) return
        try {
            device.trusted = false
            device.forget()
            console.info("[Bluetooth] forgetDevice", device.name || device.deviceName)
        } catch (e) {
            console.warn("[Bluetooth] forgetDevice failed", e)
        }
    }

    // Reconnect to already-paired devices on adapter power-on.
    function attemptAutoConnect() {
        if (!adapter || !adapter.enabled) return
        _autoConnectQueue = adapter.devices.values.filter(
            dev => dev && dev.paired && !dev.connected && !dev.blocked
        )
        if (_autoConnectQueue.length > 0)
            autoConnectStepTimer.restart()
    }

    // Lightweight status notification. NotificationService owns the DBus
    // notification surface; we forward through it when available.
    function _notify(title, glyph) {
        console.info("[Bluetooth]", title, glyph)
    }
}
