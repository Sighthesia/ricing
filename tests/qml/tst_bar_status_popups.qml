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
            + ' property string connectingTo: "";'
            + ' property bool ethernetAvailable: false;'
            + ' property bool ethernetConnected: false;'
            + ' property string activeEthernetConnection: "";'
            + ' property string lastError: "";'
            + ' property var networks;'
            + ' property int powerCalls: 0;'
            + ' property bool lastPower: false;'
            + ' property int scanCalls: 0;'
            + ' property int refreshCalls: 0;'
            + ' property int forgetCalls: 0;'
            + ' property string lastForgot: "";'
            + ' property string lastErrorSsid: "";'
            + ' property var passwordNeeded: ({});'
            + ' property int connectCalls: 0;'
            + ' property string lastSsid: "";'
            + ' property string lastPassword: "";'
            + ' property string lastSecurity: "";'
            + ' property int disconnectCalls: 0;'
            + ' function setWifiEnabled(v) { powerCalls++; lastPower = v; wifiEnabled = v }'
            + ' function scan() { scanCalls++ }'
            + ' function refreshForOpen() { refreshCalls++ }'
            + ' function forget(s) { forgetCalls++; lastForgot = s }'
            + ' function needsPasswordFor(s) { return !!passwordNeeded[s] }'
            + ' function isCredentialFailure(m) { return m === "Incorrect password" }'
            + ' function getStatusText() { return "HomeWifi" }'
            + ' function getSignalLabel(s) { return s >= 80 ? "Excellent" : "Good" }'
            + ' function isSecured(s) { return s && s !== "--" && s !== "open" }'
            + ' function connect(ssid, password, hidden, security) { connectCalls++; lastSsid = ssid; lastPassword = password; lastSecurity = security }'
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
            // The centered status line duplicated the connected network's own
            // row, so it is gone; the row carries the state instead.
            verify(findByName(item, "wifiStatusText") === null,
                "centered status line must not come back")
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

        function test_networkSecuredConnectionCollectsPassword() {
            var svc = makeNetworkService()
            svc.wifiConnected = false
            svc.networks = {
                Cafe: { ssid: "Cafe", security: "WPA2", signal: 55, connected: false, existing: false }
            }
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })

            item.handleNetworkTap(item.wifiList[0])
            var panel = findByName(item, "wifiPasswordPanel")
            var input = findByName(item, "wifiPasswordInput")
            verify(panel.visible, "password panel should open for secured network")
            input.text = "secret"
            item.submitWifiPassword()
            compare(svc.connectCalls, 1)
            compare(svc.lastSsid, "Cafe")
            compare(svc.lastPassword, "secret")
            compare(svc.lastSecurity, "WPA2")
            verify(!panel.visible, "password panel should close after submit")
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
            // The wired link names itself on its own card; the removed centered
            // line used to repeat it.
            compare(findByName(item, "ethernetNameText").text, "Office LAN")
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

        // The panel used to render whatever the shell's startup scan had
        // found, so a network that appeared later never showed up.
        function test_networkRefreshesOnOpen() {
            var svc = makeNetworkService()
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            tryCompare(svc, "refreshCalls", 1, 200)
            // A deliberate rescan is a different, user-driven request.
            item.handleWifiRescan()
            compare(svc.scanCalls, 1)
        }

        // Six hardcoded rows left most of a dense band unreachable.
        function test_networkListIsNotTruncated() {
            var svc = makeNetworkService()
            var nets = {}
            for (var i = 0; i < 12; i++) {
                nets["Net" + i] = {
                    ssid: "Net" + i, security: "WPA2", signal: 90 - i,
                    connected: false, existing: true
                }
            }
            svc.networks = nets
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            compare(item.wifiList.length, 12)
            // Sorted by signal, so the strongest network leads.
            compare(item.wifiList[0].ssid, "Net0")
            var list = findByName(item, "wifiListView")
            verify(list !== null, "network list view should exist")
            compare(list.count, 12)
            verify(list.interactive, "an overlong list scrolls")
            verify(list.height < list.contentHeight, "viewport is bounded")
        }

        // A saved profile whose stored secret was rejected is a dead end
        // without a way to drop it.
        function test_networkForgetRecoveryForStaleSecret() {
            var svc = makeNetworkService()
            svc.lastError = "Incorrect password"
            svc.lastErrorSsid = "HomeWifi"
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            var forgetBtn = findByName(item, "wifiForgetButton")
            verify(forgetBtn !== null, "forget button should exist")
            verify(forgetBtn.visible, "forget button shows for a saved secret failure")
            item.handleForgetFailed()
            compare(svc.forgetCalls, 1)
            compare(svc.lastForgot, "HomeWifi")
        }

        function test_networkForgetHiddenForUnrelatedError() {
            var svc = makeNetworkService()
            svc.lastError = "Network not found"
            svc.lastErrorSsid = "HomeWifi"
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            verify(!findByName(item, "wifiForgetButton").visible,
                "forgetting a profile cannot fix a missing network")
        }

        // The service asks for the password again once it has blamed the
        // stored secret, so the row reopens instead of failing silently.
        function test_networkReasksPasswordForStaleSecret() {
            var svc = makeNetworkService()
            svc.wifiConnected = false
            svc.networks = {
                HomeWifi: { ssid: "HomeWifi", security: "WPA2", signal: 85, connected: false, existing: true }
            }
            svc.lastError = "Incorrect password"
            svc.lastErrorSsid = "HomeWifi"
            svc.passwordNeeded = ({ HomeWifi: true })
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            item.handleNetworkTap(item.wifiList[0])
            var panel = findByName(item, "wifiPasswordPanel")
            verify(panel.visible, "password panel should reopen for a stale secret")
            compare(item.pendingWifiNetwork.ssid, "HomeWifi")
        }

        // An open network must never be gated behind a password prompt, and a
        // saved network must not be re-prompted for an unrelated failure.
        function test_networkOpenNetworkConnectsWithoutPassword() {
            var svc = makeNetworkService()
            svc.wifiConnected = false
            svc.networks = {
                FreeHotspot: { ssid: "FreeHotspot", security: "--", signal: 60, connected: false, existing: false }
            }
            svc.passwordNeeded = ({})   // service reports "no password needed"
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            item.handleNetworkTap(item.wifiList[0])
            verify(!findByName(item, "wifiPasswordPanel").visible,
                "an open network connects directly")
            compare(svc.connectCalls, 1)
            compare(svc.lastSsid, "FreeHotspot")
        }

        function test_networkSavedNetworkNotRepromptedForOtherErrors() {
            var svc = makeNetworkService()
            svc.wifiConnected = false
            svc.networks = {
                HomeWifi: { ssid: "HomeWifi", security: "WPA2", signal: 85, connected: false, existing: true }
            }
            svc.lastError = "Connection timeout"
            svc.lastErrorSsid = "HomeWifi"
            svc.passwordNeeded = ({})   // not a credential failure
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            item.handleNetworkTap(item.wifiList[0])
            verify(!findByName(item, "wifiPasswordPanel").visible,
                "a timeout is not fixed by retyping the password")
            compare(svc.connectCalls, 1)
        }
        // The centered status line repeated the connected network's own row, so
        // the panel is now: power row → error → list → rescan, with the row
        // itself reporting "Connecting…".
        function test_networkLayoutOrder() {
            var svc = makeNetworkService()
            svc.networks = {
                HomeWifi: { ssid: "HomeWifi", security: "WPA2", signal: 85, connected: false, existing: true }
            }
            svc.connecting = true
            svc.connectingTo = "HomeWifi"
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            var list = findByName(item, "wifiListView")
            var rescan = findByName(item, "wifiRescanButton")
            verify(list !== null && rescan !== null)
            // The Column positions its children during polish, so the geometry
            // is only meaningful once the layout has settled.
            wait(300)
            verify(rescan.y > list.y, "rescan sits below the list (rescan.y="
                + rescan.y + " list.y=" + list.y + " list.h=" + list.height
                + " rescan.h=" + rescan.height + ")")
            compare(findByName(item, "wifiRescanTap").enabled, false,
                "rescan is inert while an attempt is live")
            compare(findByName(item, "wifiRescanLabel").text, "Connecting…",
                "rescan carries the transient state")
            // The target row reports the attempt in place.
            compare(item.wifiConnectingTo, "HomeWifi")
        }

        // The list is the panel's content, so the refresh action reads as its
        // foot; assert the ordering, not just presence.
        function test_networkRescanIsLastChild() {
            var svc = makeNetworkService()
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            var column = findByName(item, "wifiColumn")
            verify(column !== null, "wifi column should exist")
            compare(column.children[column.children.length - 1].objectName, "wifiRescanButton")
        }

        // The lazer loading ring rides the foot button's label. It has to track
        // the scan, and it has to yield to a live connection attempt — that
        // state already reads as in-flight on its own.
        function test_wifiScanRingTracksTheScan() {
            var svc = makeNetworkService()
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            var ring = findByName(item, "wifiScanRing")
            verify(ring !== null, "wifi panel should carry a scan ring")
            // `active` (which drives opacity) is the ring's on/off state, not
            // `visible`: the ring holds its slot in the Row so the label cannot
            // shift. See test_wifiScanRingDoesNotMoveTheLabel.
            compare(ring.active, false, "ring is idle while nothing is scanning")

            svc.scanningActive = true
            wait(50)
            compare(ring.active, true, "ring runs during a scan")
            compare(ring.running, true)
            compare(findByName(item, "wifiRescanLabel").text, "Scanning…")

            svc.connecting = true
            svc.connectingTo = "HomeWifi"
            wait(50)
            compare(ring.active, false, "ring yields to a connection attempt")
            compare(findByName(item, "wifiRescanLabel").text, "Connecting…")
        }

        // The ring holds its slot in the row even while hidden, so the label
        // cannot shift sideways the moment a scan starts.
        function test_wifiScanRingDoesNotMoveTheLabel() {
            var svc = makeNetworkService()
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "network", payload: { networkService: svc }
            })
            var ring = findByName(item, "wifiScanRing")
            var label = findByName(item, "wifiRescanLabel")
            var beforeX = label.x
            var beforeY = label.y

            svc.scanningActive = true
            wait(50)
            compare(label.x, beforeX, "label shifted horizontally when the ring appeared")
            compare(label.y, beforeY, "label shifted vertically when the ring appeared")
            verify(ring.width > 0 && ring.height > 0, "ring reserves a slot")
        }

        // A Bluetooth scan with nothing found yet must not claim "no devices
        // found" — that is a claim about a search that has not finished.
        function test_bluetoothScanRingReplacesTheEmptyClaim() {
            var svc = makeBluetoothService()
            svc.devices = { values: [] }
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "bluetooth", payload: { bluetoothService: svc }
            })
            var ring = findByName(item, "btScanRing")
            var label = findByName(item, "btEmptyText")
            verify(ring !== null && label !== null, "bluetooth empty state should exist")
            compare(ring.active, false, "ring is idle when no scan is running")
            compare(label.text, "No devices found")

            svc.scanningActive = true
            wait(50)
            compare(ring.visible, true, "ring shows while discovering")
            compare(label.text, "Scanning…",
                "a live scan must not read as an exhausted search")
        }
    }
}
