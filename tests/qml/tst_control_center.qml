import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/ControlCenterLogic.js" as CcLogic
import "../../modules/bar/widgets/ClockCalendar.js" as Calendar

// Headless coverage for the control center's two reusable primitives: the sharp
// card frame and the local month calendar. Both must load, lay out, answer input
// and render every declared state under a plain Item root - no PanelWindow, no
// Quickshell singleton, no compositor.
//
// The calendar is asserted against `ClockCalendar.js` directly rather than
// against numbers copied out of the component, so the assertion proves the
// component delegates its date math to the bar module instead of forking it.
Item {
    id: root
    width: 1024
    height: 768

    // Card and calendar are built through Components so each test owns a fresh
    // instance with its own state, the same way the page will build them.
    Component {
        id: cardComponent
        Lazer.ControlCenterCard {}
    }

    Component {
        id: calendarComponent
        Lazer.ControlCenterCalendar {}
    }

    Component {
        id: notificationsComponent
        Lazer.ControlCenterNotifications {}
    }

    Component {
        id: pageComponent
        Lazer.ControlCenter {}
    }

    // The two same-surface detail pages, built through Components exactly as the
    // overview is, so each test owns a fresh instance with its own state.
    Component {
        id: networkPageComponent
        Lazer.ControlCenterNetwork {}
    }

    Component {
        id: bluetoothPageComponent
        Lazer.ControlCenterBluetooth {}
    }

    // --- Injected service fakes ---
    //
    // Each fake declares ONLY the properties and functions the page is
    // documented to read, so a binding that reaches for anything else resolves
    // to undefined here exactly as an absent service would in production. Call
    // counters prove the page called the service rather than shadowing it.

    Component {
        id: fakeNetworkComponent
        QtObject {
            property bool wifiConnected: true
            property bool wifiEnabled: true
            // The real NetworkService exposes NO flat activeSsid: it keeps a scan
            // map keyed by SSID whose entries carry ssid and connected. This fake
            // has that shape and no flat property, so a page that reached for
            // `activeSsid` would read undefined here exactly as it does in
            // production.
            property var networks: ({
                "Home": { ssid: "Home", security: "WPA2", signal: 78,
                    connected: true, existing: true }
            })
            property bool ethernetConnected: false
            property string activeEthernetConnection: ""
            property bool scanningActive: false
            property bool connecting: false
            property string connectingTo: ""
            property string lastError: ""

            // Replace the scan map wholesale, which is how the real service
            // invalidates its own bindings after a status change.
            function setWifiMap(entries) {
                var map = ({})
                for (var i = 0; i < entries.length; i++)
                    map[entries[i].ssid] = entries[i]
                networks = map
            }
        }
    }

    Component {
        id: fakeBluetoothComponent
        QtObject {
            property bool bluetoothAvailable: true
            property bool enabled: true
            property bool blocked: false
            property bool scanningActive: false
            property var devices: [{ name: "Speaker" }]
            property var connectedDevices: []
            property int scanCalls: 0

            function startScan() { scanCalls++ }
        }
    }

    // A network service with neither the scan map nor the flat name, so the page's
    // derivation has to cope with a service that offers nothing to derive from.
    Component {
        id: fakeHistoryOnlyNetworkComponent
        QtObject {
            property bool wifiConnected: false
            property bool wifiEnabled: true
            property bool ethernetConnected: false
            property bool scanningActive: false
            property bool connecting: false
            property string lastError: ""
        }
    }

    // The network service contract a detail page is documented to read: the
    // scan map, the interaction flags, the error pair, and every action method.
    // Call arguments are recorded, not just counts, so "the page asked for this
    // SSID" and "the page passed a password" are both observable.
    Component {
        id: fakeNetworkDetailComponent
        QtObject {
            property bool wifiConnected: true
            property bool wifiEnabled: true
            property var networks: ({
                "Home": { ssid: "Home", security: "WPA2", signal: 78,
                    connected: true, existing: true },
                "Neighbour 5G": { ssid: "Neighbour 5G", security: "WPA2",
                    signal: 55, connected: false, existing: false }
            })
            property bool ethernetAvailable: false
            property bool ethernetConnected: false
            property string activeEthernetIf: ""
            property string activeEthernetConnection: ""
            property var wiredGroups: []
            property var linkDetails: ({ device: "", type: "", connection: "",
                ip4: "", gateway: "", dns: [] })
            property bool scanningActive: false
            property bool connecting: false
            property string connectingTo: ""
            property string disconnectingFrom: ""
            property string lastError: ""
            property string lastErrorSsid: ""
            // Recorded calls. `passwordRequired` decides what needsPasswordFor()
            // answers, and `credentialFailure` decides isCredentialFailure(), so
            // one fake covers every branch without a second shape.
            property var calls: []
            property var passwordRequiredFor: "Neighbour 5G"
            property bool credentialFailure: false

            function record(name) {
                var args = Array.prototype.slice.call(arguments, 1)
                calls.push({ name: name, args: args })
            }
            function callCount(name) {
                var total = 0
                for (var i = 0; i < calls.length; i++)
                    if (calls[i].name === name)
                        total++
                return total
            }
            // The FIRST call's argument at `index`. Deliberately not "the last":
            // the newest call is what a reader expects, but a second call to the
            // same method would then silently satisfy the assertion written for
            // the first one.
            function callArgs(name, index) {
                for (var i = 0; i < calls.length; i++)
                    if (calls[i].name === name)
                        return index === undefined ? calls[i].args : calls[i].args[index]
                return undefined
            }

            // The NEWEST call to one method, by index. Needed wherever a method is
            // legitimately called twice and the second call is the one under
            // test - a toggle pressed on and off again.
            function lastCallArgs(name, index) {
                for (var i = calls.length - 1; i >= 0; i--)
                    if (calls[i].name === name)
                        return calls[i].args[index]
                return undefined
            }

            function setWifiMap(entries) {
                var map = ({})
                for (var i = 0; i < entries.length; i++)
                    map[entries[i].ssid] = entries[i]
                networks = map
            }
            function setWifiEnabled(enabled) {
                wifiEnabled = enabled
                record("setWifiEnabled", enabled)
            }
            // `refreshCalls` counts the OPEN refresh on its own, so "the page asked
            // once when it mounted" is not inferred from the shape of a recorded
            // argument list, and a refresh the overview's deferred path made can be
            // told apart from one the detail page made.
            property int refreshCalls: 0
            function refreshForOpen() { refreshCalls++; record("refreshForOpen") }
            function requestScan(rescan, clearError) { record("requestScan", rescan, clearError) }
            function connect(ssid, password, isHidden, securityKey) {
                connecting = true
                connectingTo = ssid
                record("connect", ssid, password, isHidden, securityKey)
            }
            function disconnect(ssid) { record("disconnect", ssid) }
            function forget(ssid) { record("forget", ssid) }
            function needsPasswordFor(ssid) { return ssid === passwordRequiredFor }
            function isCredentialFailure(message) {
                return credentialFailure && String(message || "").indexOf("password") >= 0
            }
            function isSecured(security) {
                var word = String(security || "")
                return word !== "" && word !== "--"
            }
        }
    }

    // A network fake that reports nothing at all: no scan map, no flags, no
    // methods. The detail page must render an unavailable state rather than
    // throw when the service is thinner than documented.
    Component {
        id: fakeBareNetworkComponent
        QtObject {
            property bool wifiConnected: false
            property bool wifiEnabled: false
        }
    }

    // The Bluetooth service contract a detail page is documented to read.
    // `devices` is shaped as the real one hands over - a list object with
    // `.values` - so the page's own read path is exercised, not a plain array
    // that would quietly accept an adapter-shaped binding forever.
    Component {
        id: fakeBluetoothDetailComponent
        QtObject {
            property bool bluetoothAvailable: true
            property bool enabled: true
            property bool blocked: false
            property bool scanningActive: false
            property var devices: null
            property var connectedDevices: []
            property var calls: []

            function deviceList(values) {
                var list = ({ values: values })
                devices = list
                connectedDevices = []
                for (var i = 0; i < values.length; i++) {
                    if (values[i].connected)
                        connectedDevices.push(values[i])
                }
            }
            function record(name) {
                var args = Array.prototype.slice.call(arguments, 1)
                calls.push({ name: name, args: args })
            }
            function callCount(name) {
                var total = 0
                for (var i = 0; i < calls.length; i++)
                    if (calls[i].name === name)
                        total++
                return total
            }
            function callArg(name, index) {
                for (var i = 0; i < calls.length; i++)
                    if (calls[i].name === name)
                        return calls[i].args[index]
                return undefined
            }

            function setBluetoothEnabled(state) {
                enabled = state
                record("setBluetoothEnabled", state)
            }
            function startScan() { scanningActive = true; record("startScan") }
            function pairDevice(device) { record("pairDevice", device) }
            function connectDeviceWithTrust(device) { record("connectDeviceWithTrust", device) }
            function disconnectDevice(device) { record("disconnectDevice", device) }
            function forgetDevice(device) { record("forgetDevice", device) }
            function canPair(device) {
                return !device.connected && !device.paired && !device.trusted
            }
            function canConnect(device) {
                return !device.connected && (device.paired || device.trusted)
            }
            function canDisconnect(device) { return device.connected === true }
            function isDeviceBusy(device) { return device.pairing === true }
            function getDeviceIcon(device) {
                return String(device.name || "").indexOf("Speaker") >= 0
                    ? "audio-card" : "bluetooth"
            }
            function getSignalPercent(device) {
                return device.signalStrength == null ? null : device.signalStrength
            }
            function deviceKey(device) {
                return device.address || device.name || device.path || ""
            }
        }
    }

    // A Bluetooth fake with no adapter at all, which is the real
    // `bluetoothAvailable: false` production state.
    Component {
        id: fakeNoAdapterComponent
        QtObject {
            property bool bluetoothAvailable: false
            property bool enabled: false
            property bool blocked: false
            property bool scanningActive: false
            property var devices: null
            property var connectedDevices: []
        }
    }

    // The brief's shape verbatim, plus call counters so the assertion can tell
    // "the page called the setter" from "the page wrote its own copy".
    Component {
        id: fakeVolumeComponent
        QtObject {
            property real sinkVolume: 0.42
            property bool sinkMuted: false
            property int setCalls: 0
            property int muteCalls: 0

            function setSinkVolume(value) {
                sinkVolume = value
                setCalls++
            }

            function toggleSinkMute() {
                sinkMuted = !sinkMuted
                muteCalls++
            }
        }
    }

    Component {
        id: fakeMediaComponent
        QtObject {
            property bool hasPlayer: true
            property string title: "Blue Bird"
            property string artist: "IOSYS"
            property bool playing: true
            property string playbackState: "playing"
            property bool canGoPrevious: true
            property bool canTogglePlayback: true
            property bool canGoNext: true
            property int previousCalls: 0
            property int playPauseCalls: 0
            property int nextCalls: 0

            function previous() { previousCalls++ }
            function playPause() { playPauseCalls++ }
            function next() { nextCalls++ }
        }
    }

    Component {
        id: fakeBatteryComponent
        QtObject {
            property bool available: true
            property bool ready: true
            property int percentage: 87
            property bool charging: false
            property bool pluggedIn: false
            property string iconText: "BAT"
        }
    }

    // A real ListModel, because the production read path goes through
    // historyList.count and historyList.get(i); a plain array would not exercise
    // the same binding invalidation.
    Component {
        id: fakeNotificationComponent
        QtObject {
            property int unreadCount: 0
            property int markAllCalls: 0
            property int markReadCalls: 0
            property var historyList: ListModel {}

            function latestNotification() {
                return historyList.count > 0 ? historyList.get(0) : null
            }

            function markAllRead() { markAllCalls++ }
            function markRead(notifId) { markReadCalls++ }
        }
    }

    // A notification service that exposes only the history list: no
    // latestNotification() helper at all, so the summary's fallback read path
    // is the only one that can work.
    Component {
        id: fakeHistoryOnlyNotificationComponent
        QtObject {
            property int unreadCount: 0
            property var historyList: null
        }
    }

    // A history list that COUNTS its own reads. The cap on the RENDERED summary is
    // provable from the entries, but the cap on the WALK is not: a summary that
    // read all 120 history rows and then threw 118 of them away renders exactly
    // the same two entries. This makes the walk itself observable.
    //
    // `noLatest` selects the shape: the production service has a
    // latestNotification() helper and this one deliberately does not, so the
    // bounded walk is the only read path and its cost is fully attributable.
    //
    // The counter lives in a plain JS object rather than in a QML property, and
    // that is load-bearing: the summary's adapter reads get() from inside a
    // binding, so a get() that assigned a QML property emitted a notify while the
    // binding that called it was still evaluating, and Qt answered with "Binding
    // loop detected for property rawEntries". Mutating a plain object notifies
    // nobody, the binding stays clean, and the count is still exact. The real
    // `ListModel.get()` has always been pure, which is why production never saw it.
    Component {
        id: countingHistoryComponent
        QtObject {
            // Not a QML property: nothing may notify from inside get().
            readonly property var reads: ({ count: 0 })
            property var rows: []
            property bool noLatest: false
            readonly property int count: rows.length

            function readCount() { return reads.count }

            function get(index) {
                reads.count++
                return rows[index] != null ? rows[index] : null
            }

            function latestNotification() {
                return noLatest ? null : countingHead.value
            }
        }
    }

    // The head entry a counting fake's latestNotification() hands back, so one
    // component serves both read shapes.
    QtObject {
        id: countingHead
        property var value: null
    }

    // The notification service that owns a counting history: unread count plus the
    // helper, so the summary's two read paths are both exercised.
    Component {
        id: fakeCountingNotificationComponent
        QtObject {
            property int unreadCount: 0
            property var historyList: null
            property int markAllCalls: 0

            function latestNotification() { return countingHead.value }
            function markAllRead() { markAllCalls++ }
        }
    }

    Component {
        id: fakeWeatherComponent
        QtObject {
            property real temperature: 18.5
            property string condition: "partly-cloudy"
            property string location: "Shanghai"
            property double updatedAt: 0
            property bool isStale: false
            property bool available: true
            property bool loading: false
            property string lastError: ""
        }
    }

    // Activation is observed from outside the card so the assertion reads the
    // emitted signal rather than an internal flag.
    QtObject {
        id: activationProbe
        property int count: 0
    }

    // Every component a test builds is parented to one per-test host. A failed
    // assertion abandons the test function before its own destroy() line, and an
    // abandoned card would keep answering the NEXT test's clicks - which then
    // fails for a reason that has nothing to do with it. init() creates the host
    // and cleanup() destroys it, so nothing can outlive its test and no
    // destroy() ever runs twice.
    Component {
        id: hostComponent
        Item {
            width: root.width
            height: root.height
            // Fakes are parented here too, so a failed assertion cannot leave a
            // fake behind holding state the next test would read as its own.
            property var fakes: []
        }
    }

    property Item testHost: null

    TestCase {
        name: "ControlCenter"

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            activationProbe.count = 0
            // The counting fake's head entry is a root-level object so the
            // component can be declared once for both read shapes; reset per test
            // so a stale head cannot leak into the next one's count.
            countingHead.value = null
            root.testHost = hostComponent.createObject(root)
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
            if (root.testHost) {
                root.testHost.destroy()
                root.testHost = null
            }
        }

        function makeCard(properties) {
            var args = { x: 0, y: 0, width: 320, height: 64 }
            for (var key in properties)
                args[key] = properties[key]
            return cardComponent.createObject(root.testHost, args)
        }

        // The calendar needs a settled layout before a synthetic click means
        // anything: its step buttons live inside a Column, so their positions are
        // assigned during polish, and mouseClick maps coordinates through the
        // scene graph rather than through the item's own x/y.
        function makeCalendar(properties) {
            var args = { x: 0, y: 0, width: 260 }
            for (var key in properties)
                args[key] = properties[key]
            return calendarComponent.createObject(root.testHost, args)
        }

        // --- Overview harness helpers ---

        // The page owns no timer, but its clock is injectable, so a fixed date
        // makes every header string deterministic.
        function makePage(properties) {
            var args = {
                x: 0, y: 0,
                width: 1024, height: 720,
                now: new Date(2026, 9, 12, 9, 41)
            }
            for (var key in properties)
                args[key] = properties[key]
            var page = pageComponent.createObject(root.testHost, args)
            if (page.now === undefined || page.now === null)
                page.now = new Date(2026, 9, 12, 9, 41)
            return page
        }

        // A page with NO injected clock, which is the production state: its header
        // follows the wall clock the page's own tick advances. makePage freezes the
        // clock for every other test, so the live path needs its own builder - a
        // `now: null` argument would not do, because assigning null to a date
        // property still replaces the binding with an invalid date.
        function makeLiveClockPage(properties) {
            var args = { x: 0, y: 0, width: 1024, height: 720 }
            for (var key in properties)
                args[key] = properties[key]
            return pageComponent.createObject(root.testHost, args)
        }

        function makeFake(component, properties) {
            var args = {}
            for (var key in (properties || {}))
                args[key] = properties[key]
            var fake = component.createObject(root.testHost, args)
            registerFake(fake)
            return fake
        }

        // A detail page with its own injected service, sized like the route
        // viewport the host would give it. Separate builders from makePage
        // because these are sub-pages, not the route page: they are mounted
        // INSIDE the overview rather than by the wave host's Loader.
        function makeNetworkPage(properties) {
            var args = { x: 0, y: 0, width: 1024, height: 720 }
            for (var key in (properties || {}))
                args[key] = properties[key]
            return networkPageComponent.createObject(root.testHost, args)
        }

        function makeBluetoothPage(properties) {
            var args = { x: 0, y: 0, width: 1024, height: 720 }
            for (var key in (properties || {}))
                args[key] = properties[key]
            return bluetoothPageComponent.createObject(root.testHost, args)
        }

        // Seed the network detail fake's scan map, in the real service's shape.
        function seededNetworkDetail(fake, entries) {
            var list = []
            for (var i = 0; i < entries.length; i++) {
                list.push({
                    ssid: entries[i].ssid,
                    security: entries[i].security == null ? "WPA2" : entries[i].security,
                    signal: entries[i].signal == null ? 70 : entries[i].signal,
                    connected: entries[i].connected === true,
                    existing: entries[i].existing !== false
                })
            }
            fake.setWifiMap(list)
            return fake
        }

        // Seed the Bluetooth fake with plain device records. Passed as an
        // argument rather than as a createObject property because a list object
        // has to be REPLACED to invalidate a binding, and a literal would be
        // copied element-wise - the same trap the volume sink hits.
        function seededBluetooth(fake, devices) {
            fake.deviceList(devices)
            return fake
        }

        // A row by its stable key, addressed through the PAGE's own accessor rather
        // than by sweeping a list's `children`.
        //
        // The sweep cannot work here, and the reason is worth stating: the list
        // is a Flickable, and a Flickable re-parents its declarative children
        // into its own contentItem - so the row Column is not a child of the
        // list at all, and a walk of `list.children` finds no rows. The page
        // resolving its own rows is also the contract its activation path uses,
        // so a test and a tap always act on the same record.
        function wifiRow(page, ssid) { return page.wifiRowItem(ssid) }

        function bluetoothRow(page, key) { return page.deviceRowItem(key) }

        // Every row of a page's list, in order, ignoring the Repeater's
        // role-less placeholder. Reads the page's own row seam rather than the
        // list's children, for the re-parenting reason above.
        function wifiRows(page) {
            var kept = []
            // contentItem -> the row Column -> the delegates: two hops, because
            // the Flickable owns the first re-parenting and the Column owns the
            // Repeater's.
            var all = page.listItem.contentItem.children
            for (var i = 0; i < all.length; i++) {
                var kids = all[i].children
                for (var j = 0; j < kids.length; j++) {
                    if (kids[j].rowKey !== undefined)
                        kept.push(kids[j])
                }
            }
            return kept
        }

        // Every row in a list, in order, ignoring the Repeater's placeholder.
        function rowsOf(list) {
            var kept = []
            if (!list)
                return kept
            var kids = list.children
            for (var i = 0; i < kids.length; i++) {
                if (kids[i].rowKey !== undefined)
                    kept.push(kids[i])
            }
            return kept
        }

        // Fakes live in the per-test host's own list, so destroying the host
        // takes them with it.
        function registerFake(fake) {
            if (fake)
                root.testHost.fakes.push(fake)
            return fake
        }

        // A network fake carrying a scan map, in the real service's shape: one
        // connected entry plus any number of visible-but-not-connected ones.
        // Written through the fake's own setWifiMap so the map is replaced
        // wholesale, exactly as NetworkService invalidates its own bindings.
        function seededNetwork(fake, entries) {
            var list = []
            for (var i = 0; i < entries.length; i++) {
                list.push({
                    ssid: entries[i].ssid,
                    security: entries[i].security || "WPA2",
                    signal: entries[i].signal == null ? 70 : entries[i].signal,
                    connected: entries[i].connected === true,
                    existing: true
                })
            }
            fake.setWifiMap(list)
            return fake
        }

        // Newest first, which is the order NotificationService keeps: it inserts
        // every arriving notification at index 0, so historyList.get(0) is the
        // latest and the summary must read from the head.
        function seedNotifications(fake, count) {
            for (var i = 1; i <= count; i++) {
                fake.historyList.insert(0, {
                    notifId: "n" + i,
                    appName: "App " + i,
                    summary: "Message " + i,
                    body: "Body " + i,
                    icon: "",
                    timestamp: 1000 + i,
                    read: i % 2 === 0
                })
            }
            fake.unreadCount = count
            return fake
        }

        // Every visual descendant, including Repeater delegates. A Repeater
        // leaves one role-less placeholder among its children, and it measures
        // zero, so the geometry assertions simply see a zero-width box.
        function descendants(item, out) {
            out = out || []
            var kids = item.children
            for (var i = 0; i < kids.length; i++) {
                out.push(kids[i])
                descendants(kids[i], out)
            }
            return out
        }

        // Any scroll container the page put on screen. The narrow layout must
        // not scroll sideways, so the assertion is that this stays empty.
        function scrollContainers(item, out) {
            out = out || []
            var kids = item.children
            for (var i = 0; i < kids.length; i++) {
                var child = kids[i]
                if (child.contentWidth !== undefined && child.contentHeight !== undefined
                        && child.flickableDirection !== undefined)
                    out.push(child)
                scrollContainers(child, out)
            }
            return out
        }

        function calendarSettled(calendar) {
            return calendar.previousButtonItem.x > 0 && calendar.nextButtonItem.x > 0
                    && calendar.monthLabelItem.width > 0 && calendar.gridItem.height > 0
        }

        // Do two items share any vertical strip, measured in one shared space?
        // The overlap test is the point, so it asks the question about boxes rather
        // than about a pair of y values: "header bottom <= section top" and "these
        // two rects intersect" are the same fact, and only one of them is what a
        // reader of the layout actually cares about.
        function overlapsVertically(first, second, space) {
            var firstTop = first.mapToItem(space, 0, 0).y
            var firstBottom = first.mapToItem(space, 0, first.height).y
            var secondTop = second.mapToItem(space, 0, 0).y
            var secondBottom = second.mapToItem(space, 0, second.height).y
            return firstTop < secondBottom - 0.5 && secondTop < firstBottom - 0.5
        }

        // An item's bottom edge in a shared space, which is what "must start below
        // the one above it" is really asking about.
        function bottomIn(item, space) {
            return item.mapToItem(space, 0, item.height).y
        }

        function topIn(item, space) {
            return item.mapToItem(space, 0, 0).y
        }

        // A Repeater leaves one role-less placeholder among its children, so
        // every sweep here filters on a declared delegate property instead of
        // counting children.
        function delegates(calendar, propertyName) {
            var kept = []
            var kids = calendar.gridItem.children
            for (var i = 0; i < kids.length; i++) {
                if (kids[i][propertyName] !== undefined)
                    kept.push(kids[i])
            }
            return kept
        }

        function delegatesWhere(calendar, propertyName, value) {
            var kept = []
            var all = delegates(calendar, propertyName)
            for (var i = 0; i < all.length; i++) {
                if (all[i][propertyName] === value)
                    kept.push(all[i])
            }
            return kept
        }

        // An item's x/y are relative to its own parent, so "inside the card" has
        // to be asked in the card's coordinate space instead of mixing the two.
        function leftEdgeIn(card, item) {
            return item.mapToItem(card, 0, 0).x
        }

        function boxInsideCard(card, item) {
            var topLeft = item.mapToItem(card, 0, 0)
            var bottomRight = item.mapToItem(card, item.width, item.height)
            return topLeft.x >= -0.5 && topLeft.y >= -0.5
                    && bottomRight.x <= card.width + 0.5
                    && bottomRight.y <= card.height + 0.5
        }

        function test_cardStatesRemainPaintable() {
            var card = makeCard({
                title: "Network", summary: "Unavailable", status: "unavailable",
                available: false
            })
            verify(card.visible)
            compare(card.status, "unavailable")
            card.destroy()
        }

        function test_calendarMonthNavigation() {
            var calendar = makeCalendar({ viewYear: 2026, viewMonth: 11 })
            calendar.stepMonth(1)
            compare(calendar.viewYear, 2027)
            compare(calendar.viewMonth, 0)
            calendar.destroy()
        }

        function test_aCardPaintsASquareMajorSurface() {
            var card = makeCard({ title: "Network", summary: "Home", icon: CcLogic.iconFor("network") })
            verify(card.surfaceItem.visible)
            verify(card.surfaceItem.width > 0)
            verify(card.surfaceItem.height > 0)
            // Sharp language: a card is a major surface, so it is not rounded.
            compare(card.surfaceItem.radius, 0)
            compare(card.surfaceItem.color, Lazer.LazerTheme.settingsCard)
            card.destroy()
        }

        function test_everyNonReadyStateShowsACompactLabel() {
            var states = ["loading", "unavailable", "empty", "error"]
            for (var i = 0; i < states.length; i++) {
                var card = makeCard({
                    title: "Network", summary: "placeholder",
                    status: states[i], available: true, error: "adapter missing"
                })
                verify(card.stateLabel.length > 0, states[i] + " must carry a compact label")
                verify(card.stateBadgeItem.visible, states[i] + " label must be visible")
                compare(card.stateLabelItem.text, card.stateLabel)
                // A state label replaces the card's own status word, it does not
                // stack a second line under it.
                verify(card.stateLabel.length < 24, states[i] + " label must stay compact")
                card.destroy()
            }
        }

        function test_aReadyCardShowsNoStateLabel() {
            var card = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })
            compare(card.stateLabel, "")
            verify(!card.stateBadgeItem.visible)
            card.destroy()
        }

        // A state arriving is a fade, not a reflow: the badge's strip is reserved
        // for its widest word at all times, so the title's box cannot move with
        // state and no label can be measured into the badge.
        function test_aStateChangeFadesTheBadgeWithoutMovingTheTitle() {
            var card = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })
            tryVerify(function() { return card.titleItem.width > 0 }, 800)
            var readyWidth = card.titleItem.width
            var reserved = card.reservedBadgeWidth
            verify(reserved > 0, "the badge strip is reserved even when ready")
            verify(!card.stateBadgeItem.visible)

            card.status = "loading"
            // The animation starts from zero, so a hard cut would read 1 here.
            compare(card.stateBadgeItem.opacity, 0)
            compare(card.titleItem.width, readyWidth, "a state change must not reflow the title")
            compare(card.reservedBadgeWidth, reserved)
            tryVerify(function() { return card.stateBadgeItem.visible }, 800)
            tryVerify(function() { return card.stateBadgeItem.opacity > 0.99 }, 800)
            compare(card.titleItem.width, readyWidth)

            card.status = "ready"
            tryVerify(function() { return !card.stateBadgeItem.visible }, 800)
            compare(card.titleItem.width, readyWidth)
            card.destroy()
        }

        function test_anErrorCardShowsTheServiceWordsWithoutAModal() {
            var errorCard = makeCard({
                title: "Network", summary: "NetworkManager is not responding",
                status: "error", available: true,
                error: "NetworkManager is not responding"
            })
            var readyCard = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })

            // The service's own failure words are the status line, kept verbatim
            // for a detail page to read.
            compare(errorCard.summaryItem.text, errorCard.error)
            verify(errorCard.summaryItem.visible)

            // An error is a label, not a surface: the card's declared children
            // are identical to a ready card's, so nothing popped up on top.
            compare(errorCard.children.length, readyCard.children.length)
            compare(errorCard.stateBarItem.color, Lazer.LazerTheme.settingsWarning)

            errorCard.destroy()
            readyCard.destroy()
        }

        function test_cardLabelsStayInsideTheCardBounds() {
            var longText = "a summary long enough to need eliding on a deliberately narrow card"
            // The tightest case the card can be handed: a long title AND an icon
            // AND the widest state badge, all inside a card narrower than the sum
            // of what they would like. Every one of the three has to give.
            var card = makeCard({
                width: 180, height: 64, title: "Network adapter with a long name",
                summary: longText, icon: CcLogic.iconFor("network"),
                status: "unavailable", available: true
            })
            tryVerify(function() { return card.titleItem.width > 0 }, 800)

            verify(boxInsideCard(card, card.titleItem), "the title must stay inside the card")
            verify(boxInsideCard(card, card.summaryItem), "the summary must stay inside the card")
            verify(boxInsideCard(card, card.stateBadgeItem), "the state badge must stay inside the card")
            verify(boxInsideCard(card, card.iconItem), "the icon must stay inside the card")
            verify(card.titleItem.elide !== Text.ElideNone, "the title must elide")
            verify(card.summaryItem.elide !== Text.ElideNone, "the summary must elide")
            // The badge keeps its own width; the text column takes what is left,
            // so the two never claim the same strip of the title row. Read as two
            // real boxes, because a reservation that under-measures the painted
            // word lets the title reach into the badge while both still report
            // themselves in bounds.
            var titleRight = card.titleItem.mapToItem(card, card.titleItem.width, 0).x
            verify(titleRight <= card.stateBadgeItem.mapToItem(card, 0, 0).x + 0.5,
                "the title and the badge cannot both claim the same strip")
            // ...and the fixture is actually tight, so the assertion above is not
            // passing by accident. implicitWidth is the title's natural width:
            // a Text reports contentWidth AFTER eliding, so the elision itself
            // cannot be read back off contentWidth.
            verify(card.titleItem.implicitWidth > card.titleItem.width,
                "the long title must be elided, not silently shrunk")
            card.destroy()
        }

        // The badge paints uppercase, so the strip it reserves has to be measured
        // on the uppercase word. Reserving the mixed-case label under-reserves the
        // strip by roughly the cap height, which is exactly enough for the title
        // to reach past it on a narrow card.
        function test_theBadgeStripReservesThePaintedUppercaseLabel() {
            var states = ["loading", "unavailable", "empty", "error"]
            for (var i = 0; i < states.length; i++) {
                var card = makeCard({
                    title: "Network", status: states[i], available: true
                })
                compare(card.stateLabelItem.text, card.stateLabel.toUpperCase(),
                    states[i] + " paints an uppercase label")
                var painted = card.stateBarItem.width + card.badgeGap
                        + card.stateLabelItem.width
                verify(painted <= card.reservedBadgeWidth + 0.5,
                    states[i] + " badge must fit inside its reserved strip")
                card.destroy()
            }

            // And the reservation is the widest of all of them, not the current
            // one: the label can change without the strip moving.
            var widestCard = makeCard({ title: "Network", status: "unavailable", available: true })
            var reserved = widestCard.reservedBadgeWidth
            compare(widestCard.widestStateLabel, "UNAVAILABLE",
                "the widest painted label is UNAVAILABLE")
            compare(widestCard.stateLabel, "UNAVAILABLE")
            widestCard.status = "empty"
            compare(widestCard.reservedBadgeWidth, reserved,
                "a state change must not reflow the strip")
            verify(widestCard.stateLabelItem.width
                    <= widestCard.reservedBadgeWidth - widestCard.badgeBarWidth
                    - widestCard.badgeGap + 0.5)
            widestCard.destroy()
        }

        function test_cardActivationEmitsAndFlashes() {
            var card = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })
            card.activated.connect(function() { activationProbe.count++ })
            tryVerify(function() { return card.surfaceItem.width > 0 }, 800)

            mouseClick(card, card.width / 2, card.height / 2)
            tryCompare(activationProbe, "count", 1, 500)

            // The click flash is the shared recipe, not a second one.
            verify(card.flashActive)
            compare(card.flashOverlayItem.enabled, false)
            compare(card.flashAnimationItem.property, "opacity")
            compare(card.flashAnimationItem.from, Lazer.MotionTokens.clickFlashOpacity)
            compare(card.flashAnimationItem.to, 0)
            compare(card.flashAnimationItem.duration, Lazer.MotionTokens.clickFlashDuration)
            compare(card.flashAnimationItem.easing.type, Lazer.MotionTokens.clickFlashEasing)

            // Reduced motion lands on the final state instead of playing it.
            card.flashAnimationItem.stop()
            card.flashOverlayItem.opacity = 0
            Lazer.MotionTokens.reducedMotionOverride = true
            mouseClick(card, card.width / 2, card.height / 2)
            tryCompare(activationProbe, "count", 2, 500)
            verify(!card.flashActive)
            compare(card.flashOverlayItem.opacity, 0)
            Lazer.MotionTokens.reducedMotionOverride = false
            card.destroy()
        }

        // One non-ready state at a time, each on a card whose service EXISTS, so
        // every assertion below is about readiness and not about availability.
        function expectNonReadyAvailableCardToBeInert(status) {
            var card = makeCard({
                title: "Network", summary: "Not connected",
                icon: CcLogic.iconFor("network"),
                status: status, available: true, error: "adapter missing"
            })
            card.activated.connect(function() { activationProbe.count++ })
            tryVerify(function() { return card.surfaceItem.width > 0 }, 800)

            // Paintable, and at full contrast: dimming is for a service that is
            // not there, not for a card whose label is the thing to read.
            verify(card.visible, status + " must stay visible")
            compare(card.opacity, 1, status + " must stay readable")
            verify(card.stateLabel.length > 0, status + " must keep its compact label")

            compare(card.interactive, false, status + " must not accept input")
            compare(card.activeFocusOnTab, false, status + " must not take focus")
            // ...and a host that forces focus onto it anyway still gets no ring:
            // the ring belongs to a card that accepts input, not to one that
            // merely happens to hold focus.
            card.forceActiveFocus()
            verify(!card.ringVisible, status + " must not draw a ring when focused")

            // Hover: a synthetic move over the card changes nothing.
            mouseMove(card, card.width / 2, card.height / 2)
            verify(!card.hoverHighlighted, status + " must not highlight on hover")
            compare(card.surfaceItem.color, Lazer.LazerTheme.settingsCard,
                status + " must not swap to the hover surface")
            compare(card.highlightItem.border.width, 0, status + " must not draw a ring")
            compare(card.highlightItem.enabled, false, "the ring layer never takes input")

            // Click: no activation request, and none of the shared click feedback.
            mouseClick(card, card.width / 2, card.height / 2)
            compare(activationProbe.count, 0, status + " must not activate")
            verify(!card.flashActive, status + " must not flash")
            compare(card.flashOverlayItem.opacity, 0, status + " must not wash")

            // The programmatic path is the same gate as the pointer path.
            card.activate()
            compare(activationProbe.count, 0, status + " must ignore a direct activate()")
            card.destroy()
        }

        // Availability is not readiness. A loading, empty or failed card is a
        // report, not a target, so it stays on screen and stays legible while
        // accepting nothing - and ControlCenterLogic agrees, since actionFor()
        // answers "none" for every non-ready status.
        function test_aNonReadyButAvailableCardStaysPaintableYetInert() {
            var states = ["loading", "unavailable", "empty", "error"]
            for (var i = 0; i < states.length; i++)
                expectNonReadyAvailableCardToBeInert(states[i])
        }

        // The control half of the hover assertions above: the same synthetic move
        // over a ready card DOES light up. Without this, "no hover on an inert
        // card" would also pass if the harness could not drive hover at all.
        function test_theSameHoverStillReachesAReadyCard() {
            var card = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })
            tryVerify(function() { return card.surfaceItem.width > 0 }, 800)
            mouseMove(card, card.width / 2, card.height / 2)
            tryVerify(function() { return card.hoverHighlighted }, 500)
            tryCompare(card.surfaceItem, "color", Lazer.LazerTheme.settingsCardHover, 500)
            // Read through JS, not through tryCompare("border.width"): the Qt 6.11
            // test helpers cannot resolve a grouped property path, so that form
            // fails on a value that is already correct.
            tryVerify(function() { return card.highlightItem.border.width === 1.5 }, 500)
            card.destroy()
        }

        function test_anUnavailableCardStaysVisibleButInert() {
            var card = makeCard({
                title: "Network", summary: "Unavailable",
                status: "unavailable", available: false
            })
            card.activated.connect(function() { activationProbe.count++ })
            verify(card.visible)
            compare(card.interactive, false)
            compare(card.activeFocusOnTab, false)
            tryVerify(function() { return card.surfaceItem.width > 0 }, 800)

            mouseClick(card, card.width / 2, card.height / 2)
            compare(activationProbe.count, 0, "an unavailable card must not activate")

            // It dims through the shared disabled token rather than vanishing or
            // hard-cutting, so the transition is observable.
            tryCompare(card, "opacity", Lazer.LazerTheme.settingsDisabledAlpha, 800)
            verify(card.visible)
            card.destroy()
        }

        function test_aReadyCardKeepsFullOpacity() {
            var card = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })
            compare(card.opacity, 1)
            verify(card.interactive)
            compare(card.activeFocusOnTab, true)
            card.destroy()
        }

        function test_cardIconResolvesTheLogicIconPaths() {
            for (var i = 0; i < CcLogic.cardKinds.length; i++) {
                var kind = CcLogic.cardKinds[i]
                var iconPath = CcLogic.iconFor(kind)
                verify(iconPath.length > 0, kind + " must name an icon")
                var card = makeCard({
                    title: CcLogic.cardTitles[kind], summary: "ready", icon: iconPath
                })
                verify(card.iconItem.visible, kind + " icon must be shown")
                // The path is relative to the card's own directory, so this is
                // the check that a wrong base directory cannot ship: a broken
                // path reports Image.Error rather than a silently blank icon.
                tryCompare(card.iconItem, "status", Image.Ready, 2000)
                compare(String(card.iconItem.source), iconPath)
                card.destroy()
            }
        }

        function test_theTextColumnFollowsTheIconSlot() {
            var withIcon = makeCard({ title: "Network", summary: "Home", icon: CcLogic.iconFor("network") })
            var withoutIcon = makeCard({ title: "Media", summary: "No media", icon: "" })
            verify(withIcon.iconItem.visible)
            verify(!withoutIcon.iconItem.visible)
            tryVerify(function() { return withIcon.titleItem.width > 0 }, 800)

            // Without an icon the text column starts at the surface padding
            // instead of beside a reserved hole, and the two cases are pinned
            // to the shared padding and icon metrics.
            compare(leftEdgeIn(withoutIcon, withoutIcon.titleItem), 12)
            compare(leftEdgeIn(withIcon, withIcon.titleItem), 12 + withIcon.iconSize + withIcon.iconGap)
            withIcon.destroy()
            withoutIcon.destroy()
        }

        // Pagination is asserted through the buttons a user actually presses, not
        // by calling stepMonth(): the arithmetic was already covered above, so what
        // is under test here is the wiring from a click to that arithmetic.
        function test_theStepButtonsPageTheMonthOnAClick() {
            var calendar = makeCalendar({ viewYear: 2026, viewMonth: 11 })
            tryVerify(function() { return calendarSettled(calendar) }, 1000)

            mouseClick(calendar.nextButtonItem, calendar.nextButtonItem.width / 2,
                       calendar.nextButtonItem.height / 2)
            tryCompare(calendar, "viewYear", 2027, 800)
            tryCompare(calendar, "viewMonth", 0, 800)
            // The header followed, and so did the grid's own set of dates.
            compare(calendar.monthLabelText, Calendar.monthLabel(2027, 0))
            tryVerify(function() {
                return delegatesWhere(calendar, "inMonth", true).length
                        === Calendar.daysInMonth(2027, 0)
            }, 800)

            // Back again, so a click is a page rather than a one-way latch.
            mouseClick(calendar.previousButtonItem, calendar.previousButtonItem.width / 2,
                       calendar.previousButtonItem.height / 2)
            tryCompare(calendar, "viewYear", 2026, 800)
            tryCompare(calendar, "viewMonth", 11, 800)
            compare(calendar.monthLabelText, Calendar.monthLabel(2026, 11))
            tryVerify(function() {
                return delegatesWhere(calendar, "inMonth", true).length
                        === Calendar.daysInMonth(2026, 11)
            }, 800)
            calendar.destroy()
        }

        // The keyboard half: Return and Space on a focused step button are the
        // actions the component declares, and an unhandled key must do nothing.
        function test_theStepButtonsPageTheMonthOnTheKeyboard() {
            var calendar = makeCalendar({ viewYear: 2026, viewMonth: 11 })
            tryVerify(function() { return calendarSettled(calendar) }, 1000)

            // Focused the way Tab would, since tab order is the host's business.
            calendar.nextButtonItem.forceActiveFocus()
            verify(calendar.nextButtonItem.activeFocus)
            keyPress(Qt.Key_Return)
            keyRelease(Qt.Key_Return)
            tryCompare(calendar, "viewYear", 2027, 800)
            tryCompare(calendar, "viewMonth", 0, 800)

            keyPress(Qt.Key_Space)
            keyRelease(Qt.Key_Space)
            tryCompare(calendar, "viewMonth", 1, 800)

            calendar.previousButtonItem.forceActiveFocus()
            verify(calendar.previousButtonItem.activeFocus)
            keyPress(Qt.Key_Return)
            keyRelease(Qt.Key_Return)
            tryCompare(calendar, "viewMonth", 0, 800)

            // The handler is a whitelist of activation keys, not "any key".
            keyPress(Qt.Key_Left)
            keyRelease(Qt.Key_Left)
            compare(calendar.viewMonth, 0, "an unrelated key must not page the calendar")
            compare(calendar.viewYear, 2027)
            calendar.destroy()
        }

        function test_calendarGridIsFixedAtSixRowsForEveryMonth() {
            var february = makeCalendar({ viewYear: 2026, viewMonth: 1 })
            compare(february.rowCount, 6)
            compare(february.columnCount, 7)
            compare(february.cellCount, 42)
            compare(delegates(february, "dayOffset").length, 42)
            compare(delegatesWhere(february, "inMonth", true).length, Calendar.daysInMonth(2026, 1))
            // A fixed grid means a fixed footprint: width and height follow the
            // implicit sizes, so the panel hosting it cannot resize as the user
            // pages. (Asserted here because it is the component's own default,
            // not something a test can force by assigning.)
            compare(february.height, february.implicitHeight)
            compare(february.width, february.implicitWidth)

            // A 31-day month must occupy the same six rows and the same height.
            february.stepMonth(1)
            compare(february.viewMonth, 2)
            compare(delegatesWhere(february, "inMonth", true).length, Calendar.daysInMonth(2026, 2))

            var january = makeCalendar({ viewYear: 2026, viewMonth: 0 })
            compare(delegatesWhere(january, "inMonth", true).length, Calendar.daysInMonth(2026, 0))
            compare(january.implicitHeight, february.implicitHeight,
                "a fixed six-row grid must not change the calendar's height")
            january.destroy()
            february.destroy()
        }

        function test_calendarSteppingWrapsBothWays() {
            var calendar = makeCalendar({ viewYear: 2026, viewMonth: 0 })
            calendar.stepMonth(-1)
            compare(calendar.viewYear, 2025)
            compare(calendar.viewMonth, 11)
            calendar.stepMonth(2)
            compare(calendar.viewYear, 2026)
            compare(calendar.viewMonth, 1)
            // The label is the bar module's own wording, not a second formatter.
            compare(calendar.monthLabelText, Calendar.monthLabel(2026, 1))
            calendar.destroy()
        }

        function test_calendarUsesTheSundayFirstWeekdayConvention() {
            var calendar = makeCalendar({ viewYear: 2026, viewMonth: 11 })
            compare(calendar.weekdayLabels.length, 7)
            compare(calendar.weekdayLabels[0], "\u65E5")
            compare(calendar.weekdayLabels[6], "\u516D")

            // December 2026 starts on a Tuesday, so a Sunday-first strip puts the
            // 1st in the third column.
            compare(Calendar.firstWeekday(2026, 11), 2)
            var inMonth = delegatesWhere(calendar, "inMonth", true)
            compare(inMonth.length, Calendar.daysInMonth(2026, 11))
            var firstCell = inMonth[0]
            compare(firstCell.dayOffset, 1)
            compare(firstCell.cellIndex, Calendar.firstWeekday(2026, 11))
            // The two cells before it belong to November, and stay unpainted.
            compare(delegates(calendar, "dayOffset")[0].cellIndex, 0)
            compare(delegates(calendar, "dayOffset")[1].cellIndex, 1)
            calendar.destroy()
        }

        function test_calendarHighlightsExactlyTheTodayCell() {
            var calendar = makeCalendar({
                today: new Date(2026, 10, 12), viewYear: 2026, viewMonth: 10
            })
            var todayCells = delegatesWhere(calendar, "isToday", true)
            compare(todayCells.length, 1)
            compare(todayCells[0].dayOffset, 12)
            compare(todayCells[0].color, Lazer.LazerTheme.activeFill)
            verify(todayCells[0].border.width > 0)

            // Stepping away from the current month drops the highlight, and
            // stepping back restores the same cell.
            calendar.stepMonth(1)
            compare(delegatesWhere(calendar, "isToday", true).length, 0)
            calendar.stepMonth(-1)
            var restored = delegatesWhere(calendar, "isToday", true)
            compare(restored.length, 1)
            compare(restored[0].dayOffset, 12)
            calendar.destroy()
        }

        function test_calendarResetViewReturnsToToday() {
            var calendar = makeCalendar({
                today: new Date(2026, 0, 5), viewYear: 2030, viewMonth: 7
            })
            compare(calendar.viewingCurrentMonth, false)
            compare(calendar.monthLabelItem.color, Lazer.LazerTheme.settingsAccent)

            calendar.stepMonth(1)
            calendar.resetView()
            compare(calendar.viewYear, 2026)
            compare(calendar.viewMonth, 0)
            compare(calendar.viewingCurrentMonth, true)
            // The accent handoff is a real transition, so it lands a frame later.
            tryCompare(calendar.monthLabelItem, "color", Lazer.LazerTheme.textPrimary, 800)
            calendar.destroy()
        }

        function readRepoFile(relativePath) {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", Qt.resolvedUrl("../../" + relativePath), false)
            xhr.send(null)
            return { status: xhr.status, text: xhr.responseText }
        }

        // One named QML block, by brace counting from the line that declares its
        // id to the line that closes it. A regex cannot do this: the block nests
        // Items and Rectangles, so "\n    }" lands on an inner close and the
        // slice runs on into the rest of the file - which is how a battery block
        // "with no handlers" ends up reporting the weather block's HoverHandler.
        function blockNamed(text, idName) {
            var lines = text.split("\n")
            var start = -1
            var indent = 0
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].match(new RegExp("^\\s*id:\\s*" + idName + "\\s*$"))) {
                    start = i
                    indent = lines[i].match(/^\s*/)[0].length
                    break
                }
            }
            if (start < 0)
                return ""
            var depth = 0
            var opened = false
            for (var j = start; j < lines.length; j++) {
                var stripped = lines[j].replace(/"[^"]*"/g, '""')
                for (var k = 0; k < stripped.length; k++) {
                    if (stripped[k] === "{") {
                        depth++
                        opened = true
                    } else if (stripped[k] === "}") {
                        depth--
                    }
                }
                if (opened && depth === 0)
                    return lines.slice(start, j + 1).join("\n")
            }
            return ""
        }

        // A file's code with its // and /* */ comments removed, for source assertions
        // that must survive documentation. Both pages say out loud that they do
        // not shell out to anything, and a check over the raw text would flag
        // the very sentence documenting the rule it enforces.
        function stripComments(text) {
            return String(text)
                .replace(/\/\*[\s\S]*?\*\//g, " ")
                .replace(/\/\/[^\n]*/g, " ")
        }

        // The month grid must render the bar module's math, not a second copy of
        // it. No runtime assertion can see a forked helper - a private
        // daysInMonth() would satisfy every behavioural check above while
        // drifting the moment the bar module changes - so the source is read
        // directly. Needs QML_XHR_ALLOW_FILE_READ=1, which scripts/qmltest.sh
        // sets.
        function test_theCalendarRendersTheBarDateMathInsteadOfForkingIt() {
            var file = readRepoFile("modules/lazerbar/ControlCenterCalendar.qml")
            compare(file.status, 200, "the calendar source must be readable")
            verify(file.text.indexOf("ClockCalendar.js") >= 0,
                "the calendar must import the shared date module")

            var forked = file.text.match(/function\s+(daysInMonth|firstWeekday|cellDayOffset|cellInMonth|isTodayCell|monthLabel)\s*\(/)
            compare(forked, null, "the calendar must not redeclare " + (forked ? forked[1] : ""))

            // stepMonth is the component's own stepping API, so it exists - but its
            // first statement has to hand the arithmetic to the shared module,
            // which is what rules out a local reimplementation that happens to
            // agree on the months a test happens to visit.
            var forward = file.text.match(/function\s+stepMonth\s*\([^)]*\)\s*\{\s*([^\n]*)/)
            verify(forward !== null, "stepMonth must be declared")
            verify(forward[1].indexOf("Calendar.stepMonth") >= 0,
                "stepMonth must delegate to Calendar.stepMonth")
        }

        function test_calendarStepButtonsAreSquareGeometricArrows() {
            var calendar = makeCalendar({})
            tryVerify(function() { return calendar.previousButtonItem.width > 0 }, 800)

            compare(calendar.previousButtonItem.width, calendar.previousButtonItem.height)
            compare(calendar.nextButtonItem.width, calendar.nextButtonItem.height)
            compare(calendar.previousButtonItem.radius, 0)
            compare(calendar.nextButtonItem.radius, 0)
            verify(calendar.previousButtonItem.activeFocusOnTab)
            verify(calendar.nextButtonItem.activeFocusOnTab)

            verify(String(calendar.previousButtonItem.glyphItem.source).indexOf("chevron-left.svg") >= 0)
            verify(String(calendar.nextButtonItem.glyphItem.source).indexOf("chevron-right.svg") >= 0)
            tryCompare(calendar.previousButtonItem.glyphItem, "status", Image.Ready, 2000)
            tryCompare(calendar.nextButtonItem.glyphItem, "status", Image.Ready, 2000)
            calendar.destroy()
        }

        // --- Bounded notification summary ---

        function makeNotifications(properties) {
            var args = { x: 0, y: 0, width: 320 }
            for (var key in (properties || {}))
                args[key] = properties[key]
            return notificationsComponent.createObject(root.testHost, args)
        }

        function test_theNotificationSummaryIsCappedAtTwoEntries() {
            var service = seedNotifications(makeFake(fakeNotificationComponent), 5)
            var summary = makeNotifications({ notificationService: service })
            tryCompare(summary, "entryCount", 2, 1000)
            // Two, because maxEntries is the module's fixed cap - a five-entry
            // history must not make the panel taller or the summary longer.
            compare(summary.maxEntries, 2)
            compare(summary.maxEntries, CcLogic.notificationEntryCap)
            // The unread count is reported whole and separately, so capping the
            // entries never hides how many are waiting.
            compare(summary.unreadCount, 5)
            compare(summary.entries[0].notifId, "n5")
            compare(summary.entries[1].notifId, "n4")
        }

        // The walk is bounded, not just the result. A summary that read a 120-entry
        // history and then dropped 118 entries would render identically to one
        // that read two, so the cap on the RESULT proves nothing about the cap on
        // the WORK: this fake counts its own get() calls and the bound is asserted
        // on that count.
        function test_theSummaryWalksNoMoreOfTheHistoryThanItRenders() {
            var rows = []
            for (var i = 0; i < 120; i++)
                rows.push({ notifId: "n" + i, appName: "App", summary: "Message " + i })

            var counted = makeFake(countingHistoryComponent, { rows: rows, noLatest: true })
            var countedService = makeFake(fakeCountingNotificationComponent, {
                historyList: counted, unreadCount: 120
            })
            var summary = makeNotifications({ notificationService: countedService })
            tryCompare(summary, "entryCount", 2, 1000)
            // latestNotification() is absent here, so every read came from the
            // bounded walk: exactly one read per rendered entry, and no more.
            compare(counted.readCount(), 2,
                "a 120-entry history must be read no further than the cap, read "
                    + counted.readCount() + " rows")

            // And with latestNotification() present the walk is at most the cap
            // MINUS the entry that helper already supplied.
            var bothRows = []
            for (var j = 0; j < 120; j++)
                bothRows.push({ notifId: "m" + j, appName: "App", summary: "S" + j })
            countingHead.value = bothRows[0]
            var bothCounted = makeFake(countingHistoryComponent, { rows: bothRows })
            var bothService = makeFake(fakeCountingNotificationComponent, {
                historyList: bothCounted, unreadCount: 120
            })
            var withLatest = makeNotifications({ notificationService: bothService })
            tryCompare(withLatest, "entryCount", 2, 1000)
            // Exactly two: index 0 (which is the head the helper already supplied,
            // so it has to be read to know it is a duplicate and skipped) and
            // index 1 (which is kept). A walk that does not stop at the cap would
            // read 120.
            compare(bothCounted.readCount(), 2,
                "the helper supplies one entry, so the walk reads the duplicate and "
                    + "one more (read " + bothCounted.readCount() + ")")
        }

        function test_theNotificationSummaryHeightIsBoundedByTheCapNotTheContent() {
            var empty = makeNotifications({})
            var two = makeNotifications({ notificationService: seedNotifications(
                makeFake(fakeNotificationComponent), 2) })
            var many = makeNotifications({ notificationService: seedNotifications(
                makeFake(fakeNotificationComponent), 9) })
            tryCompare(two, "entryCount", 2, 1000)
            tryCompare(many, "entryCount", 2, 1000)
            compare(two.implicitHeight, many.implicitHeight,
                "nine notifications must not make the panel taller than two")
            compare(empty.implicitHeight, many.implicitHeight,
                "an empty history must not collapse the panel either")
        }

        // A bounded height is not the same as a height that FITS. Reserving one row
        // instead of `maxEntries` rows leaves the summary's own box correct while
        // the second entry paints straight over the "view all" row and off the
        // bottom of the component - the kind of defect a cap assertion cannot see,
        // because both summaries in that test are the same height either way.
        function test_twoEntriesStayAboveTheViewAllRowAndInsideTheSummary() {
            var service = seedNotifications(makeFake(fakeNotificationComponent), 3)
            var summary = makeNotifications({ notificationService: service })
            tryCompare(summary, "entryCount", 2, 1000)
            compare(summary.entryCap, 2, "the band is sized from the cap")

            var first = summary.entryItem(0)
            var second = summary.entryItem(1)
            verify(first !== null && second !== null,
                "both capped entries must be on screen, found "
                    + (first === null ? "no first row" : "") + (second === null ? "no second row" : ""))
            // A Column assigns its children's positions during layout, so the rows'
            // geometry needs a real settle before it means anything.
            tryVerify(function() { return second.height > 0 && second.width > 0 }, 1000)
            compare(summary.entryItem(2), null, "the band is never over-filled")

            // The band is the cap's worth of rows plus the gaps between them, which
            // is the geometry the footer has to be placed against.
            compare(summary.entryBandHeight, 2 * summary.entryHeight + summary.rowGap)
            compare(summary.entryColumnItem.height, summary.entryBandHeight)

            var secondBottom = bottomIn(second, summary)
            var viewAllTop = topIn(summary.viewAllItem, summary)
            verify(secondBottom <= viewAllTop + 0.5,
                "the second row must end above \"view all\" (row bottom "
                    + secondBottom.toFixed(1) + ", view-all top " + viewAllTop.toFixed(1) + ")")
            verify(topIn(second, summary) >= bottomIn(first, summary) - 0.5,
                "the rows are stacked, not painted on top of each other")

            // ...and everything stays inside the component's own box.
            verify(viewAllTop + summary.viewAllItem.height
                    <= summary.implicitHeight + 0.5,
                "the action row must fit inside the summary (bottom "
                    + (viewAllTop + summary.viewAllItem.height).toFixed(1)
                    + ", height " + summary.implicitHeight.toFixed(1) + ")")
            verify(secondBottom <= summary.implicitHeight + 0.5)
            verify(summary.viewAllItem.height === summary.footerHeight)

            // A third entry changes nothing about the band, so the layout this
            // measurement describes is the layout a busy history gets too.
            var busy = makeNotifications({ notificationService: seedNotifications(
                makeFake(fakeNotificationComponent), 9) })
            tryCompare(busy, "entryCount", 2, 1000)
            tryVerify(function() { return busy.entryItem(1).height > 0 }, 1000)
            compare(busy.entryBandHeight, summary.entryBandHeight)
            compare(busy.implicitHeight, summary.implicitHeight)
            verify(bottomIn(busy.entryItem(1), busy) <= topIn(busy.viewAllItem, busy) + 0.5,
                "a nine-entry history overlaps its own action row")
        }

        // The summary reads a bounded prefix of the history through the
        // historyList loop, deduplicating the overlap between the two. No
        // unbounded walk of the history is allowed.
        function test_theSummaryPrefersTheLatestEntryAndDeduplicatesTheHistory() {
            var service = seedNotifications(makeFake(fakeNotificationComponent), 3)
            var summary = makeNotifications({ notificationService: service })
            tryCompare(summary, "entryCount", 2, 1000)
            compare(summary.entries.length, 2)
            var ids = []
            for (var i = 0; i < summary.entries.length; i++)
                ids.push(String(summary.entries[i].notifId))
            compare(ids.join(","), "n3,n2",
                "latestNotification() is historyList.get(0), so it must not double up")

            // A service with no latestNotification() at all still renders its
            // bounded history slice through the same cap.
            var noLatest = seedNotifications(makeFake(fakeNotificationComponent), 4)
            var bareService = makeFake(fakeHistoryOnlyNotificationComponent, {
                historyList: noLatest.historyList, unreadCount: noLatest.unreadCount
            })
            var bare = makeNotifications({ notificationService: bareService })
            tryCompare(bare, "entryCount", 2, 1000)
            compare(bare.entries[0].notifId, "n4")
            compare(bare.unreadCount, 4)
        }

        // Opening the summary is a request for the full view; it is emphatically
        // not a decision to clear the user's unread notifications.
        function test_openingTheSummaryNeverMarksAnythingRead() {
            var service = seedNotifications(makeFake(fakeNotificationComponent), 3)
            var summary = makeNotifications({ notificationService: service })
            var requests = 0
            summary.openRequested.connect(function() { requests++ })
            tryVerify(function() { return summary.viewAllItem.width > 0 }, 1000)

            compare(service.markAllCalls, 0, "construction must not touch read state")
            mouseClick(summary.viewAllItem, summary.viewAllItem.width / 2,
                       summary.viewAllItem.height / 2)
            tryVerify(function() { return requests === 1 }, 800)
            compare(service.markAllCalls, 0, "opening must not call markAllRead()")
            compare(service.markReadCalls, 0, "opening must not call markRead()")
            compare(service.unreadCount, 3, "the unread count is unchanged by opening")
        }

        function test_anEmptyHistoryOffersNoViewAllAction() {
            var service = makeFake(fakeNotificationComponent)
            var summary = makeNotifications({ notificationService: service })
            tryVerify(function() { return summary.entryCount === 0 }, 1000)
            compare(summary.viewAllEnabled, false,
                "nothing to view means nothing to activate")
            var requests = 0
            summary.openRequested.connect(function() { requests++ })
            summary.viewAllItem.activate()
            compare(requests, 0)
            compare(summary.entries.length, 0)
        }

        // --- Overview: scope ---

        function test_theOverviewHasExactlyTheFourCoreControlCards() {
            var page = makePage({ networkService: makeFake(fakeNetworkComponent) })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            compare(page.controlCardCount, 4)
            compare(page.controlCardKinds.join(","), CcLogic.cardKinds.join(","))

            // Stated as an exact set: the four cards are the module's four, with
            // the module's own titles and icons. There is no fifth control and
            // no brightness / DND / power card anywhere in the column.
            var titles = []
            var icons = []
            for (var i = 0; i < page.controlCards.length; i++) {
                titles.push(page.controlCards[i].title)
                icons.push(page.controlCards[i].icon)
            }
            compare(titles.join(","), "Network,Bluetooth,Volume,Media")
            compare(icons.join(","), CcLogic.cardIcons.network + ","
                    + CcLogic.cardIcons.bluetooth + ","
                    + CcLogic.cardIcons.volume + ","
                    + CcLogic.cardIcons.media)
            for (var j = 0; j < icons.length; j++)
                verify(icons[j].indexOf("brightness") < 0,
                    "no brightness asset may reach a control card")
        }

        // Battery is a read-only header state, not a control. The page publishes
        // no battery card, and the header block declares no input handler at
        // all - asserted on the source, because "there is no click" cannot be
        // observed by clicking.
        function test_batteryIsHeaderStateAndNotAFifthControlCard() {
            var page = makePage({ batteryService: makeFake(fakeBatteryComponent) })
            tryVerify(function() { return page.batteryStateItem.width > 0 }, 1000)
            compare(page.controlCardCount, 4, "battery must not join the control column")
            compare(page.batteryCard, null, "there is no battery card")
            compare(page.controlCardKinds.indexOf("battery"), -1)
            verify(page.batteryStateItem.visible)
            compare(page.batteryTextItem.text, "87%",
                "the header reads the service's own percentage")
            compare(page.batteryStateItem.activeFocusOnTab, false,
                "read-only state does not take focus")

            var file = readRepoFile("modules/lazerbar/ControlCenter.qml")
            compare(file.status, 200, "the overview source must be readable")
            var block = blockNamed(file.text, "batteryState")
            verify(block !== "", "the battery header must be a named block")
            var handlers = block.match(/TapHandler|MouseArea|HoverHandler|DragHandler|Flickable/)
            compare(handlers, null,
                "the battery header declares no input handler (found "
                    + (handlers ? handlers[0] : "") + ")")
        }

        function test_batteryRendersEveryStateWithoutBlocking() {
            var states = [
                { available: false, ready: false, percentage: 0, iconText: "" },
                { available: true, ready: false, percentage: 0, iconText: "?" },
                { available: true, ready: true, percentage: 87, iconText: "BAT" },
                { available: true, ready: true, percentage: 12, iconText: "CHG",
                  charging: true, pluggedIn: true },
                { available: true, ready: true, percentage: 8, iconText: "AC",
                  pluggedIn: true }
            ]
            for (var i = 0; i < states.length; i++) {
                var page = makePage({ batteryService: makeFake(fakeBatteryComponent, states[i]) })
                tryVerify(function() { return page.batteryStateItem.width > 0 }, 1000)
                verify(page.batteryTextItem.text.length > 0,
                    "battery state " + i + " must render a readable value")
                verify(page.batteryStateItem.visible)
                compare(page.controlCardCount, 4)
            }
        }

        // --- Overview: card actions ---

        function test_networkAndBluetoothCardsRequestTheirDetailPages() {
            var networkRequests = 0
            var bluetoothRequests = 0
            var page = makePage({
                networkService: makeFake(fakeNetworkComponent),
                bluetoothService: makeFake(fakeBluetoothComponent)
            })
            page.networkDetailsRequested.connect(function() { networkRequests++ })
            page.bluetoothDetailsRequested.connect(function() { bluetoothRequests++ })
            tryVerify(function() { return page.networkCard.width > 0 }, 1000)

            // The programmatic path first, because that is what the host will
            // use; then a real click, because that is what the user does.
            page.networkCard.activate()
            tryVerify(function() { return networkRequests === 1 }, 800)
            page.bluetoothCard.activate()
            tryVerify(function() { return bluetoothRequests === 1 }, 800)

            // ...and the request is gated on the module's action, not merely on the
            // card having been clicked. openNetworkDetails() is a public function a
            // host could call directly, and a card with no action must answer no.
            page.openNetworkDetails()
            page.openBluetoothDetails()
            tryVerify(function() {
                return networkRequests === 2 && bluetoothRequests === 2
            }, 300)
            compare(networkRequests, 2, "a host may call the request directly on a ready card")
            compare(bluetoothRequests, 2)

            // Back to the overview before clicking: a card under a mounted
            // detail page is not what the user is looking at, so a synthetic
            // click there would prove nothing about the card.
            compare(page.handleBack(), true)
            tryVerify(function() { return page.activeSubPage === "" }, 1000)

            mouseClick(page.networkCard, page.networkCard.width / 2, page.networkCard.height / 2)
            tryVerify(function() { return networkRequests === 3 }, 800)
            compare(page.handleBack(), true)
            tryVerify(function() { return page.activeSubPage === "" }, 1000)
            mouseClick(page.bluetoothCard, page.bluetoothCard.width / 2,
                       page.bluetoothCard.height / 2)
            tryVerify(function() { return bluetoothRequests === 3 }, 800)

            // The control half: a card whose service failed is inert, so it
            // neither flashes nor requests a detail page.
            var failing = makeFake(fakeNetworkComponent, {
                lastError: "NetworkManager is not responding" })
            var inert = makePage({ networkService: failing })
            var inertRequests = 0
            inert.networkDetailsRequested.connect(function() { inertRequests++ })
            tryVerify(function() { return inert.networkCard.width > 0 }, 1000)
            mouseClick(inert.networkCard, inert.networkCard.width / 2,
                       inert.networkCard.height / 2)
            compare(inertRequests, 0, "a failed adapter has no detail page to open")
            verify(!inert.networkCard.flashActive,
                "a card with no action must not play the click flash either")

            // ...and the direct call is gated too, which is the half a click cannot
            // reach: an inert card's TapHandler never fires, so only calling the
            // function outright could emit here.
            inert.openNetworkDetails()
            compare(inertRequests, 0,
                "the request must follow the module's action, not just the click")
        }

        function test_volumeControlsCallTheInjectedService() {
            var volume = makeFake(fakeVolumeComponent)
            var page = makePage({ volumeService: volume })
            tryVerify(function() { return page.volumeSliderItem.width > 0 }, 1000)

            // The slider is bound to the service in both directions.
            compare(page.volumeSliderItem.value, volume.sinkVolume)
            compare(page.volumeSliderItem.from, 0)
            compare(page.volumeSliderItem.to, 1)

            page.volumeSliderItem.setValue(0.8)
            tryCompare(volume, "setCalls", 1, 800)
            compare(volume.sinkVolume, 0.8, "the service owns the value")

            // The page's own guard on the value it sends: setVolume() is public and
            // a host (or a slider whose from/to were retuned) could hand it
            // anything, so an out-of-range request is clamped rather than passed
            // straight to PipeWire. The slider itself already normalises, which is
            // exactly why this needs its own test - the slider agreeing is not the
            // page agreeing.
            page.setVolume(2.5)
            tryCompare(volume, "setCalls", 2, 800)
            compare(volume.sinkVolume, 1, "a value above the range clamps to its top")
            page.setVolume(-1)
            tryCompare(volume, "setCalls", 3, 800)
            compare(volume.sinkVolume, 0, "a value below the range clamps to its bottom")
            page.setVolume(Number.NaN)
            tryCompare(volume, "setCalls", 4, 800)
            compare(volume.sinkVolume, 0, "an unusable value clamps rather than reaching the service")

            // The mute button is the second action on the same card.
            compare(volume.sinkMuted, false)
            mouseClick(page.muteButtonItem, page.muteButtonItem.width / 2,
                       page.muteButtonItem.height / 2)
            tryCompare(volume, "muteCalls", 1, 800)
            compare(volume.sinkMuted, true)
            // ...and the card's own summary follows the service, so the two reads
            // can never disagree.
            tryCompare(page.volumeCard, "summary", "Muted", 800)

            // Mute again through the button, and once through the card body. The
            // explicit wait between them matters: a mute button tap claims itself
            // until the next event-loop turn, and tryCompare on an
            // already-satisfied value returns without spinning the loop - so the
            // card's own activation immediately after would still be inside the
            // claim window.
            page.muteButtonItem.activate()
            tryCompare(volume, "muteCalls", 2, 800)
            wait(50)
            page.volumeCard.activate()
            tryCompare(volume, "muteCalls", 3, 800)
        }

        // A track tap or scrub is the slider's, not the card's. Qt delivers the
        // deepest handler first and still delivers to the ancestor, so the card
        // has to be told which control took the tap - otherwise dragging the
        // volume would also toggle mute.
        function test_aSliderTapDoesNotAlsoToggleTheCard() {
            var volume = makeFake(fakeVolumeComponent)
            var page = makePage({ volumeService: volume })
            tryVerify(function() { return page.volumeSliderItem.width > 0 }, 1000)

            mouseClick(page.volumeSliderItem, page.volumeSliderItem.width * 0.75,
                       page.volumeSliderItem.height / 2)
            tryVerify(function() { return volume.setCalls >= 1 }, 800)
            compare(volume.muteCalls, 0,
                "a tap on the slider must not reach the card's mute action (setCalls="
                    + volume.setCalls + ", muteCalls=" + volume.muteCalls + ")")

            // The control half: the same click on the card's own dead space
            // still toggles, so the guard is not simply a disabled card. The
            // explicit wait matters: the tap claim is released on the next
            // event-loop turn, and a satisfied tryCompare returns without
            // spinning the loop.
            wait(50)
            page.volumeCard.activate()
            tryVerify(function() { return volume.muteCalls === 1 }, 800)
        }

        function test_mediaTransportCallsTheInjectedService() {
            var media = makeFake(fakeMediaComponent)
            var page = makePage({ mediaService: media })
            tryVerify(function() { return page.mediaPlayPauseButtonItem.width > 0 }, 1000)

            // The card's own line is the service's words, not a second formatter.
            compare(page.mediaCard.summary, "IOSYS — Blue Bird")
            verify(String(page.mediaPlayPauseButtonItem.glyphItem.source)
                .indexOf("pause.svg") >= 0, "a playing card shows the pause glyph")
            verify(String(page.mediaPreviousButtonItem.glyphItem.source)
                .indexOf("previous.svg") >= 0)
            verify(String(page.mediaNextButtonItem.glyphItem.source)
                .indexOf("next.svg") >= 0)

            page.mediaPreviousButtonItem.activate()
            tryCompare(media, "previousCalls", 1, 800)
            wait(50)
            page.mediaPlayPauseButtonItem.activate()
            tryCompare(media, "playPauseCalls", 1, 800)
            wait(50)
            page.mediaNextButtonItem.activate()
            tryCompare(media, "nextCalls", 1, 800)

            // Transport capability is the service's, not the page's: a player
            // that cannot go next has an inert button, and its programmatic
            // activation is ignored exactly like the pointer one.
            var bare = makeFake(fakeMediaComponent, {
                canGoPrevious: false, canTogglePlayback: false, canGoNext: false
            })
            var barePage = makePage({ mediaService: bare })
            tryVerify(function() { return barePage.mediaNextButtonItem.width > 0 }, 1000)
            compare(barePage.mediaPreviousButtonItem.enabled, false)
            compare(barePage.mediaPlayPauseButtonItem.enabled, false)
            compare(barePage.mediaNextButtonItem.enabled, false)
            compare(barePage.mediaPreviousButtonItem.activeFocusOnTab, false)
            barePage.mediaNextButtonItem.activate()
            compare(bare.nextCalls, 0, "a transport the player cannot do must stay inert")
            barePage.mediaCard.activate()
            compare(bare.playPauseCalls, 0,
                "the card body must not toggle playback the player cannot toggle")
        }

        // Same rule as the volume card: the card body is playback, the embedded
        // buttons are the specific transport, and one click does one thing.
        //
        // Driven by a real click on the button, not by calling activate(). Qt
        // delivers a tap to the deepest handler and then still delivers it to
        // every ancestor, so a real click is the only thing that exercises the
        // arbitration - the programmatic path never goes through the handlers at
        // all, and a test written that way passes whether the arbitration exists
        // or not.
        function test_aTransportClickDoesNotAlsoTogglePlaybackOnTheCard() {
            var media = makeFake(fakeMediaComponent)
            var page = makePage({ mediaService: media })
            tryVerify(function() { return page.mediaNextButtonItem.width > 0 }, 1000)
            var button = page.mediaNextButtonItem

            mouseClick(button, button.width / 2, button.height / 2)
            tryVerify(function() { return media.nextCalls >= 1 }, 800)
            compare(media.playPauseCalls, 0,
                "one click must not also toggle playback (nextCalls=" + media.nextCalls
                    + ", playPauseCalls=" + media.playPauseCalls + ")")

            // The control half: the card's own body still toggles, so the guard is
            // an arbitration and not a disabled card.
            wait(50)
            page.mediaCard.activate()
            tryCompare(media, "playPauseCalls", 1, 800)
        }

        // A play/pause is the one control on this page the user presses most, and
        // it is also the one that changes a glyph, a label and an enabled state. A
        // Repeater rebuilds every delegate when its MODEL changes, so a model that
        // carried those three words replaced all three buttons - and the keyboard
        // focus parked on one of them - on every single press. The buttons are
        // therefore identified by the model and nothing else, and identity plus
        // focus are what this asserts.
        function test_theTransportDelegatesSurviveAPlayStateChange() {
            var media = makeFake(fakeMediaComponent)
            var page = makePage({ mediaService: media })
            tryVerify(function() { return page.mediaPlayPauseButtonItem.width > 0 }, 1000)
            var before = [page.mediaPreviousButtonItem, page.mediaPlayPauseButtonItem,
                page.mediaNextButtonItem]
            for (var i = 0; i < before.length; i++)
                verify(before[i] !== null, "transport " + i + " must exist")

            var toggle = before[1]
            toggle.forceActiveFocus()
            tryVerify(function() { return toggle.activeFocus }, 800,
                "the toggle must be able to take focus at all")
            verify(String(toggle.glyphItem.source).indexOf("pause.svg") >= 0,
                "a playing track shows the pause glyph")
            compare(toggle.label, "Pause")

            media.playing = false

            // Wait on the NEW state rather than on the model having changed: a
            // settled check right after a swap reads the previous frame.
            tryVerify(function() {
                return page.mediaPlayPauseButtonItem.label === "Play"
            }, 1000, "the toggle must follow the player's own state")
            verify(String(page.mediaPlayPauseButtonItem.glyphItem.source)
                .indexOf("play.svg") >= 0, "a paused track shows the play glyph")

            // Same three objects, in the same order, with the focus they had.
            var after = [page.mediaPreviousButtonItem, page.mediaPlayPauseButtonItem,
                page.mediaNextButtonItem]
            for (var j = 0; j < after.length; j++)
                verify(after[j] === before[j],
                    "transport " + j + " was rebuilt by a play-state change")
            verify(toggle.activeFocus,
                "a play-state change must not take the keyboard focus away")

            // ...and back again, including the capability flip, which is the same
            // model the old shape rebuilt on.
            media.playing = true
            media.canTogglePlayback = false
            tryVerify(function() {
                return page.mediaPlayPauseButtonItem.enabled === false
            }, 1000, "the toggle must follow the player's own capability")
            compare(page.mediaPlayPauseButtonItem, toggle,
                "losing a capability must not rebuild the delegates either")
            compare(page.mediaPreviousButtonItem, before[0])
            compare(page.mediaNextButtonItem, before[2])
        }

        // --- Overview: unavailable / absent optional services ---

        function test_theOverviewRendersWithUnavailableServices() {
            var page = makePage({
                networkService: makeFake(fakeNetworkComponent, { wifiEnabled: false,
                    wifiConnected: false, networks: ({}) }),
                bluetoothService: makeFake(fakeBluetoothComponent, {
                    bluetoothAvailable: false, devices: null, connectedDevices: null }),
                volumeService: makeFake(fakeVolumeComponent, { sinkVolume: 0 }),
                mediaService: makeFake(fakeMediaComponent, { hasPlayer: false,
                    title: "", artist: "", playing: false }),
                batteryService: makeFake(fakeBatteryComponent, { available: false,
                    ready: false, percentage: 0, iconText: "" }),
                notificationService: seedNotifications(makeFake(fakeNotificationComponent), 0)
            })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)

            for (var i = 0; i < page.controlCards.length; i++) {
                var card = page.controlCards[i]
                verify(card.visible, "card " + i + " must stay painted")
                verify(card.summary.length > 0,
                    "card " + i + " must render a non-blocking status line")
            }
            compare(page.networkCard.status, "ready",
                "a disabled-but-present radio is a real state, not an empty list")
            compare(page.networkCard.summary, "Off")
            compare(page.bluetoothCard.status, "unavailable")
            compare(page.mediaCard.status, "empty")
            compare(page.mediaCard.summary, "No media")
            verify(page.batteryTextItem.text.length > 0)
        }

        // No service injected at all is the production state between this task
        // and the wiring task: the page must still mount and paint.
        function test_theOverviewRendersWithNoServiceInjectedAtAll() {
            var page = makePage({})
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            for (var i = 0; i < page.controlCards.length; i++) {
                var card = page.controlCards[i]
                compare(card.status, "unavailable", "card " + i + " reports an absent service")
                compare(card.available, false)
                verify(card.visible)
                verify(card.summary.length > 0)
                compare(card.interactive, false, "card " + i + " must accept nothing")
            }
            compare(page.entryCount, 0)
            verify(page.visible)
            verify(page.calendarItem.visible)
        }

        // A non-ready card stays inert, but it must stop announcing itself as a
        // button: a screen reader that is told "button" and then gets nothing is
        // worse than one told "Network, Not connected, Loading".
        function test_aNonReadyCardAnnouncesItsStateInsteadOfAPressedButton() {
            // A failed adapter is the non-ready case worth announcing: the card is
            // on screen, has no action, and its own words are the thing to read.
            var page = makePage({ networkService: makeFake(fakeNetworkComponent, {
                lastError: "NetworkManager is not responding" }) })
            // Both halves of the module's decision, pinned: the card frame's own
            // status, and the normalized action behind it.
            compare(page.networkCard.status, "error")
            compare(page.cardData("network").action, "none")
            var detailRequests = 0
            page.networkDetailsRequested.connect(function() { detailRequests++ })
            tryVerify(function() { return page.networkCard.width > 0 }, 1000)

            // Ready: a real target, announced as a button.
            var ready = makePage({ networkService: makeFake(fakeNetworkComponent) })
            tryVerify(function() { return ready.networkCard.width > 0 }, 1000)
            compare(ready.networkCard.Accessible.role, Accessible.Button)

            // Non-ready: same card, static text, and the state in the name.
            compare(page.networkCard.Accessible.role, Accessible.StaticText)
            verify(page.networkCard.Accessible.name.indexOf("Network") >= 0)
            verify(page.networkCard.Accessible.name.indexOf(page.networkCard.summary) >= 0,
                "the announcement must carry the status line the card shows")
            page.networkCard.activate()
            compare(detailRequests, 0, "inert stays inert - no activation was restored")
        }

        // The connected network's name has to come from the service's actual shape.
        // NetworkService exposes no flat `activeSsid`: the name lives on the
        // connected entry of its `networks` scan map. A page that read a flat
        // property instead got undefined and degraded every connected card to a
        // bare "Connected" - which looks like a working card, so nothing about the
        // card itself reports the mistake.
        function test_theConnectedNetworkNameIsReadFromTheServicesOwnScanMap() {
            var fake = seededNetwork(makeFake(fakeNetworkComponent), [
                { ssid: "Neighbour 5G", connected: false },
                { ssid: "Cafe Guest", connected: true },
                { ssid: "Attic", connected: false }
            ])
            var page = makePage({ networkService: fake })
            tryVerify(function() { return page.networkCard.width > 0 }, 1000)

            compare(fake.activeSsid, undefined,
                "the fake must not quietly grow the flat property the real service lacks")
            compare(page.connectedWifiSsid, "Cafe Guest")
            compare(page.networkSnapshot.activeSsid, "Cafe Guest")
            compare(page.networkCard.summary, "Cafe Guest",
                "the connected network's name, not a bare \"Connected\"")
            compare(page.networkCard.status, "ready")

            // Moving the connected mark has to follow, which is the half that only
            // works if the page reads the map and the service replaces it wholesale.
            seededNetwork(fake, [
                { ssid: "Cafe Guest", connected: false },
                { ssid: "Attic", connected: true }
            ])
            tryCompare(page.networkCard, "summary", "Attic", 1000)

            // No connected entry: the module's own fallback, unchanged.
            seededNetwork(fake, [{ ssid: "Cafe Guest", connected: false }])
            tryCompare(page.networkCard, "summary", "Connected", 1000)
            compare(page.connectedWifiSsid, "")

            // An entry whose ssid field is missing falls back to its map key, which
            // is the same string the map is keyed by.
            fake.networks = ({ Kettle: { connected: true } })
            tryCompare(page, "connectedWifiSsid", "Kettle", 1000)

            // Ethernet precedence is the module's, and it is untouched: a wired
            // link reads its own name, and the derived SSID never outranks it.
            var wired = makeFake(fakeNetworkComponent, {
                wifiConnected: false, ethernetConnected: true,
                activeEthernetConnection: "Wired link 1", networks: ({})
            })
            var wiredPage = makePage({ networkService: wired })
            tryVerify(function() { return wiredPage.networkCard.width > 0 }, 1000)
            compare(wiredPage.connectedWifiSsid, "")
            compare(wiredPage.networkCard.summary, "Wired link 1")

            // A service with neither shape still renders the module's ladder.
            var bare = makePage({ networkService: makeFake(fakeHistoryOnlyNetworkComponent) })
            tryVerify(function() { return bare.networkCard.width > 0 }, 1000)
            compare(bare.connectedWifiSsid, "")
            compare(bare.networkCard.summary, "Not connected")
        }

        // --- Overview: header ---

        function test_theHeaderReadsTheInjectedClockWeatherAndBattery() {
            var page = makePage({
                now: new Date(2026, 9, 12, 9, 41),
                weatherService: makeFake(fakeWeatherComponent),
                batteryService: makeFake(fakeBatteryComponent)
            })
            tryVerify(function() { return page.clockTextItem.width > 0 }, 1000)
            verify(page.clockTextItem.text.indexOf("09:41") >= 0,
                "the header clock must follow the injected date")
            compare(page.weatherState, "ready")
            // Rounded for a header: 18.5 shows as 19, not as a fake precision the
            // reading does not have.
            compare(page.weatherTextItem.text, "19°")
            verify(page.weatherConditionItem.text.length > 0)
            compare(page.batteryTextItem.text, "87%")
        }

        function test_everyWeatherStateRendersWithoutBlocking() {
            var states = [
                { available: true, loading: true },
                { available: false },
                { available: true, temperature: 18.5, isStale: true },
                { available: true, temperature: 18.5, lastError: "HTTP 503" },
                { available: true, temperature: Number.NaN },
                { available: true, temperature: 18.5 }
            ]
            var expected = ["loading", "unavailable", "stale", "stale", "empty", "ready"]
            for (var i = 0; i < states.length; i++) {
                var page = makePage({ weatherService: makeFake(fakeWeatherComponent, states[i]) })
                tryVerify(function() { return page.clockTextItem.width > 0 }, 1000)
                compare(page.weatherState, expected[i],
                    "weather state " + i + " must come from the logic module")
                verify(page.weatherTextItem.text.length > 0,
                    "weather state " + i + " must still render a value")
                verify(page.visible)
                compare(page.controlCardCount, 4)
            }

            // A stale reading still SHOWS its temperature, dimmed by the condition
            // word beside it. This is the state a failed refresh produces - the
            // service keeps the last reading and reports lastError - so dropping
            // the value would blank the header every time a request failed, which
            // is precisely what the module's "stale" state exists to prevent.
            var stale = makePage({ weatherService: makeFake(fakeWeatherComponent, {
                available: true, temperature: 18.5, isStale: true }) })
            tryVerify(function() { return stale.clockTextItem.width > 0 }, 1000)
            compare(stale.weatherState, "stale")
            compare(stale.weatherTextItem.text, "19°",
                "a stale reading keeps its value")
            compare(stale.weatherConditionItem.text, "partly-cloudy")
            verify(stale.weatherTextItem.color !== Lazer.LazerTheme.textMuted,
                "the value stays legible; the condition word carries the dimming")

            // And the states with no reading render a placeholder instead of
            // inventing one: an empty or absent service must not show a number.
            var absent = makePage({})
            tryVerify(function() { return absent.clockTextItem.width > 0 }, 1000)
            compare(absent.weatherState, "unavailable")
            compare(absent.weatherTextItem.text, "—")
            compare(absent.weatherConditionItem.text, "Unavailable")
        }

        // A page the shell retains keeps its header on screen for minutes at a time,
        // so a clock that only ever reads the moment of construction is a wrong
        // clock rather than an approximate one. This drives the real Timer, because
        // a test that called a hand-written tick function would pass even if nothing
        // in production ever called it.
        function test_theHeaderClockTicksWhileThePageIsRetained() {
            var before = new Date()
            var live = makeLiveClockPage({ clockTickInterval: 20 })
            tryVerify(function() { return live.clockTextItem.width > 0 }, 1000)
            compare(live.clockTickTimer.running, true,
                "the clock tick must run for a retained page")
            compare(live.clockTickTimer.interval, 20)

            // The production state: nothing injected, so the header follows the wall
            // clock and the tick is what moves it.
            var initial = live.liveClock.getTime()
            tryVerify(function() {
                return live.liveClock.getTime() !== initial
            }, 2000, "a live page's clock must advance on its own")
            verify(live.liveClock.getTime() >= before.getTime(),
                "the tick reads the wall clock, not a private counter")

            // ...and the header renders the value the tick wrote. Qt.formatDate is
            // used rather than a literal weekday, because the pattern is what the
            // header declares and the locale's word is not this test's business.
            tryVerify(function() {
                return live.clockTextItem.text === Qt.formatTime(live.now, "HH:mm")
                    && live.dateTextItem.text === Qt.formatDate(live.now, "yyyy-MM-dd dddd")
            }, 1000, "the header must render the moment the tick wrote")

            // The text itself has to move, not just the property behind it: the tick
            // period here is far shorter than a minute, so a real minute boundary may
            // or may not fall inside the test. Asserted instead that the label agrees
            // with `now` before and after the tick, which a frozen header could not
            // manage if it ever disagreed - and that `now` is what moved.
            var labelBefore = live.clockTextItem.text
            var stampBefore = live.now.getTime()
            tryVerify(function() { return live.now.getTime() !== stampBefore }, 2000)
            compare(live.clockTextItem.text,
                Qt.formatTime(live.now, "HH:mm"),
                "the label must track the tick" + (labelBefore === live.clockTextItem.text
                    ? " (both read " + live.clockTextItem.text + ")" : ""))

            // An injected clock is still injected: `now` was assigned, so the binding
            // the tick drives is gone and the tick cannot write over a fixed moment.
            // Every other header test depends on this half.
            var frozen = new Date(2026, 9, 12, 9, 41)
            var injected = makePage({ now: frozen, clockTickInterval: 20 })
            tryVerify(function() { return injected.clockTextItem.width > 0 }, 1000)
            wait(120)
            compare(injected.now.getTime(), frozen.getTime(),
                "an injected clock must survive the tick")
            compare(injected.clockTextItem.text, "09:41")
            compare(injected.dateTextItem.text, Qt.formatDate(frozen, "yyyy-MM-dd dddd"))
            compare(injected.liveClock.getTime() === frozen.getTime(), false,
                "the live clock kept running underneath - only the binding is gone")
        }

        // --- Overview: layout ---

        function test_theLayoutModeFlipsAtTheLogicBreakpoint() {
            var narrow = makePage({ width: CcLogic.minimumTwoColumnWidth - 1 })
            var wide = makePage({ width: CcLogic.minimumTwoColumnWidth })
            tryVerify(function() { return narrow.layoutMode === "narrow"
                                    && wide.layoutMode === "wide" }, 1000)
            compare(narrow.layoutMode, "narrow")
            compare(wide.layoutMode, "wide")

            // ...and the breakpoint is the module's own, not a page-local number.
            // One pixel either side of it is enough to catch a hardcoded 760.
            compare(makePage({ width: CcLogic.minimumTwoColumnWidth - 2 }).layoutMode,
                "narrow")
            compare(makePage({ width: CcLogic.minimumTwoColumnWidth + 2 }).layoutMode,
                "wide")
        }

            function test_theWideLayoutSplitsIntoTheModulesTwoSections() {
            var page = makePage({ width: 1024, height: 720 })
            tryVerify(function() { return page.layoutMode === "wide" }, 1000)
            compare(page.sections.left.join(","), CcLogic.sectionOrder("wide").left.join(","))
            compare(page.sections.right.join(","), CcLogic.sectionOrder("wide").right.join(","))

            // The left column holds the four control cards, top to bottom.
            tryVerify(function() { return page.controlsColumnItem.width > 0 }, 1000)
            compare(page.controlsColumnItem.x, 0, "the control column is the left one")
            compare(page.controlsColumnItem.width, page.leftColumnWidth)
            verify(page.calendarItem.x >= page.controlsColumnItem.width,
                "the information column is to the right of the controls")
            verify(page.notificationsItem.x >= page.controlsColumnItem.width)

            // Balanced, and derived from the page's own width rather than from a
            // label: the split is the middle of what is left after the padding and
            // the gutter, and the two columns add up with the gutter to exactly the
            // usable width - nothing is left over for a label to claim.
            compare(page.leftColumnWidth,
                Math.floor((page.usableWidth - page.columnGap) * 0.5),
                "the two columns split the remainder evenly")
            verify(page.leftColumnWidth >= page.controlColumnMinimumWidth
                    && page.rightColumnWidth >= page.infoColumnMinimumWidth,
                "both columns honour their explicit minimum")
            compare(page.leftColumnWidth + page.columnGap + page.rightColumnWidth,
                Math.max(page.usableWidth, page.leftColumnWidth + page.columnGap
                    + page.infoColumnMinimumWidth),
                "the columns plus the gutter consume the usable width exactly")

            var cards = page.controlCards
            compare(cards.length, 4)
            for (var i = 1; i < cards.length; i++) {
                var above = cards[i - 1]
                verify(cards[i].y >= above.y + above.height,
                    "card " + i + " must start below the one above it")
                compare(cards[i].width, above.width,
                    "the cards share one column width")
            }

            // The right column is calendar then notifications, in that order, and
            // the y positions are the ones the module's order array implies.
            var rightOrder = CcLogic.sectionOrder("wide").right
            compare(rightOrder.join(","), "calendar,notifications")
            verify(page.calendarItem.y < page.notificationsItem.y,
                "the calendar is the first information block")
            verify(page.notificationsItem.y
                    >= page.calendarItem.y + page.calendarItem.height,
                "the summary starts below the calendar")
            compare(page.calendarItem.width, page.rightColumnWidth)
            compare(page.notificationsItem.width, page.rightColumnWidth)
        }

        // The header and the sections it introduces are laid out in the SAME content
        // box: the header is the first section of the stack, and the wide column
        // arrays describe a column, so neither arrangement mentions the other. Every
        // wide section therefore resolved its offset to 0 and painted on top of the
        // clock. Asserted as an overlap between real rectangles rather than as a
        // pair of y values, because "the clock and the cards share pixels" is the
        // defect and it is what a reader of this layout has to be able to trust.
        function test_theWideLayoutKeepsTheHeaderClearOfEverySection() {
            var page = makePage({
                width: 1024, height: 720,
                networkService: makeFake(fakeNetworkComponent),
                bluetoothService: makeFake(fakeBluetoothComponent),
                volumeService: makeFake(fakeVolumeComponent),
                mediaService: makeFake(fakeMediaComponent),
                batteryService: makeFake(fakeBatteryComponent),
                notificationService: seedNotifications(
                    makeFake(fakeNotificationComponent), 3)
            })
            tryVerify(function() { return page.layoutMode === "wide" }, 1000)
            tryVerify(function() {
                return page.mediaCard.width > 0 && page.calendarItem.width > 0
                    && page.headerItem.height > 0
            }, 1000)

            var content = page.layoutContentItem
            var headerBottom = bottomIn(page.headerItem, content)
            verify(headerBottom > 0, "the header occupies real space in the content box")

            var names = CcLogic.sectionOrder("wide").left.concat(
                CcLogic.sectionOrder("wide").right)
            compare(names.join(","), "controls,calendar,notifications")
            for (var i = 0; i < names.length; i++) {
                var section = page.sectionItem(names[i])
                verify(section !== null, "section " + names[i] + " must exist")
                verify(!overlapsVertically(page.headerItem, section, content),
                    "the header and the " + names[i]
                        + " section overlap (header ends at " + headerBottom.toFixed(1)
                        + ", " + names[i] + " starts at " + topIn(section, content).toFixed(1) + ")")
                verify(topIn(section, content) >= headerBottom - 0.5,
                    names[i] + " must start below the header")
            }

            // The header has to be the first thing on the panel, not a strip the
            // scroller is pushed down past: the reserved-band arrangement left 74px
            // of empty surface above the clock in both layouts.
            var surfaceTop = topIn(page.layoutSurfaceItem, page)
            compare(surfaceTop, page.pagePadding,
                "the scroller starts at the page padding, with no band above the header")
            compare(topIn(page.headerItem, page), page.pagePadding,
                "the header is the first thing in the content box")
            compare(topIn(page.headerItem, page), surfaceTop,
                "the header sits at the top of the scroll surface itself")

            // The narrow surface carries the same header as the first section of its
            // stack, so the no-band arrangement has to hold there too - and the
            // fixture must actually scroll, or the assertion proves nothing.
            var narrow = makePage({ width: 560, height: 700 })
            tryVerify(function() { return narrow.layoutMode === "narrow"
                                    && narrow.headerItem.height > 0 }, 1000)
            compare(topIn(narrow.layoutSurfaceItem, narrow), narrow.pagePadding)
            verify(narrow.layoutSurfaceItem.interactive,
                "the fixture must actually be a scrolling narrow surface")
            verify(!overlapsVertically(narrow.headerItem,
                    narrow.sectionItem("controls"), narrow.layoutContentItem),
                "the narrow header must stay clear of the control column too")

            // And the content box is tall enough for the whole wide arrangement, so
            // nothing is pushed out of the surface by the header it now clears.
            verify(content.height >= bottomIn(page.notificationsItem, content),
                "the content box must contain the information column")
            verify(content.height >= bottomIn(page.controlsColumnItem, content))
        }

        function test_theNarrowStackFollowsTheModulesSectionOrder() {
            var page = makePage({ width: 560, height: 1400 })
            tryVerify(function() { return page.layoutMode === "narrow" }, 1000)
            var order = CcLogic.sectionOrder("narrow").stacked
            compare(page.sections.stacked.join(","), order.join(","))
            compare(order.join(","), "overview,controls,notifications,calendar")

            // Read the real geometry and check it against the module's order,
            // rather than trusting the page's own array back to itself.
            var previousBottom = -1
            for (var i = 0; i < order.length; i++) {
                var item = page.sectionItem(order[i])
                verify(item !== null, "section " + order[i] + " must exist")
                verify(item.visible, "section " + order[i] + " must be shown")
                var top = item.mapToItem(page.layoutContentItem, 0, 0).y
                verify(top >= previousBottom,
                    order[i] + " must start at or below "
                        + (i > 0 ? order[i - 1] : "the top"))
                previousBottom = top + item.height
                // Every stacked section spans the full content width, so a narrow
                // panel never needs a horizontal scroll to reach its far edge.
                compare(item.width, page.usableWidth,
                    order[i] + " must span the narrow content width")
            }
            // All four are on screen at once: a stacked layout is not a pager.
            compare(page.visibleSectionCount, 4)
        }

        function test_theNarrowLayoutHasNoHorizontalOverflow() {
            var page = makePage({ width: 560, height: 1400 })
            tryVerify(function() { return page.layoutMode === "narrow" }, 1000)
            tryVerify(function() { return page.calendarItem.width > 0 }, 1000)

            // The one scroller on this page is vertical only, so there is no
            // horizontal path off the panel at any width.
            var scrollers = scrollContainers(page)
            compare(scrollers.length, 1, "the page has exactly one scroll surface")
            compare(scrollers[0].flickableDirection, Flickable.VerticalFlick)
            verify(scrollers[0].contentWidth <= scrollers[0].width,
                "the scroller has no horizontal overflow to scroll through")

            var items = descendants(page)
            verify(items.length > 0)
            for (var i = 0; i < items.length; i++) {
                var item = items[i]
                verify(item.width >= 0, "no negative width in the narrow layout")
                verify(item.height >= 0, "no negative height in the narrow layout")
                var left = item.mapToItem(page, 0, 0).x
                var right = left + item.width
                verify(left >= -0.5 && right <= page.width + 0.5,
                    "descendant " + i + " (" + item.objectName + ") spans "
                        + left.toFixed(1) + ".." + right.toFixed(1)
                        + " outside 0.." + page.width)
            }
        }

        // The same geometry contract in the wide layout, with long service words
        // that would stretch a column if any label were allowed to.
        function test_theWideLayoutKeepsLongLabelsInsideTheirColumns() {
            var page = makePage({
                width: 900, height: 720,
                networkService: seededNetwork(makeFake(fakeNetworkComponent), [
                    { ssid: "a-network-ssid-long-enough-to-need-eliding" }]),
                mediaService: makeFake(fakeMediaComponent, {
                    title: "a track title that is far longer than any column",
                    artist: "and an artist name to match it" })
            })
            tryVerify(function() { return page.layoutMode === "wide" }, 1000)
            tryVerify(function() { return page.mediaCard.width > 0 }, 1000)
            var scrollers = scrollContainers(page)
            compare(scrollers.length, 1)
            compare(scrollers[0].flickableDirection, Flickable.VerticalFlick)

            var items = descendants(page)
            for (var i = 0; i < items.length; i++) {
                var item = items[i]
                var left = item.mapToItem(page, 0, 0).x
                var right = left + item.width
                verify(left >= -0.5 && right <= page.width + 0.5,
                    "descendant " + i + " (" + item.objectName + ") spans "
                        + left.toFixed(1) + ".." + right.toFixed(1))
            }
            // The long words really are long, so the assertion cannot pass by
            // the labels happening to fit: implicitWidth is the natural width, and
            // a Text reports contentWidth AFTER eliding, so elision itself cannot
            // be read back off contentWidth.
            verify(page.mediaCard.summaryItem.implicitWidth
                    > page.mediaCard.summaryItem.width,
                "the fixture must actually need eliding")
            verify(page.mediaCard.summaryItem.elide !== Text.ElideNone,
                "the summary must elide rather than overflow")
            verify(page.mediaCard.titleItem.elide !== Text.ElideNone,
                "the title must elide rather than overflow")
        }

        // --- Overview: page contract and seams ---

        function test_theOverviewPublishesTheWaveRouteContract() {
            var page = makePage({})
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            compare(page.objectName, "controlCenterPage")
            verify(page.title.length > 0)
            verify(page.description.length > 0)
            compare(page.sidebarEntries.length, 0,
                "the overview fills the full width; the host hides an empty rail")
            compare(page.activeSidebarId, "")
            // The overview is a top-level route with nothing to pop.
            compare(page.canGoBack, false)
            compare(page.handleBack(), false,
                "declining back is what lets the host close the surface")
            compare(page.focusDefaultCount, 0)
            page.focusDefault()
            tryCompare(page, "focusDefaultCount", 1, 800)
            verify(page.activeFocus,
                "focus lands on the page, never on the launcher's search field")
        }

        function test_theOverviewMapsItsSnapshotsThroughTheLogicNormalizer() {
            var page = makePage({
                networkService: makeFake(fakeNetworkComponent),
                volumeService: makeFake(fakeVolumeComponent, { sinkMuted: true }),
                mediaService: makeFake(fakeMediaComponent)
            })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)

            for (var i = 0; i < CcLogic.cardKinds.length; i++) {
                var kind = CcLogic.cardKinds[i]
                var data = page.cardData(kind)
                verify(data !== null, kind + " must publish a normalized card")
                // Re-derived from the same snapshot through the same module: any
                // second opinion in the page shows up as a mismatch here.
                var again = CcLogic.normalizeCard(kind, page.snapshotFor(kind))
                compare(JSON.stringify(data), JSON.stringify(again),
                    kind + " must be the module's own normalization, not a local copy")
                compare(data.title, CcLogic.titleFor(kind))
                compare(data.icon, CcLogic.iconFor(kind))
                compare(data.detailRoute, CcLogic.detailRoutes[kind] || "")
            }
            compare(page.cardData("volume").summary, "Muted")
            compare(page.cardData("volume").action, "direct")
            compare(page.cardData("network").action, "detail")
            compare(page.cardData("media").detailRoute, "",
                "media has no detail route yet")
        }

        // No runtime assertion can see a card that forgot the module: the state
        // logic could be re-derived inline and every behavioural check above
        // would still pass. The source is read directly instead.
        function test_theOverviewMapsThroughControlCenterLogicInsteadOfForkingIt() {
            var file = readRepoFile("modules/lazerbar/ControlCenter.qml")
            compare(file.status, 200, "the overview source must be readable")
            verify(file.text.indexOf("ControlCenterLogic.js") >= 0,
                "the overview must import the shared contract module")
            var calls = file.text.match(/CcLogic\.normalizeCard\(/g)
            verify(calls !== null && calls.length >= 1,
                "the overview must normalize cards through CcLogic.normalizeCard")

            // The caller hands the summary the module's fixed cap, never a number
            // of its own: a limit derived from the incoming history would let a
            // busy list reshape the panel, which is the exact failure the module's
            // constant exists to prevent.
            verify(file.text.indexOf("maxEntries: CcLogic.notificationEntryCap") >= 0,
                "the overview must cap the summary with the module's own constant")

            verify(file.text.indexOf("markAllRead") < 0,
                "the overview must never clear the user's read state")

            // Layout and header vocabulary comes from the module too.
            verify(file.text.indexOf("CcLogic.sectionOrder") >= 0,
                "the section order must come from the module")
            verify(file.text.indexOf("CcLogic.layoutMode") >= 0,
                "the breakpoint must come from the module")
            verify(file.text.indexOf("CcLogic.minimumTwoColumnWidth") >= 0,
                "the breakpoint value must be the module's own constant")
            verify(file.text.indexOf("CcLogic.weatherState") >= 0)
        }

        // --- Detail pages: the same-surface contract ---
        //
        // The routing shape first, because it is the part a detail page's own
        // behaviour cannot prove. Both pages are tested standalone below; this
        // section is about the overview mounting them INSIDE itself.

        // The brief's own assertion, verbatim in shape: a card activation is a
        // request, and the request reaches the same surface's sub-page stack.
        function test_networkCardRequestsSameSurfaceDetail() {
            var page = makePage({
                networkService: makeFake(fakeNetworkComponent),
                bluetoothService: makeFake(fakeBluetoothComponent)
            })
            // Counted from OUTSIDE the page, through the emitted signal, rather
            // than from an internal flag: the assertion is about the request that
            // leaves the card, not about a variable the page maintains itself.
            var requests = 0
            page.networkDetailsRequested.connect(function() { requests++ })
            tryVerify(function() { return page.networkCard.width > 0 }, 1000)

            page.networkCard.activate()
            tryVerify(function() { return requests === 1 }, 1000)

            // The request is answered in-surface: the same page now holds the
            // detail page, and the route offers back because it has something to
            // pop. Back needs a callable handler, not just a published flag.
            tryVerify(function() { return page.activeSubPage === "network-detail" }, 1000)
            compare(page.canGoBack, true,
                "a page holding a sub-page offers back")
            verify(typeof page.handleBack === "function",
                "back needs a callable handler, not just a published flag")
            compare(page.canGoBack === (typeof page.handleBack === "function"), true,
                "both halves of the host's back contract, or neither")
        }

        function test_openingADetailPageMountsItInsideTheOverview() {
            var page = makePage({
                networkService: makeFake(fakeNetworkComponent),
                bluetoothService: makeFake(fakeBluetoothComponent)
            })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            compare(page.activeSubPage, "",
                "the overview shows no sub-page to begin with")
            compare(page.detailPageItem, null)
            verify(page.overviewItem.visible,
                "the overview is what is on screen before a request")

            page.openNetworkDetails()
            tryVerify(function() { return page.activeSubPage === "network-detail" }, 1000)
            var detail = page.detailPageItem
            verify(detail !== null, "the network detail page must be mounted")
            compare(detail.objectName, "controlCenterNetworkDetail")
            tryVerify(function() { return detail.width > 0 && detail.height > 0 }, 1000)
            verify(!page.overviewItem.visible,
                "the overview yields the viewport while a detail page is up")
            verify(page.visible, "the route page itself is still alive")

            page.openBluetoothDetails()
            tryVerify(function() { return page.activeSubPage === "bluetooth-detail" }, 1000)
            compare(page.detailPageItem.objectName, "controlCenterBluetoothDetail")
        }

        // Focus follows the mounted page. While a sub-page is up, a keystroke meant for
        // its controls must not be eaten by a card under an invisible overview -
        // and the hand-off has to be DEFERRED, because a Loader builds its item
        // asynchronously: reading `detailPageItem` in the same turn as the route
        // change reads null, and focusing the outgoing page would put the caret
        // in an invisible one.
        function test_focusFollowsTheMountedSubPage() {
            var page = makePage({
                networkService: makeFake(fakeNetworkDetailComponent),
                bluetoothService: makeFake(fakeBluetoothDetailComponent)
            })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)

            page.focusDefault()
            tryVerify(function() { return page.activeFocus === true }, 1000)
            var overviewFocused = page.focusDefaultCount

            page.openNetworkDetails()
            tryVerify(function() { return page.activeSubPage === "network-detail" }, 1000)
            var detail = page.detailPageItem
            verify(detail !== null, "the network detail page must be mounted")

            // A later press lands on the sub-page, not the overview. The counter
            // is a CALL count, so it still increments - what must not happen is
            // the overview keeping focus, and that is what the two focus flags
            // say: the sub-page holds it and the overview no longer does.
            page.focusDefault()
            tryVerify(function() { return detail.activeFocus === true }, 1000,
                "focus must land on the mounted sub-page")
            verify(page.activeFocus !== true,
                "the overview must not keep focus behind a mounted sub-page")
            verify(page.focusDefaultCount > overviewFocused,
                "the press must have reached the route, not been dropped")

            // And after a return, on the overview again - the same one press both
            // ways, which is what a user would expect from one route.
            verify(page.handleBack())
            tryVerify(function() { return page.activeSubPage === "" }, 1000)
            page.focusDefault()
            tryVerify(function() { return page.activeFocus === true }, 1000,
                "back on the overview, focus returns to it")
        }

        // The module owns the sub-page names, so no caller can invent a fourth
        // destination and no detail page can be reached by a name the module
        // does not declare.
        function test_theSubPageNamesComeFromTheModule() {
            var page = makePage({
                networkService: makeFake(fakeNetworkComponent),
                bluetoothService: makeFake(fakeBluetoothComponent)
            })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)

            page.openNetworkDetails()
            tryVerify(function() { return page.activeSubPage === "network-detail" }, 1000)
            compare(page.activeSubPage, CcLogic.detailRoutes.network)

            page.openBluetoothDetails()
            tryVerify(function() { return page.activeSubPage === "bluetooth-detail" }, 1000)
            compare(page.activeSubPage, CcLogic.detailRoutes.bluetooth)

            // An unknown name mounts nothing and REFUSES, so a caller cannot
            // replace a mounted page with an empty viewport by typo. Refusing is
            // also strictly better than clearing: a rejected request leaves what
            // was on screen alone, which is what the user was looking at.
            compare(page.requestSubPage("settings-center"), false,
                "a name the module does not declare is refused")
            compare(page.activeSubPage, "bluetooth-detail",
                "a refused request leaves the mounted page alone")
            compare(page.requestSubPage(""), false)
            compare(page.requestSubPage(undefined), false)
            compare(page.requestSubPage(CcLogic.detailRoutes.volume), false,
                "volume has no detail route, so it has no sub-page either")

            // ...and the module's own helper agrees with what the page accepts,
            // so the two cannot drift into accepting different sets.
            compare(CcLogic.isDetailRoute(page.activeSubPage), true)
            compare(CcLogic.isDetailRoute("settings-center"), false)
            compare(CcLogic.isDetailRoute(CcLogic.detailRoutes.network), true)
            compare(CcLogic.isDetailRoute(CcLogic.detailRoutes.bluetooth), true)
        }

        // Back restores the retained overview, and the refresh lands ONE event
        // loop turn later - not in the same turn that hid the sub-page.
        //
        // Same-turn is the bug this guards: `refreshForOpen()` throttles itself
        // and re-reads the device table, and doing that while the overview's own
        // cards are still bound to the pre-return state made the summary lag a
        // whole frame behind the operation that caused it.
        function test_backRestoresTheOverviewThenRefreshesOneTurnLater() {
            var network = makeFake(fakeNetworkDetailComponent)
            var bluetooth = makeFake(fakeBluetoothDetailComponent)
            var page = makePage({
                networkService: network, bluetoothService: bluetooth
            })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            page.openNetworkDetails()
            tryVerify(function() { return page.activeSubPage === "network-detail" }, 1000)
            compare(page.returnRefreshCount, 0,
                "opening a sub-page is not a RETURN, so the deferred hook stays quiet")
            // What the page DID ask for on the way in is its own open refresh, and
            // that is the detail page's call, not the overview's.
            compare(network.callCount("refreshForOpen"), 1,
                "the mounted detail page asked the service to re-read the radio")

            verify(page.handleBack(), "back must be consumed, not declined")
            // Same turn: the overview is already back and the refresh has NOT
            // happened. This is the whole point of the deferral.
            compare(page.activeSubPage, "")
            verify(page.overviewItem.visible)
            compare(page.returnRefreshCount, 0,
                "restoring the overview and refreshing it are different turns")
        }

        // The deferral itself, asserted as its own thing: same turn restores the
        // overview, the NEXT turn refreshes it - exactly once per return.
        function test_theDeferredRefreshRunsOnTheNextEventLoopTurn() {
            var network = makeFake(fakeNetworkDetailComponent)
            var page = makePage({ networkService: network })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            page.openNetworkDetails()
            tryVerify(function() { return page.activeSubPage === "network-detail" }, 1000)
            // The mount asked for its own read; the RETURN refresh is what this
            // test is about, so it is counted from there.
            compare(network.callCount("refreshForOpen"), 1,
                "the detail page's own open refresh happened on the way in")

            verify(page.handleBack())
            compare(page.activeSubPage, "")
            compare(page.returnRefreshCount, 0,
                "the hook has not run yet, one turn after the pop")

            tryCompare(page, "returnRefreshCount", 1, 1000)
            // The hook reaches the service, and reaches it through its own
            // method: the page must not re-read the adapter itself. One more call
            // than the mount made - the deferral adds one, and only one.
            tryVerify(function() { return network.callCount("refreshForOpen") === 2 }, 1000)
            compare(network.callCount("refreshForOpen"), 2)

            // Exactly one refresh: the deferral must not become a loop.
            compare(page.returnRefreshCount, 1)
            wait(50)
            compare(page.returnRefreshCount, 1, "one return, one refresh")

            // A second back with nothing to pop must not refresh: the overview
            // declines, and a decline is not a return.
            compare(page.handleBack(), false)
            wait(50)
            compare(page.returnRefreshCount, 1,
                "a declined press is not a return and refreshes nothing")
        }

        // The deferred refresh is the page's own hook, so the overview stays a
        // report and the services stay the only owners of side effects.
        function test_theReturnRefreshIsAHookTheOverviewExposes() {
            var page = makePage({ networkService: makeFake(fakeNetworkDetailComponent) })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            verify(typeof page.refreshAfterReturn === "function",
                "the return refresh must be a hook a test can drive")
            compare(typeof page.refreshAfterReturn, "function")

            // Driving it directly with no service at all must be a no-op, not a
            // throw: the production page starts with every service null.
            var bare = makePage({})
            tryVerify(function() { return bare.controlCardCount === 4 }, 1000)
            bare.refreshAfterReturn()
        }

        // --- Opening the detail asks the service to re-read the radio ---

        // The scan behind the overview's summary can be minutes old, and a
        // network that appeared since then is not in the list at all. So the
        // detail page asks for a fresh read on its way in - the same call the
        // bar's network popup makes, through the service's own method, so the
        // service throttles it exactly as it throttles that one.
        function test_theNetworkDetailRequestsAServiceRefreshWhenItOpens() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: true, signal: 78 }
            ])
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.width > 0 }, 1000)

            compare(fake.refreshCalls, 1,
                "opening the page asks the service to re-read the radio, once")
            compare(fake.callCount("refreshForOpen"), 1,
                "and it reaches the service through its own refreshForOpen()")
            compare(fake.callArgs("requestScan", 0), undefined,
                "the open must not borrow the rescan button's arguments")
            compare(fake.callCount("requestScan"), 0,
                "opening is a read, not the user's deliberate rescan")

            // The count is the page's own, so the ONCE-ness is observable rather
            // than inferred from the service.
            compare(page.openRefreshCount, 1)
        }

        // One open, one request. A binding, or a handler on the service property,
        // would ask again for every re-render and every service swap - and a
        // service swap is precisely what a test does when it seeds a fake. An
        // open that re-reads the radio per binding churn is a scan per frame, and
        // the service's own throttle is the only thing standing between that and
        // a busy adapter.
        function test_theOpenRefreshIsAskedOnceAndNeverAgainOnChurn() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: true, signal: 78 }
            ])
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.width > 0 }, 1000)
            compare(fake.refreshCalls, 1)

            // Every kind of churn a live page sees: the scan map replaced wholesale,
            // a loading flag, a resize, a focus hand-off.
            fake.setWifiMap([
                { ssid: "Home", security: "WPA2", signal: 70, connected: true,
                    existing: true },
                { ssid: "Neighbour 5G", security: "WPA2", signal: 40,
                    connected: false, existing: false }])
            fake.scanningActive = true
            fake.connecting = true
            fake.connectingTo = "Home"
            page.width = 800
            page.focusDefault()
            wait(200)
            compare(fake.refreshCalls, 1,
                "churn must not turn the open refresh into a poll")

            // A second mount is a second open, so it asks again - the rule is
            // "once per mount", not "once per page object ever".
            var reopened = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return reopened.width > 0 }, 1000)
            compare(fake.refreshCalls, 2, "a fresh mount is a fresh open")
        }

        // Only the network has a radio to re-read: the Bluetooth detail mounts and
        // asks nothing of the network service, and its own construction is inert
        // (asserted on its own page below). Returning to the overview stays the
        // overview's deferred path - the page does not take that over.
        function test_onlyTheNetworkMountRefreshesAndTheReturnStaysDeferred() {
            var network = makeFake(fakeNetworkDetailComponent)
            var bluetooth = seededBluetooth(makeFake(fakeBluetoothDetailComponent), [
                { name: "Speaker", address: "AA:BB:00:00:00:01", connected: true,
                    paired: true, signalStrength: 80 }
            ])
            var page = makePage({ networkService: network, bluetoothService: bluetooth })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            compare(network.refreshCalls, 0,
                "the overview itself opens without a radio refresh")

            page.openBluetoothDetails()
            tryVerify(function() { return page.activeSubPage === "bluetooth-detail" }, 1000)
            wait(150)
            compare(network.refreshCalls, 0,
                "a Bluetooth detail mounts without touching the radio")
            compare(page.returnRefreshCount, 0)

            // Returning is the overview's own deferred refresh, and only then.
            verify(page.handleBack())
            tryCompare(page, "returnRefreshCount", 1, 1000)
            compare(network.refreshCalls, 1,
                "the return refresh is the deferred path, and it is the only one here")

            page.openNetworkDetails()
            tryVerify(function() { return page.activeSubPage === "network-detail" }, 1000)
            tryVerify(function() { return network.refreshCalls === 2 }, 1000,
                "the network detail's own open refresh, on top of the return one")

            verify(page.handleBack())
            tryCompare(page, "returnRefreshCount", 2, 1000)
            compare(network.refreshCalls, 3, "one open, one return, one call each")
        }

        // The password prompt must CLAIM its Escape, and the claim must be written
        // down rather than left implicit.
        //
        // Measured on this Qt build (6.11.2): a Keys handler already stops an
        // unaccepted press from walking up the chain, so the runtime behaviour is
        // the same either way - which is exactly why it cannot be what pins the
        // rule. What is at stake is the page's intent: an Escape nobody claims
        // reads as "nobody here wanted this press", and the first ancestor waiting
        // for one is the wave host, whose handler pops the whole detail page. So
        // the explicit claim is asserted on the source, the same way the other
        // invisible-to-runtime contracts here are.
        function test_thePasswordPromptExplicitlyClaimsItsEscapePress() {
            var file = readRepoFile("modules/lazerbar/ControlCenterNetwork.qml")
            compare(file.status, 200, "the network page source must be readable")
            var code = stripComments(file.text)
            var claim = code.indexOf("Keys.onEscapePressed")
            verify(claim >= 0, "the prompt field must handle Escape itself")
            var cancel = code.indexOf("root.cancelPassword()", claim)
            verify(cancel > claim, "Escape must cancel the prompt")
            verify(code.indexOf("event.accepted = true", cancel) > cancel
                    && code.indexOf("event.accepted = true", cancel)
                        - cancel < 220,
                "and it must claim the press, so the host never sees it")
        }

        // A detail page must not be reachable as a top-level Wave route. That is
        // the whole point of the same-surface ruling, and it is invisible from
        // behaviour alone: a second route would open its own Loader item and
        // still look correct to every test above.
        function test_detailPagesAreNotTopLevelWaveRoutes() {
            var routes = readRepoFile("modules/lazerbar/WaveSurfaceLogic.js")
            compare(routes.status, 200, "the route registry must be readable")
            verify(routes.text.indexOf('"network-detail"') < 0,
                "a detail page must never be registered as a Wave route")
            verify(routes.text.indexOf('"bluetooth-detail"') < 0,
                "a detail page must never be registered as a Wave route")

            var host = readRepoFile("modules/lazerbar/WaveSurfaceHost.qml")
            compare(host.status, 200, "the host source must be readable")
            verify(host.text.indexOf("ControlCenterNetwork") < 0
                    && host.text.indexOf("ControlCenterBluetooth") < 0,
                "the host must know nothing about any route's sub-pages")
            verify(host.text.indexOf("PanelWindow") < 0,
                "the host must not create a second window")
        }

        // The detail pages are content, not services: no window, no second
        // service, no direct tool invocation. Asserted on the source because no
        // runtime assertion can see a Process that is merely never triggered.
        function test_theDetailPagesReuseTheServicesInsteadOfReimplementingThem() {
            var files = ["modules/lazerbar/ControlCenterNetwork.qml",
                "modules/lazerbar/ControlCenterBluetooth.qml"]
            for (var i = 0; i < files.length; i++) {
                var file = readRepoFile(files[i])
                compare(file.status, 200, files[i] + " must be readable")
                // Comments are stripped first, because both pages have to be able
                // to SAY that they shell out to nothing: a check over the raw text
                // would flag the sentence that documents the rule it enforces.
                var code = stripComments(file.text)
                verify(code.indexOf("PanelWindow") < 0,
                    files[i] + " must not create a window")
                verify(code.indexOf("PopupWindow") < 0,
                    files[i] + " must not create an overlay")
                verify(code.indexOf("nmcli") < 0,
                    files[i] + " must not shell out to nmcli itself")
                verify(code.indexOf("bluetoothctl") < 0,
                    files[i] + " must not shell out to bluetoothctl itself")
                verify(code.indexOf("Process") < 0,
                    files[i] + " must not run its own process")
                verify(code.indexOf("Quickshell") < 0,
                    files[i] + " must not import Quickshell to reach a service")
                verify(code.indexOf("../services") < 0,
                    files[i] + " must not import a service directly")
            }
        }

        // --- Production owner edge ---

        // The route page takes its services as injected properties, so the
        // wiring lives at the owner edge and the page itself stays importable by
        // this suite with no Quickshell module. That boundary is worth pinning:
        // a service imported straight into the page would make every fake-service
        // test above a lie, and a service added to the page but never injected
        // would render an "unavailable" card in production with nothing failing.
        //
        // So the two halves are asserted together: every property the page
        // declares is forwarded by the surface, and the surface declares nothing
        // the page cannot accept.
        function test_theRoutePageReceivesEveryInjectedServiceAndImportsNone() {
            var page = readRepoFile("modules/lazerbar/ControlCenter.qml")
            compare(page.status, 200, "the overview must be readable")
            var pageCode = stripComments(page.text)
            verify(pageCode.indexOf("Quickshell") < 0,
                "the overview must not import Quickshell to reach a service")
            verify(pageCode.indexOf("../services") < 0,
                "the overview must not import a service directly")

            var surface = readRepoFile("modules/lazerbar/LauncherSurface.qml")
            compare(surface.status, 200, "the launcher surface must be readable")
            var surfaceCode = stripComments(surface.text)
            // The closing quote matters: the surface legitimately imports the
            // embedded launcher session, and only the bare services module would
            // give it the singletons.
            verify(surfaceCode.indexOf('import "../../services"') < 0,
                "the launcher surface must not import the services module; the bar injects them")

            // Every service seam the page declares, named off the page itself so
            // this cannot drift from the contract the cards actually read.
            var seams = pageServiceSeams(pageCode)
            verify(seams.length > 0, "the overview must declare service seams to inject")
            for (var index = 0; index < seams.length; index++) {
                var seam = seams[index]
                verify(surfaceCode.indexOf("property var " + seam) !== -1,
                    "the launcher surface must declare an injected " + seam)
                verify(surfaceCode.indexOf(seam + ": root." + seam) !== -1,
                    "the launcher surface must forward " + seam + " into the route page")
            }

            // The bars that bind the singletons are PanelWindow roots, so the
            // whole-repo compile guard cannot read their bodies: a name the
            // services module does not declare would surface as a shell that does
            // not start, with nothing to point at. The registry is a plain text
            // file, so this half of the contract is checkable after all - and both
            // bars are checked, because both mount a wave surface.
            var registry = readRepoFile("services/qmldir")
            compare(registry.status, 200, "the services registry must be readable")
            for (var edge = 0; edge < barOwnerEdges.length; edge++) {
                var owner = readRepoFile(barOwnerEdges[edge])
                compare(owner.status, 200, barOwnerEdges[edge] + " must be readable")
                var ownerCode = stripComments(owner.text)
                for (var bound = 0; bound < seams.length; bound++)
                    verify(ownerCode.indexOf(seams[bound] + ": Services."
                            + seamNameFor(seams[bound])) !== -1,
                        barOwnerEdges[edge] + " must bind " + seams[bound]
                            + " to Services." + seamNameFor(seams[bound]))
            }
            // And each bound name has to be a singleton that exists, or the shell
            // dies at startup on an unknown type rather than on a missing card.
            for (var name = 0; name < seams.length; name++)
                verify(registry.text.indexOf("singleton " + seamNameFor(seams[name])) !== -1,
                    "no Services." + seamNameFor(seams[name]) + " singleton for the "
                        + seams[name] + " seam")
        }

        // Every bar that mounts the wave surface is an owner edge for the route's
        // services, so a new binding has to reach all of them.
        readonly property var barOwnerEdges: ["modules/bar/TopBar.qml",
            "modules/lazerbar/TopBar.qml"]

        // The singleton name a seam is bound to. `mediaService` is the seam and
        // `MediaService` the singleton; the convention is stated here rather than
        // left implicit, so a seam that does not follow it fails loudly instead of
        // quietly looking for a singleton nobody declared.
        function seamNameFor(seam) {
            return seam.charAt(0).toUpperCase() + seam.slice(1)
        }

        // The page's service seams, read off its own declarations: `property var
        // <name>: null` is how it spells "injected, and absent is a defined
        // state". Anything else with a different default is a local, so it is not
        // part of the owner-edge contract.
        function pageServiceSeams(pageCode) {
            var found = []
            var pattern = /property var ([A-Za-z][A-Za-z0-9]*): null/g
            var match
            while ((match = pattern.exec(pageCode)) !== null) {
                if (found.indexOf(match[1]) < 0)
                    found.push(match[1])
            }
            return found
        }

        // --- Network detail page ---

        function test_theNetworkDetailPagePublishesTheBackContract() {
            var page = makeNetworkPage({ networkService: makeFake(fakeNetworkDetailComponent) })
            tryVerify(function() { return page.width > 0 }, 1000)
            compare(page.objectName, "controlCenterNetworkDetail")
            verify(page.title.length > 0)
            verify(page.description.length > 0)
            // A detail page is a sub-page by definition, so it always has
            // something to pop - the overview is the thing it pops back to.
            compare(page.canGoBack, true)

            var backs = 0
            page.backRequested.connect(function() { backs++ })
            // Unlike the overview, this one takes the press: returning false
            // would make the host close the whole surface instead.
            verify(page.handleBack())
            compare(backs, 1)
            compare(page.canGoBack, true,
                "the page stays a sub-page, so a second press is still a back")
        }

        function test_theNetworkDetailPageShowsTheWifiPowerAndWiredState() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: true },
                { ssid: "Neighbour 5G", connected: false }
            ])
            fake.ethernetAvailable = true
            fake.ethernetConnected = true
            fake.activeEthernetIf = "enp3s0"
            fake.activeEthernetConnection = "Office LAN"
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.listItem.width > 0 }, 1000)

            compare(page.wifiEnabled, true)
            compare(page.wifiToggleItem.checked, true)
            compare(page.wifiRowCount, 2)
            compare(page.connectedSsid, "Home",
                "the connected name comes off the connected entry of the scan map")
            verify(page.wiredStatusText.length > 0,
                "a live wired link must report its own profile name")
            verify(page.wiredStatusText.indexOf("Office LAN") >= 0)
            compare(page.errorText, "", "no failure means no inline error")

            // The row order is the radio's own priority: connected first, then
            // by signal. "Home" is connected, so it leads regardless of signal.
            var rows = wifiRows(page)
            compare(rows.length, 2, "both reported networks must exist as rows")
            compare(String(rows[0].rowKey), "Home",
                "a connected network leads regardless of signal")
        }

        // The power toggle and the rescan are the page's only service calls, and
        // construction must make none of them.
        function test_theNetworkDetailPagePowerToggleCallsTheService() {
            var fake = makeFake(fakeNetworkDetailComponent)
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.wifiToggleItem.width > 0 }, 1000)
            compare(fake.callCount("setWifiEnabled"), 0,
                "construction must not touch radio power")

            page.wifiToggleItem.activate()
            tryCompare(fake, "wifiEnabled", false, 1000)
            compare(fake.callArgs("setWifiEnabled", 0), false,
                "the page asks the service for the state it wants, not the inverse")

            // Pressed again, and the SECOND call is the one under test: the
            // toggle has to ask for "on" now, not repeat "off".
            page.wifiToggleItem.activate()
            tryCompare(fake, "wifiEnabled", true, 1000)
            compare(fake.lastCallArgs("setWifiEnabled", 0), true,
                "the second press asks for power on, not a repeat of power off")
            compare(fake.callCount("setWifiEnabled"), 2)
        }

        function test_theNetworkDetailPageRescanRequestsAFreshRead() {
            var fake = makeFake(fakeNetworkDetailComponent)
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.listItem.width > 0 }, 1000)
            compare(fake.callCount("requestScan"), 0,
                "construction must not scan")

            page.rescan()
            tryVerify(function() { return fake.callCount("requestScan") === 1 }, 1000)
            compare(fake.callArgs("requestScan", 0), true,
                "an explicit rescan asks for a fresh radio scan")
        }

        // Connect on an open network goes straight through, with no password
        // step - the prompt is for secured networks only.
        function test_connectingAnOpenNetworkCallsTheServiceDirectly() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: false, security: "--", signal: 60 }
            ])
            fake.passwordRequiredFor = ""
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.wifiRowCount === 1 }, 1000)
            compare(page.passwordSsid, "",
                "an open network must not raise a password prompt")

            page.activateNetwork("Home")
            tryVerify(function() { return fake.callCount("connect") === 1 }, 1000)
            compare(fake.callArgs("connect", 0), "Home")
            compare(fake.callArgs("connect", 1), "",
                "an open network connects without a password")
            compare(fake.callArgs("connect", 3), "--",
                "the row's own security word rides along, so a profile is created right")
        }

        // The connected row disconnects rather than reconnects.
        function test_tappingTheConnectedNetworkDisconnectsIt() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: true, signal: 78 }
            ])
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.wifiRowCount === 1 }, 1000)

            page.activateNetwork("Home")
            tryVerify(function() { return fake.callCount("disconnect") === 1 }, 1000)
            compare(fake.callArgs("disconnect", 0), "Home")
            compare(fake.callCount("connect"), 0,
                "the connected row must not also try to connect")
        }

        // A secured network collects its password first, and the field owns
        // focus only while it is open. Focus is the part that matters: a field
        // that keeps focus after the prompt closes swallows the next keystroke
        // into a password nobody is looking at.
        function test_aSecuredNetworkPromptsForAPasswordBeforeConnecting() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: false, security: "WPA2", signal: 60 }
            ])
            fake.passwordRequiredFor = "Home"
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.wifiRowCount === 1 }, 1000)
            compare(fake.callCount("connect"), 0)

            page.activateNetwork("Home")
            tryVerify(function() { return page.passwordSsid === "Home" }, 1000)
            compare(fake.callCount("connect"), 0,
                "the prompt must gate the connect, not follow it")
            tryVerify(function() { return page.passwordItem.visible }, 1000)
            tryVerify(function() { return page.passwordItem.activeFocus }, 1000,
                "an open prompt takes focus so the user can just type")

            page.password = "hunter2"
            page.submitPassword()
            tryVerify(function() { return fake.callCount("connect") === 1 }, 1000)
            compare(fake.callArgs("connect", 0), "Home")
            compare(fake.callArgs("connect", 1), "hunter2",
                "the typed password reaches the service")
            tryVerify(function() { return page.passwordSsid === "" }, 1000)
            compare(page.passwordItem.activeFocus, false,
                "a closed prompt must give focus back")
        }

        function test_cancellingThePasswordPromptReleasesFocusAndConnectsNothing() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: false, security: "WPA2" }
            ])
            fake.passwordRequiredFor = "Home"
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.wifiRowCount === 1 }, 1000)
            page.activateNetwork("Home")
            tryVerify(function() { return page.passwordSsid === "Home" }, 1000)

            page.password = "hunter2"
            page.cancelPassword()
            tryVerify(function() { return page.passwordSsid === "" }, 1000)
            compare(page.password, "", "a cancelled secret must not linger in the page")
            compare(page.passwordItem.activeFocus, false)
            compare(fake.callCount("connect"), 0,
                "cancelling changes no network state")
        }

        // A rejected secret is the recovery path, not a dead end: the service's
        // own credential classification decides whether the row asks again.
        function test_aCredentialFailureIsShownInlineAndKeepsThePasswordPathOpen() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: false, security: "WPA2", existing: true }
            ])
            fake.lastError = "Incorrect password"
            fake.lastErrorSsid = "Home"
            fake.credentialFailure = true
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.wifiRowCount === 1 }, 1000)

            compare(page.errorText, "Incorrect password",
                "the service's own classified words, unedited")
            compare(page.errorIsCredential, true)
            verify(page.errorForSsid === "Home",
                "the error has to name the row it belongs to")

            // ...and asking again still opens the prompt instead of failing
            // silently against the rejected profile.
            fake.passwordRequiredFor = "Home"
            page.activateNetwork("Home")
            tryVerify(function() { return page.passwordSsid === "Home" }, 1000)
        }

        // A non-credential failure is reported and offers no recovery that would
        // not work.
        function test_aNonCredentialFailureIsShownWithoutAPasswordPrompt() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: false, security: "WPA2" }
            ])
            fake.lastError = "Connection timeout"
            fake.lastErrorSsid = "Home"
            fake.credentialFailure = false
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.wifiRowCount === 1 }, 1000)

            compare(page.errorText, "Connection timeout")
            compare(page.errorIsCredential, false,
                "a timeout is not a credential problem and must not ask for a password")
        }

        // An in-flight attempt marks its own row, so the user can see which
        // network the shell is working on.
        function test_anInFlightAttemptMarksItsRow() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: false, security: "--" },
                { ssid: "Neighbour 5G", connected: false, security: "--" }
            ])
            fake.passwordRequiredFor = ""
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.wifiRowCount === 2 }, 1000)
            compare(page.busySsid, "")

            fake.connecting = true
            fake.connectingTo = "Neighbour 5G"
            tryVerify(function() { return page.busySsid === "Neighbour 5G" }, 1000)
            var busy = wifiRow(page, "Neighbour 5G")
            verify(busy !== null, "the busy row must be addressable by its own name")
            verify(busy.busy, "the in-flight row is marked busy")
            var idle = wifiRow(page, "Home")
            verify(idle !== null && !idle.busy,
                "an unrelated row must not be marked busy too")
        }

        // A service thinner than documented is the production null case, and it
        // renders a state rather than throwing.
        function test_theNetworkDetailPageSurvivesAThinService() {
            var page = makeNetworkPage({ networkService: makeFake(fakeBareNetworkComponent) })
            tryVerify(function() { return page.width > 0 }, 1000)
            compare(page.errorText, "")
            compare(page.wifiRowCount, 0)
            verify(page.stateLabel.length > 0, "an absent radio must still say so")
            verify(page.listItem.width > 0, "the page must still lay out")

            // Every action is a guarded call, so a bare service cannot throw.
            page.rescan()
            page.setWifiEnabled(true)
            page.activateNetwork("anything")
            page.cancelPassword()
            page.submitPassword()

            // No service at all is the state the production page starts in.
            var none = makeNetworkPage({})
            tryVerify(function() { return none.width > 0 }, 1000)
            none.rescan()
            none.setWifiEnabled(false)
            verify(none.stateLabel.length > 0)
        }

        // The visible list is bounded: a dense band scrolls inside the page
        // instead of stretching the wave surface.
        function test_theNetworkListIsABoundedScrollableArea() {
            var entries = []
            for (var i = 0; i < 40; i++)
                entries.push({ ssid: "Net " + i, security: "WPA2",
                    signal: 40 + i, connected: false })
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), entries)
            var page = makeNetworkPage({ networkService: fake, height: 480 })
            tryVerify(function() { return page.wifiRowCount === 40 }, 2000)
            tryVerify(function() { return page.listItem.height > 0 }, 1000)

            // Every reported network is reachable by row key, not just the first
            // few: the bound is on the VIEWPORT, never on the data.
            var last = wifiRow(page, "Net 39")
            verify(last !== null, "the 40th network must exist as a row target")
            compare(page.listItem.flickableDirection, Flickable.VerticalFlick)
            verify(page.listItem.contentHeight > page.listItem.height,
                "an overlong list must actually scroll")
            verify(page.listItem.height <= page.height,
                "the list may not grow past the page it lives in")
            verify(page.listItem.interactive, "an overlong list takes the wheel")
        }

        // A short list does not swallow the wheel, and nothing scrolls sideways.
        function test_aShortNetworkListDoesNotScroll() {
            var fake = seededNetworkDetail(makeFake(fakeNetworkDetailComponent), [
                { ssid: "Home", connected: true },
                { ssid: "Neighbour 5G", connected: false }
            ])
            var page = makeNetworkPage({ networkService: fake })
            tryVerify(function() { return page.wifiRowCount === 2 }, 1000)
            tryVerify(function() { return page.listItem.height > 0 }, 1000)

            compare(page.listItem.contentHeight <= page.listItem.height, true,
                "a list that already fits has nothing to scroll")
            compare(page.listItem.interactive, false,
                "a list that fits must leave the wheel to the page")
            compare(page.listItem.flickableDirection, Flickable.VerticalFlick,
                "the detail list never scrolls sideways")
            compare(page.listItem.contentWidth, page.listItem.width,
                "horizontal content is pinned to the viewport")
        }

        // --- Bluetooth detail page ---

        function test_theBluetoothDetailPagePublishesTheBackContract() {
            var page = makeBluetoothPage({
                bluetoothService: seededBluetooth(makeFake(fakeBluetoothDetailComponent), []) })
            tryVerify(function() { return page.width > 0 }, 1000)
            compare(page.objectName, "controlCenterBluetoothDetail")
            verify(page.title.length > 0)
            verify(page.description.length > 0)
            compare(page.canGoBack, true)

            var backs = 0
            page.backRequested.connect(function() { backs++ })
            verify(page.handleBack())
            compare(backs, 1)
        }

        function test_theBluetoothDetailPageShowsEveryAdapterStateInline() {
            var states = [
                { name: "no adapter", service: { bluetoothAvailable: false } },
                { name: "blocked", service: { blocked: true } },
                { name: "off", service: { enabled: false } },
                { name: "scanning", service: { scanningActive: true } },
                { name: "on", service: { enabled: true } }
            ]
            // Stated as the five words the page itself computes, so this asserts
            // the module's precedence rather than five hand-typed phrases: a
            // blocked radio outranks "off", and no adapter outranks both.
            var expected = ["unavailable", "blocked", "off", "loading", "ready"]
            for (var i = 0; i < states.length; i++) {
                var fake = makeFake(fakeBluetoothDetailComponent, states[i].service)
                seededBluetooth(fake, i === 0 ? [] : [
                    { name: "Studio Speaker", address: "AA:BB:00:00:00:01",
                      connected: true, paired: true, signalStrength: 80 }])
                var page = makeBluetoothPage({ bluetoothService: fake })
                tryVerify(function() { return page.width > 0 }, 1000)
                compare(page.state, expected[i],
                    "adapter state '" + states[i].name + "' must resolve to its own word")
                verify(page.stateLabel.length > 0,
                    "state '" + states[i].name + "' must render a readable label")
                verify(page.visible, "state '" + states[i].name + "' keeps the page")
                verify(page.deviceListViewportItem.height > 0,
                    "state '" + states[i].name + "' keeps the list's shape")
            }

            // No service at all is the production start state and reports itself
            // rather than throwing.
            var none = makeBluetoothPage({})
            tryVerify(function() { return none.width > 0 }, 1000)
            compare(none.state, "unavailable")
            verify(none.stateLabel.length > 0)
        }

        // An absent adapter is not a missing page: the power control has nothing
        // to switch, so it must not offer to switch it.
        function test_theBluetoothPowerToggleIsInertWithoutAnAdapter() {
            var fake = makeFake(fakeNoAdapterComponent)
            var page = makeBluetoothPage({ bluetoothService: fake })
            tryVerify(function() { return page.powerToggleItem.width > 0 }, 1000)

            compare(page.powerAvailable, false)
            verify(!page.powerToggleItem.enabled,
                "there is no adapter to power, so nothing may be offered")
            compare(page.powerToggleItem.activeFocusOnTab, false)
            compare(page.deviceCount, 0)
        }

        function test_theBluetoothPowerToggleAsksTheServiceToSwitchOff() {
            var fake = makeFake(fakeBluetoothDetailComponent)
            var page = makeBluetoothPage({ bluetoothService: fake })
            tryVerify(function() { return page.powerToggleItem.width > 0 }, 1000)
            compare(page.powerAvailable, true)
            compare(fake.calls.length, 0, "construction must not touch adapter power")

            page.powerToggleItem.activate()
            tryCompare(fake, "enabled", false, 1000)
            verify(fake.calls.length > 0 && fake.calls[0].name === "setBluetoothEnabled")
            compare(fake.calls[0].args[0], false,
                "the page asks for the state it wants, not the inverse")
        }

        function test_theBluetoothScanButtonStartsTheServiceScan() {
            var fake = makeFake(fakeBluetoothDetailComponent)
            var page = makeBluetoothPage({ bluetoothService: fake })
            tryVerify(function() { return page.scanButtonItem.width > 0 }, 1000)
            compare(fake.callCount("startScan"), 0, "construction must not scan")

            page.scanButtonItem.activate()
            tryVerify(function() { return fake.callCount("startScan") === 1 }, 1000)
        }

        // Every device action routes to the service method that owns it. One
        // table, four cases, because these four are exactly the states a device
        // can be in and a mixed-up dispatch is invisible until it does damage.
        function test_everyDeviceActionRoutesToItsOwnServiceMethod() {
            var unpaired = { name: "New Speaker", address: "AA:BB:00:00:00:02",
                connected: false, paired: false, trusted: false }
            var paired = { name: "Studio Speaker", address: "AA:BB:00:00:00:01",
                connected: false, paired: true, trusted: true }
            var connected = { name: "Headphones", address: "AA:BB:00:00:00:03",
                connected: true, paired: true, trusted: true }
            var fake = seededBluetooth(makeFake(fakeBluetoothDetailComponent),
                [unpaired, paired, connected])
            var page = makeBluetoothPage({ bluetoothService: fake })
            tryVerify(function() { return page.deviceCount === 3 }, 1000)

            page.activateDevice("AA:BB:00:00:00:02")
            tryVerify(function() { return fake.callCount("pairDevice") === 1 }, 1000)
            compare(fake.callCount("connectDeviceWithTrust"), 0,
                "an unpaired device is paired, never connected blind")

            page.activateDevice("AA:BB:00:00:00:01")
            tryVerify(function() { return fake.callCount("connectDeviceWithTrust") === 1 }, 1000)
            compare(fake.callCount("pairDevice"), 1,
                "a paired device connects; the earlier pair must not repeat")

            page.activateDevice("AA:BB:00:00:00:03")
            tryVerify(function() { return fake.callCount("disconnectDevice") === 1 }, 1000)
            compare(fake.callCount("connectDeviceWithTrust"), 1,
                "a connected device disconnects; it must not also reconnect")
        }

        function test_forgettingADeviceIsASeparateExplicitAction() {
            var paired = { name: "Studio Speaker", address: "AA:BB:00:00:00:01",
                connected: false, paired: true, trusted: true }
            var fake = seededBluetooth(makeFake(fakeBluetoothDetailComponent), [paired])
            var page = makeBluetoothPage({ bluetoothService: fake })
            tryVerify(function() { return page.deviceCount === 1 }, 1000)

            // Forget is not the primary row action: it is destructive, so it
            // lives behind its own target and never rides the connect path.
            page.forgetDevice("AA:BB:00:00:00:01")
            tryVerify(function() { return fake.callCount("forgetDevice") === 1 }, 1000)
            compare(fake.callCount("connectDeviceWithTrust"), 0,
                "forgetting a device must not also connect it")

            // And that target is offered at all. This assertion exists because the
            // button's gate once came out `undefined` and left it permanently
            // disabled, while every dispatch check above still passed - a
            // destructive action that could not be reached.
            var row = bluetoothRow(page, "AA:BB:00:00:00:01")
            verify(row !== null)
            compare(page.isForgetable(row.device), true,
                "a live device may be forgotten")
            verify(row.forgetButton.visible && row.forgetButton.width > 0,
                "the Forget target must actually exist on the row")
            compare(row.forgetButton.enabled, true,
                "the Forget target must be enabled for a live device")
            compare(row.forgetButton.opacity, 1,
                "an enabled Forget target must not render in the disabled shape")
        }

        // A device mid-pairing offers nothing at all, so neither target does.
        function test_aBusyDeviceOffersNeitherTarget() {
            var fake = seededBluetooth(makeFake(fakeBluetoothDetailComponent), [
                { name: "Studio Speaker", address: "AA:BB:00:00:00:01",
                    connected: false, paired: true, trusted: true, pairing: true }])
            var page = makeBluetoothPage({ bluetoothService: fake })
            tryVerify(function() { return page.deviceCount === 1 }, 1000)

            var row = bluetoothRow(page, "AA:BB:00:00:00:01")
            verify(row !== null)
            compare(page.isForgetable(row.device), false,
                "nothing may be forgotten while the adapter is working on it")
            compare(row.forgetButton.enabled, false,
                "a mid-pairing device must not offer Forget")
            verify(!row.deviceActionButton.enabled,
                "nor the primary action, or a second call would race the first")
        }

        // A device row is addressed by the adapter's own stable key, never by
        // its position: a scan that returns the same devices in a different
        // order must not turn the action buttons around.
        function test_deviceRowsAreAddressedByAStableKey() {
            var first = { name: "Studio Speaker", address: "AA:BB:00:00:00:01",
                connected: true, paired: true, signalStrength: 80 }
            var second = { name: "Headphones", address: "AA:BB:00:00:00:03",
                connected: false, paired: true, signalStrength: 40 }
            var fake = seededBluetooth(makeFake(fakeBluetoothDetailComponent), [first, second])
            var page = makeBluetoothPage({ bluetoothService: fake })
            tryVerify(function() { return page.deviceCount === 2 }, 1000)

            var row = bluetoothRow(page, "AA:BB:00:00:00:01")
            verify(row !== null, "the connected device must be addressable by its address")
            compare(String(row.rowKey), "AA:BB:00:00:00:01")
            compare(row.rowLabel, "Studio Speaker")
            verify(bluetoothRow(page, "nope") === null,
                "an unknown key resolves to no row rather than to the first one")

            // Reordering the adapter's list keeps every key pointing at the same
            // device, which is the whole point of keying on the address.
            seededBluetooth(fake, [second, first])
            tryVerify(function() { return page.deviceCount === 2 }, 1000)
            var swapped = bluetoothRow(page, "AA:BB:00:00:00:01")
            verify(swapped !== null && swapped.rowLabel === "Studio Speaker",
                "a reordering must not move an action onto another device")
        }

        function test_aBusyDeviceRefusesEveryAction() {
            var busy = { name: "Studio Speaker", address: "AA:BB:00:00:00:01",
                connected: false, paired: true, trusted: true, pairing: true }
            var fake = seededBluetooth(makeFake(fakeBluetoothDetailComponent), [busy])
            var page = makeBluetoothPage({ bluetoothService: fake })
            tryVerify(function() { return page.deviceCount === 1 }, 1000)

            var row = bluetoothRow(page, "AA:BB:00:00:00:01")
            verify(row !== null)
            verify(row.busy, "the service's own busy answer drives the row")
            page.activateDevice("AA:BB:00:00:00:01")
            page.forgetDevice("AA:BB:00:00:00:01")
            compare(fake.calls.length, 0,
                "a device mid-pairing accepts nothing; a second call would race the first")
        }

        function test_theBluetoothDetailPageRendersEveryDeviceState() {
            var fake = seededBluetooth(makeFake(fakeBluetoothDetailComponent), [
                { name: "Studio Speaker", address: "AA:BB:00:00:00:01",
                    connected: true, paired: true, signalStrength: 80 },
                { name: "Headphones", address: "AA:BB:00:00:00:03",
                    connected: false, paired: true, signalStrength: null },
                { name: "New Keyboard", address: "AA:BB:00:00:00:04",
                    connected: false, paired: false }
            ])
            var page = makeBluetoothPage({ bluetoothService: fake })
            tryVerify(function() { return page.deviceCount === 3 }, 1000)

            var connected = bluetoothRow(page, "AA:BB:00:00:00:01")
            var paired = bluetoothRow(page, "AA:BB:00:00:00:03")
            var fresh = bluetoothRow(page, "AA:BB:00:00:00:04")
            verify(connected !== null && paired !== null && fresh !== null)
            verify(connected.connected, "a connected row says so")
            verify(!paired.connected)
            // An unknown signal strength renders as unknown, not as zero bars -
            // "0%" on a device that never reported strength is a false reading.
            compare(paired.signalPercent, -1)
            compare(connected.signalPercent, 80)
            verify(fresh.signalPercent === -1)
            verify(connected.rowIcon.length > 0,
                "the service's own icon mapping is used, not a local guess")
        }

        function test_theBluetoothDeviceListIsABoundedScrollableArea() {
            var devices = []
            for (var i = 0; i < 30; i++)
                devices.push({ name: "Device " + i,
                    address: "AA:BB:00:00:00:" + (10 + i),
                    connected: false, paired: false })
            var fake = seededBluetooth(makeFake(fakeBluetoothDetailComponent), devices)
            var page = makeBluetoothPage({ bluetoothService: fake, height: 480 })
            tryVerify(function() { return page.deviceCount === 30 }, 2000)
            tryVerify(function() { return page.deviceListItem.height > 0 }, 1000)

            verify(bluetoothRow(page, "AA:BB:00:00:00:39") !== null,
                "the 30th device must exist as a row target")
            compare(page.deviceListItem.flickableDirection, Flickable.VerticalFlick)
            verify(page.deviceListItem.contentHeight > page.deviceListItem.height,
                "an overlong device list must actually scroll")
            verify(page.deviceListItem.height <= page.height,
                "the list may not grow past the page it lives in")
        }

        function test_aShortBluetoothDeviceListDoesNotScroll() {
            var fake = seededBluetooth(makeFake(fakeBluetoothDetailComponent), [
                { name: "Studio Speaker", address: "AA:BB:00:00:00:01",
                    connected: true, paired: true, signalStrength: 80 }])
            var page = makeBluetoothPage({ bluetoothService: fake })
            tryVerify(function() { return page.deviceCount === 1 }, 1000)
            tryVerify(function() { return page.deviceListItem.height > 0 }, 1000)

            compare(page.deviceListItem.contentHeight <= page.deviceListItem.height, true)
            compare(page.deviceListItem.interactive, false)
            compare(page.deviceListItem.flickableDirection, Flickable.VerticalFlick)
        }

        // No adapter, no scan, no devices: the real production state of a
        // machine with no Bluetooth hardware, which must not throw.
        function test_theBluetoothDetailPageSurvivesAnAbsentAdapter() {
            var page = makeBluetoothPage({ bluetoothService: makeFake(fakeNoAdapterComponent) })
            tryVerify(function() { return page.width > 0 }, 1000)
            compare(page.deviceCount, 0)
            compare(page.powerAvailable, false)
            verify(page.stateLabel.length > 0)
            verify(page.visible, "an absent adapter keeps the page legible")

            // Every action is guarded, so a bare service cannot throw.
            page.scan()
            page.setBluetoothEnabled(true)
            page.activateDevice("anything")
            page.forgetDevice("anything")

            // No service at all is what the production page starts with.
            var none = makeBluetoothPage({})
            tryVerify(function() { return none.width > 0 }, 1000)
            none.scan()
            verify(none.stateLabel.length > 0)
        }

        // --- Acceptance: optional services, narrow geometry, route defaults ---

        // The brief's optional-service acceptance case: three services all
        // reporting themselves unavailable at once still leave the whole overview
        // usable (acceptance 7, "Optional service failures leave the rest of the
        // surface usable").
        //
        // Assigned onto a LIVE page rather than into the constructor. Three failing
        // at construction is one shape; a service that answered correctly on mount
        // and then stops answering is the real one, and a constructor-only fixture
        // would pass even if the page read each optional service once at
        // construction and cached the answer forever.
        function test_optionalServicesDoNotBlockOverview() {
            var page = makePage({
                networkService: seededNetwork(makeFake(fakeNetworkComponent), [
                    { ssid: "Home", connected: true }]),
                weatherService: makeFake(fakeWeatherComponent),
                batteryService: makeFake(fakeBatteryComponent)
            })
            tryVerify(function() { return page.visible && page.controlCardCount === 4 }, 1000)
            // Pinned first, so the fixture is proved to have been the healthy one:
            // without these the assertions below would also pass on a page whose
            // weather header had never rendered.
            compare(page.weatherState, "ready")
            compare(page.networkCard.status, "ready")
            compare(page.networkCard.summary, "Home")

            page.weatherService = makeFake(fakeWeatherComponent, {
                available: false, loading: false, temperature: Number.NaN,
                isStale: false, lastError: "DNS lookup failed" })
            page.batteryService = makeFake(fakeBatteryComponent, {
                available: false, ready: false, percentage: 0, charging: false,
                pluggedIn: false, iconText: "" })
            page.networkService = makeFake(fakeNetworkComponent, {
                wifiEnabled: true, wifiConnected: false, networks: ({}),
                lastError: "NetworkManager is not responding" })

            // The brief's assertion, verbatim in intent: still on screen, still
            // exactly the four core controls.
            tryVerify(function() { return page.visible && page.controlCardCount === 4 }, 1000)

            // Each failure lands on its own card or its own header band, and on
            // nothing else: no service's failure removed the header, a sibling
            // card, or the information column.
            compare(page.weatherState, "unavailable")
            compare(page.networkCard.status, "error")
            compare(page.networkCard.error, "NetworkManager is not responding")
            compare(page.batteryReady, false)
            verify(page.clockTextItem.text.length > 0,
                "the clock is local time, not a service: it must not go blank")
            verify(page.batteryTextItem.text.length > 0,
                "an absent battery renders a word, not an empty band")
            verify(page.calendarItem.visible,
                "the calendar is local date math and must survive every failure")
            compare(page.entryCount, 0)
            for (var i = 0; i < page.controlCards.length; i++)
                verify(page.controlCards[i].visible,
                    "card " + i + " stays painted while another service has failed")

            // ...and the cards whose services did NOT fail are still actionable,
            // which is the half of acceptance 7 that "still renders" misses.
            var volume = makeFake(fakeVolumeComponent)
            var media = makeFake(fakeMediaComponent)
            page.volumeService = volume
            page.mediaService = media
            tryCompare(page.volumeCard, "status", "ready", 500)
            tryCompare(page.mediaCard, "status", "ready", 500)
            page.toggleMute()
            compare(volume.muteCalls, 1,
                "volume stays directly actionable next to two failed services")
            page.mediaAction("next")
            compare(media.nextCalls, 1,
                "media stays directly actionable next to two failed services")

            // The failed network card is inert, not broken: no detail page may be
            // mounted for a service that reported an error.
            var requests = 0
            page.networkDetailsRequested.connect(function() { requests++ })
            page.openNetworkDetails()
            compare(requests, 0, "a failed card must not hand off to its detail page")
            compare(page.activeSubPage, "")
        }

        // The narrow half of acceptance 4: "The narrow layout remains usable
        // without horizontal scrolling" is only half a claim unless the controls
        // are still ON SCREEN. A stack that quietly dropped the media card below a
        // scroll limit would keep every scroll assertion green.
        //
        // The width here is deliberately far below the module's 760px breakpoint,
        // so this is the worst case rather than the boundary.
        function test_everyCoreCardStaysReachableInTheNarrowLayout() {
            var page = makePage({
                width: 420, height: 1600,
                // Healthy services, so "reachable" can mean enabled rather than
                // merely present: an inert control on a collapsed row looks
                // identical to a working one in a geometry assertion.
                volumeService: makeFake(fakeVolumeComponent),
                mediaService: makeFake(fakeMediaComponent)
            })
            tryVerify(function() { return page.layoutMode === "narrow" }, 1000)
            tryVerify(function() { return page.mediaCard.width > 0 }, 1000)
            verify(420 < CcLogic.minimumTwoColumnWidth,
                "the fixture must actually be below the two-column breakpoint")

            compare(page.controlCardCount, 4)
            for (var i = 0; i < page.controlCards.length; i++) {
                var card = page.controlCards[i]
                verify(card.visible, "card " + i + " must stay visible when stacked")
                verify(card.width > 0 && card.height > 0, "card " + i + " must keep a real box")
                // The spec's own floor: reachable "without reducing interactive
                // targets to an unusable size". 48px is the bar's target size
                // (LazerTheme.targetSize), and the cards are declared at 88.
                verify(card.height >= 48,
                    "card " + i + " is " + card.height + "px tall, under a usable target")
                verify(card.width >= 48, "card " + i + " is only " + card.width + "px wide")
                var left = card.mapToItem(page, 0, 0).x
                verify(left >= -0.5 && left + card.width <= page.width + 0.5,
                    "card " + i + " leaves the narrow panel horizontally")
            }

            // The two DIRECT controls have to be reachable too, not just framed:
            // a card can keep its box while the control inside it collapses.
            verify(page.volumeSliderItem.width > 0, "the volume slider survives the stack")
            verify(page.volumeSliderItem.height > 0)
            verify(page.muteButtonItem.width > 0 && page.muteButtonItem.height > 0)
            compare(page.muteButtonItem.enabled, true)
            var ids = ["previous", "toggle", "next"]
            for (var j = 0; j < ids.length; j++) {
                var button = page.transportItem(ids[j])
                verify(button !== null, "transport " + ids[j] + " survives the stack")
                verify(button.width > 0 && button.height > 0)
                compare(button.enabled, true,
                    "transport " + ids[j] + " must stay actionable when stacked")
            }

            // And the stack still has exactly one scroll surface, vertical only.
            var scrollers = scrollContainers(page)
            compare(scrollers.length, 1, "the page has exactly one scroll surface")
            compare(scrollers[0].flickableDirection, Flickable.VerticalFlick)
        }

        // The route default, asserted from the live page rather than from the
        // module: the host decides what a route page looks like from `title`,
        // `description`, `sidebarEntries`, `activeSidebarId`, `canGoBack`,
        // `focusDefault()` and `handleBack()`, so a page that drifted on any of
        // them would render the launcher's chrome on the control center.
        //
        // The empty rail is the load-bearing half: with entries, the shared host
        // mounts FullscreenSidebar and every section of the page loses 196px of
        // width - which is exactly what would break the B1 two-column layout.
        function test_theRoutePageContractIsWhatTheSharedHostReads() {
            var page = makePage({ width: 900, height: 720 })
            tryVerify(function() { return page.layoutMode === "wide" }, 1000)

            compare(page.title, "Control Center")
            compare(page.description.length > 0, true)
            compare(page.sidebarEntries.length, 0,
                "an entry here would steal the B1 layout's right column")
            compare(page.activeSidebarId, "")

            // Every section the wide arrangement names must resolve to a real,
            // shown item - the overview band plus both columns. `visibleSectionCount`
            // is deliberately not asked here: it counts the module's STACKED order,
            // which is empty by construction in the wide arrangement.
            var wideNames = ["overview"].concat(page.sections.left, page.sections.right)
            compare(wideNames.length, 4)
            for (var i = 0; i < wideNames.length; i++) {
                var item = page.sectionItem(wideNames[i])
                verify(item !== null, "wide section " + wideNames[i] + " must resolve")
                verify(item.visible, "wide section " + wideNames[i] + " must be shown")
            }

            // Back precedence, from the live page: nothing to pop on the overview,
            // one step to pop while a detail page is mounted, and a real refusal
            // in between so the host's fall-through-to-close stays reachable.
            compare(page.canGoBack, false)
            compare(page.handleBack(), false, "the overview declines back")
            page.requestSubPage(CcLogic.detailRoutes.network)
            tryVerify(function() { return page.activeSubPage !== "" }, 500)
            compare(page.canGoBack, true)
            compare(page.handleBack(), true, "a mounted sub-page consumes back")
            tryVerify(function() { return page.canGoBack === false }, 500)

            // An unknown sub-page name mounts nothing, so a caller typo cannot
            // produce a blank viewport that looks like a load failure.
            compare(page.requestSubPage("nope"), false)
            compare(page.activeSubPage, "")
        }
    }
}