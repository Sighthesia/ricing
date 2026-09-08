import QtQuick
import QtTest
import "../../modules/bar" as Bar
import "../../modules/bar/widgets/BatteryLevel.js" as BatteryLevel

// Content contract for the battery/bluetooth/network popup kinds.
// Uses fake/injected services so real singletons are never mutated.
Item {
    id: root
    width: 400
    height: 1200

    Component { id: actionsComp; Bar.BarPopupActions {} }

    // Recursive search across children/data.
    function findByName(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++) {
                var r = findByName(kids[i], name)
                if (r)
                    return r
            }
        }
        var dataList = item.data
        if (dataList && dataList !== kids) {
            for (var j = 0; j < dataList.length; j++) {
                var d = dataList[j]
                if (!d || d === item)
                    continue
                var already = false
                if (kids) {
                    for (var k = 0; k < kids.length; k++) {
                        if (kids[k] === d) { already = true; break }
                    }
                }
                if (already)
                    continue
                var rd = findByName(d, name)
                if (rd)
                    return rd
            }
        }
        return null
    }

    function makeBatteryService() {
        return Qt.createQmlObject(
            'import QtQuick; QtObject {'
            + ' property bool ready: true;'
            + ' property int percentage: 82;'
            + ' property bool charging: true;'
            + ' property bool pluggedIn: false;'
            + ' property bool low: false;'
            + ' property bool critical: false; }',
            root, "fakeBattery")
    }

    function makeBluetoothService() {
        var svc = Qt.createQmlObject(
            'import QtQuick; QtObject {'
            + ' property bool bluetoothAvailable: true;'
            + ' property bool enabled: true;'
            + ' property bool scanningActive: false;'
            + ' property var devices;'
            + ' property int powerCalls: 0;'
            + ' property bool lastPower: false;'
            + ' property int scanCalls: 0;'
            + ' property bool lastScan: false;'
            + ' property int connectCalls: 0;'
            + ' property int disconnectCalls: 0;'
            + ' property int pairCalls: 0;'
            + ' function setBluetoothEnabled(v) { powerCalls++; lastPower = v; enabled = v }'
            + ' function setScanActive(v) { scanCalls++; lastScan = v; scanningActive = v }'
            + ' function canConnect(d) { return d && !d.connected && (d.paired || d.trusted) }'
            + ' function canDisconnect(d) { return d && !!d.connected }'
            + ' function canPair(d) { return d && !d.connected && !d.paired && !d.trusted }'
            + ' function connectDeviceWithTrust(d) { connectCalls++ }'
            + ' function disconnectDevice(d) { disconnectCalls++ }'
            + ' function pairDevice(d) { pairCalls++ } }',
            root, "fakeBt")
        svc.devices = {
            values: [
                { name: "Headphones", connected: true, paired: true, trusted: true },
                { name: "Keyboard", connected: false, paired: true, trusted: true },
            ]
        }
        return svc
    }

    function makeNetworkService() {
        var svc = Qt.createQmlObject(
            'import QtQuick; QtObject {'
            + ' property bool wifiEnabled: true;'
            + ' property bool wifiConnected: true;'
            + ' property bool scanningActive: false;'
            + ' property bool connecting: false;'
            + ' property bool ethernetAvailable: false;'
            + ' property bool ethernetConnected: false;'
            + ' property string activeEthernetConnection: "";'
            + ' property string lastError: "";'
            + ' property var networks;'
            + ' property int powerCalls: 0;'
            + ' property bool lastPower: false;'
            + ' property int scanCalls: 0;'
            + ' property int connectCalls: 0;'
            + ' property string lastSsid: "";'
            + ' property int disconnectCalls: 0;'
            + ' function setWifiEnabled(v) { powerCalls++; lastPower = v; wifiEnabled = v }'
            + ' function scan() { scanCalls++ }'
            + ' function getStatusText() { return "HomeWifi" }'
            + ' function getSignalLabel(s) { return s >= 80 ? "Excellent" : "Good" }'
            + ' function connect(ssid) { connectCalls++; lastSsid = ssid }'
            + ' function disconnect(ssid) { disconnectCalls++; lastSsid = ssid } }',
            root, "fakeWifi")
        svc.networks = {
            HomeWifi: { ssid: "HomeWifi", security: "WPA2", signal: 85, connected: true, existing: true },
            Cafe: { ssid: "Cafe", security: "--", signal: 55, connected: false, existing: false },
        }
        return svc
    }

    TestCase {
        name: "BarBatteryIcons"
        when: windowShown

        function test_buckets() {
            compare(BatteryLevel.bucketFor(0), 0)
            compare(BatteryLevel.bucketFor(12), 0)
            compare(BatteryLevel.bucketFor(13), 25)
            compare(BatteryLevel.bucketFor(37), 25)
            compare(BatteryLevel.bucketFor(38), 50)
            compare(BatteryLevel.bucketFor(62), 50)
            compare(BatteryLevel.bucketFor(63), 75)
            compare(BatteryLevel.bucketFor(87), 75)
            compare(BatteryLevel.bucketFor(88), 100)
            compare(BatteryLevel.bucketFor(100), 100)
            compare(BatteryLevel.bucketFor(-5), 0)
            compare(BatteryLevel.bucketFor("oops"), 0)
        }

        function test_iconFiles() {
            compare(BatteryLevel.iconFileFor(82, true), "../icons/battery-75.svg")
            compare(BatteryLevel.iconFileFor(100, true), "../icons/battery-100.svg")
            compare(BatteryLevel.iconFileFor(5, true), "../icons/battery-0.svg")
            compare(BatteryLevel.iconFileFor(82, false), "../icons/battery-0.svg")
        }
    }

    TestCase {
        name: "BarBatteryPopup"
        when: windowShown

        function test_batteryRendersReadout() {
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "battery", payload: { batteryService: makeBatteryService() }
            })
            verify(findByName(item, "batteryContent").visible, "batteryContent visible")
            verify(!findByName(item, "volumeContent").visible)
            verify(!findByName(item, "fallbackContent").visible)
            compare(findByName(item, "batteryPctText").text, "82%")
            compare(findByName(item, "batteryStateText").text, "Charging")
            compare(item.batteryLevel, 0.82)
        }

        function test_batteryUnknownState() {
            var svc = makeBatteryService()
            svc.ready = false
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "battery", payload: { batteryService: svc }
            })
            compare(findByName(item, "batteryPctText").text, "—")
            compare(findByName(item, "batteryStateText").text, "Unknown")
        }

        function test_batteryNullPayloadDoesNotThrow() {
            var item = createTemporaryObject(actionsComp, root, { actionKind: "battery", payload: null })
            verify(findByName(item, "batteryContent").visible)
            verify(true, "no throw with null payload")
        }
    }

    TestCase {
        name: "BarBluetoothPopup"
        when: windowShown

        function test_bluetoothRendersTogglesAndDevices() {
            var svc = makeBluetoothService()
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "bluetooth", payload: { bluetoothService: svc }
            })
            verify(findByName(item, "bluetoothContent").visible, "bluetoothContent visible")
            verify(!findByName(item, "fallbackContent").visible)
            verify(findByName(item, "btPowerToggle").checked, "power reflects service")
            compare(item.btDeviceList.length, 2)
            // Connected device sorts first.
            compare(item.btDeviceName(item.btDeviceList[0]), "Headphones")
            compare(item.btDeviceStatus(item.btDeviceList[0]), "Connected")
            // Power toggle routes into the service.
            findByName(item, "btPowerToggle").toggled(false)
            compare(svc.powerCalls, 1)
            verify(!svc.lastPower)
            // Tapping the paired row connects; the connected row disconnects.
            item.handleBluetoothDeviceTap(item.btDeviceList[1])
            compare(svc.connectCalls, 1)
            item.handleBluetoothDeviceTap(item.btDeviceList[0])
            compare(svc.disconnectCalls, 1)
        }

        function test_bluetoothNullPayloadDoesNotThrow() {
            var item = createTemporaryObject(actionsComp, root, { actionKind: "bluetooth", payload: null })
            verify(findByName(item, "bluetoothContent").visible)
            item.handleBluetoothDeviceTap(null)
            verify(true, "no throw with null payload")
        }
    }

    TestCase {
        name: "BarNetworkPopup"
        when: windowShown

        function test_networkRendersStatusAndList() {
            var svc = makeNetworkService()
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            verify(findByName(item, "networkContent").visible, "networkContent visible")
            verify(!findByName(item, "fallbackContent").visible)
            compare(findByName(item, "wifiStatusText").text, "HomeWifi")
            compare(item.wifiList.length, 2)
            compare(item.wifiList[0].ssid, "HomeWifi")
            compare(item.wifiSignalLabel(85), "Excellent")
            // Rescan routes into the service.
            var rescanBtn = findByName(item, "wifiRescanButton")
            verify(rescanBtn !== null, "rescan button should exist")
            verify(rescanBtn.visible, "rescan button visible")
            verify(rescanBtn.enabled, "rescan button enabled")
            item.handleWifiRescan()
            compare(svc.scanCalls, 1)
            // Settings rows grow with an entrance animation; wait for the
            // layout to settle before the synthetic click, like a real user.
            wait(800)
            mouseClick(rescanBtn, rescanBtn.width / 2, rescanBtn.height / 2, Qt.LeftButton)
            tryCompare(svc, "scanCalls", 2, 500)
            // Connected row disconnects, other rows connect.
            item.handleNetworkTap(item.wifiList[0])
            compare(svc.disconnectCalls, 1)
            compare(svc.lastSsid, "HomeWifi")
            item.handleNetworkTap(item.wifiList[1])
            compare(svc.connectCalls, 1)
            compare(svc.lastSsid, "Cafe")
        }

        function test_networkErrorLine() {
            var svc = makeNetworkService()
            svc.lastError = "Incorrect password"
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            var err = findByName(item, "wifiErrorText")
            verify(err.visible, "error line visible")
            compare(err.text, "Incorrect password")
        }

        function test_networkEthernetRow() {
            var svc = makeNetworkService()
            svc.ethernetAvailable = true
            svc.ethernetConnected = true
            svc.activeEthernetConnection = "Office LAN"
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            verify(item.ethAvailable, "ethernet available reflects service")
            verify(item.ethConnected, "ethernet connected reflects service")
            compare(item.ethName, "Office LAN")
            var row = findByName(item, "ethernetRow")
            verify(row !== null, "ethernet row should exist")
            verify(row.visible, "ethernet row visible when adapter present")
            compare(findByName(item, "ethernetStatusText").text, "Connected")
            // Wired link wins the header line.
            compare(findByName(item, "wifiStatusText").text, "Office LAN")
        }

        function test_networkEthernetHiddenWithoutAdapter() {
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: makeNetworkService() }
            })
            verify(!findByName(item, "ethernetRow").visible, "ethernet row hidden without adapter")
        }

        function test_networkNullPayloadDoesNotThrow() {
            var item = createTemporaryObject(actionsComp, root, { actionKind: "network", payload: null })
            verify(findByName(item, "networkContent").visible)
            item.handleNetworkTap(null)
            verify(true, "no throw with null payload")
        }
    }
}
