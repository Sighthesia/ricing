import QtQuick
import "ControlCenterLogic.js" as CcLogic
import "../../services" as Services

// Same-surface Bluetooth detail page: a sub-page of the control-center route,
// not a sibling Wave route.
//
// It is MOUNTED INSIDE ControlCenter, which owns the wave host's single retained
// Loader, so this file creates no window and opens no overlay. Escape is the
// host's to route: the page publishes `canGoBack` plus a `handleBack()` and
// answers with `backRequested()` for the owner to pop it.
//
// Every read goes through the injected `bluetoothService` and every write is one
// call into one of its existing methods. There is no second Bluetooth
// implementation here: no bluetoothctl, no process, no adapter handling. The
// service owns pairing, trust and the device's own state; this page decides
// only how a state looks and which single action each row offers.
//
// Sharp language: right-angled row surfaces, state as square colour bars,
// motion from MotionTokens only.
Item {
    id: root
    objectName: "controlCenterBluetoothDetail"

    // --- Injected service seam ---
    //
    // Null is the production state until the wiring task passes
    // Services.BluetoothService, and it renders an explicit state rather than
    // throwing.

    property var bluetoothService: null

    // --- Sub-page contract ---
    //
    // A constant `true`, for the same reason the network page's is: only the
    // host's Escape routing decides whether the press arrives.

    readonly property bool canGoBack: true

    signal backRequested()

    readonly property string detailRoute: CcLogic.detailRoutes.bluetooth

    // Host chrome for this sub-page, in the same shape the overview publishes.
    readonly property string title: Services.Tr.q("cc.bluetooth.title")
    readonly property string description: Services.Tr.q("cc.bluetooth.description")
    readonly property var sectionEntries: []
    readonly property string activeSectionId: ""

    function focusDefault() { root.forceActiveFocus() }

    // Never returns false: a decline would let the host close the whole surface
    // instead of popping this page.
    function handleBack() {
        root.backRequested()
        return true
    }

    // --- Fixed geometry tokens ---

    readonly property real pagePadding: 24
    readonly property real sectionGap: 18
    readonly property real rowGap: 6
    readonly property real rowHeight: 44
    readonly property real sectionTitleHeight: 20
    readonly property real actionHeight: 28
    readonly property real powerRowHeight: 44

    // The bounded list budget. A long paired-device history scrolls inside the
    // page instead of growing the wave surface.
    readonly property real maxListHeight: 300

    // --- Service snapshot ---
    //
    // An adapter that does not exist is unavailable; one that is rfkilled or
    // powered off is still a PRESENT adapter, so it reports through
    // enabled/blocked and stays legible instead of going inert.

    readonly property bool serviceAvailable: root.bluetoothService !== null
    readonly property bool adapterAvailable: root.bluetoothService
            && root.bluetoothService.bluetoothAvailable !== false
    readonly property bool enabled: root.bluetoothService
            && root.bluetoothService.enabled === true
    readonly property bool blocked: root.bluetoothService
            && root.bluetoothService.blocked === true
    readonly property bool scanningActive: root.bluetoothService
            && root.bluetoothService.scanningActive === true

    // Whether the power control has anything to switch. An absent adapter has no
    // power switch, so offering one would be a target that cannot do anything.
    readonly property bool powerAvailable: root.serviceAvailable && root.adapterAvailable

    readonly property int connectedCount: {
        var list = root.bluetoothService ? root.bluetoothService.connectedDevices : null
        if (list == null || typeof list.length !== "number")
            return 0
        var total = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i] != null && list[i].connected === true)
                total++
        }
        return total
    }

    // --- One state word for the whole page ---
    //
    // The module's own vocabulary in the module's precedence. A report, never a
    // gate: no adapter, rfkill or a powered-down radio all keep the page laid out
    // and explain themselves.
    readonly property string state: !root.serviceAvailable ? "unavailable"
        : (!root.adapterAvailable ? "unavailable"
            : (root.blocked ? "blocked"
                : (!root.enabled ? "off"
                    : (root.scanningActive ? "loading"
                        : (root.deviceList.length === 0 ? "empty" : "ready")))))
    readonly property string stateLabel: {
        if (!root.serviceAvailable)
            return Services.Tr.q("cc.bluetooth.unavailable")
        if (!root.adapterAvailable)
            return Services.Tr.q("cc.bluetooth.noAdapterLong")
        if (root.blocked)
            return Services.Tr.q("cc.bluetooth.blocked")
        if (!root.enabled)
            return Services.Tr.q("cc.bluetooth.off")
        if (root.scanningActive)
            return Services.Tr.q("cc.bluetooth.scanning")
        if (root.deviceList.length === 0)
            return Services.Tr.q("cc.card.noDevices")
        return root.connectedCount > 0
            ? Services.Tr.n("cc.bluetooth.connectedCount", root.connectedCount)
            : Services.Tr.n("cc.bluetooth.deviceCount", root.deviceList.length)
    }

    // --- Devices ---
    //
    // The service hands over a list object with `.values`, which is what
    // BluetoothAdapter.devices is; a plain array is accepted too so a test fake
    // can be simple. Connected first, then by the service's own sortDevices()
    // when it offers one, then by name - so a device row never reorders between
    // two paints of the same list.
    readonly property var deviceList: {
        var service = root.bluetoothService
        if (!service)
            return []
        var raw = service.devices
        if (raw == null)
            return []
        var values = raw.values != null ? raw.values : raw
        if (values == null || typeof values.length !== "number")
            return []
        var list = []
        for (var i = 0; i < values.length; i++) {
            if (values[i] != null)
                list.push(values[i])
        }
        if (typeof service.sortDevices === "function")
            list = service.sortDevices(list)
        list.sort(function (a, b) {
            var aConn = a.connected === true ? 1 : 0
            var bConn = b.connected === true ? 1 : 0
            if (aConn !== bConn)
                return bConn - aConn
            return root.deviceName(a).localeCompare(root.deviceName(b))
        })
        return list
    }
    readonly property int deviceCount: root.deviceList.length
    readonly property int deviceContentHeight: root.deviceCount * root.rowHeight
            + Math.max(0, root.deviceCount - 1) * root.rowGap

    function deviceName(device) {
        if (device == null)
            return ""
        if (device.name != null && String(device.name) !== "")
            return String(device.name)
        if (device.deviceName != null && String(device.deviceName) !== "")
            return String(device.deviceName)
        return String(device.address == null ? "" : device.address)
    }

    // The adapter's own stable key, preferred over a name so two devices called
    // "Speaker" cannot collide, and over an index so a rescan that reorders the
    // list cannot move a row's action onto a different device.
    function deviceKey(device, index) {
        var service = root.bluetoothService
        if (service && typeof service.deviceKey === "function") {
            var key = String(service.deviceKey(device))
            if (key !== "")
                return key
        }
        if (device != null && device.address != null && String(device.address) !== "")
            return String(device.address)
        var name = root.deviceName(device)
        return name !== "" ? name : String(index)
    }

    // Signal as a percentage, or -1 for unknown. The service owns the mapping;
    // an unknown strength is reported as unknown rather than as 0%, which would
    // be a reading the adapter never made.
    readonly property int signalUnknown: -1

    function deviceSignalPercent(device) {
        var service = root.bluetoothService
        if (!service || typeof service.getSignalPercent !== "function")
            return root.signalUnknown
        var percent = service.getSignalPercent(device)
        if (percent == null)
            return root.signalUnknown
        var number = Number(percent)
        if (!isFinite(number))
            return root.signalUnknown
        return Math.round(Math.max(0, Math.min(100, number)))
    }

    function deviceIcon(device) {
        var service = root.bluetoothService
        if (service && typeof service.getDeviceIcon === "function")
            return String(service.getDeviceIcon(device))
        return ""
    }

    // The service owns all three capability questions and the busy question, so
    // a row's single action cannot disagree with what the adapter would accept.
    readonly property bool adapterEnabled: root.serviceAvailable && root.adapterAvailable

    function deviceBusy(device) {
        var service = root.bluetoothService
        if (!service || typeof service.isDeviceBusy !== "function")
            return false
        return service.isDeviceBusy(device) === true
    }

    // The ONE action a row offers, in the order the states actually occur: a
    // connected device disconnects, a paired one connects, an unpaired one
    // pairs. Three states, three targets, never two live at once.
    function deviceAction(device) {
        if (device == null)
            return "none"
        if (root.deviceBusy(device))
            return "none"
        var service = root.bluetoothService
        if (!service)
            return "none"
        if (typeof service.canDisconnect === "function"
                && service.canDisconnect(device) === true)
            return "disconnect"
        if (typeof service.canConnect === "function"
                && service.canConnect(device) === true)
            return "connect"
        if (typeof service.canPair === "function"
                && service.canPair(device) === true)
            return "pair"
        return "none"
    }

    readonly property var actionLabels: ({
        "pair": Services.Tr.q("cc.bluetooth.pair"),
        "connect": Services.Tr.q("common.connect"),
        "disconnect": Services.Tr.q("common.disconnect"),
        "none": ""
    })

    // Whether a row may offer Forget: exactly "has a live action". deviceAction()
    // already answers "none" for a busy device, so the busy test is NOT repeated
    // here - two copies of one rule are where they diverge.
    //
    // The single source of that answer. The Forget button asks this rather than
    // reading a delegate property, which on this Qt build could be handed
    // `undefined` on its first assignment and leave the button permanently
    // disabled; and no delegate property duplicates it, because a second copy of
    // this rule is exactly how the two would drift apart.
    function isForgetable(device) {
        return root.deviceAction(device) !== "none"
    }

    function actionLabel(action) {
        return String(root.actionLabels[action] == null ? "" : root.actionLabels[action])
    }

    // --- Actions ---
    //
    // Each is one guarded call into an existing service method. The guards are
    // not padding: the production page starts with a null service.

    function setBluetoothEnabled(state) {
        if (!root.bluetoothService
                || typeof root.bluetoothService.setBluetoothEnabled !== "function")
            return
        root.bluetoothService.setBluetoothEnabled(state === true)
    }

    function scan() {
        if (!root.bluetoothService || typeof root.bluetoothService.startScan !== "function")
            return
        root.bluetoothService.startScan()
    }

    // The row's single action. Dispatched through deviceAction() rather than
    // re-asked here, so a tap and a paint can never disagree about what the row
    // would have done.
    function activateDevice(key) {
        var device = root.deviceFor(key)
        if (device === null)
            return
        var action = root.deviceAction(device)
        if (action === "none")
            return
        var service = root.bluetoothService
        if (action === "disconnect" && typeof service.disconnectDevice === "function")
            service.disconnectDevice(device)
        else if (action === "connect" && typeof service.connectDeviceWithTrust === "function")
            service.connectDeviceWithTrust(device)
        else if (action === "pair" && typeof service.pairDevice === "function")
            service.pairDevice(device)
    }

    // Forget is destructive, so it is a SEPARATE explicit target that never
    // rides the primary action: losing a device by tapping its connect button
    // would not be recoverable.
    function forgetDevice(key) {
        var device = root.deviceFor(key)
        if (device === null || root.deviceBusy(device))
            return
        var service = root.bluetoothService
        if (!service || typeof service.forgetDevice !== "function")
            return
        service.forgetDevice(device)
    }

    // The device behind a stable key, resolved from the page's own list rather
    // than from a raw index, so an activation and a paint always act on the same
    // record.
    function deviceFor(key) {
        var list = root.deviceList
        var target = String(key)
        for (var i = 0; i < list.length; i++) {
            if (String(root.deviceKey(list[i], i)) === target)
                return list[i]
        }
        return null
    }

    implicitWidth: 640
    implicitHeight: 520

    // The page's vertical scroller, pinned to the viewport's width so the panel
    // can never scroll sideways.
    Flickable {
        id: pageFlick
        objectName: "bluetoothPageFlick"
        x: root.pagePadding
        y: root.pagePadding
        width: Math.max(0, root.width - root.pagePadding * 2)
        height: Math.max(0, root.height - y - root.pagePadding)
        contentWidth: width
        contentHeight: pageContent.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        // Unqualified for the same reason the network page's is: reading the
        // height back through the parent is not assigned yet during construction.
        interactive: contentHeight > height

        // The content box every section is placed in, declared explicitly so the
        // sections do not land on the Flickable's own built-in content item.
        Item {
            id: pageContent
            objectName: "bluetoothPageContent"
            width: pageFlick.width
            height: deviceSection.y + deviceSection.height

            // --- Adapter state ---
            //
            // One read-only line: which of the four states the radio is in, in
            // the module's own vocabulary.
            Text {
                id: stateLabel
                x: 0
                y: 0
                width: parent.width
                height: implicitHeight
                text: root.stateLabel
                color: root.state === "unavailable" || root.state === "off"
                      || root.state === "blocked"
                    ? LazerTheme.textMuted : LazerTheme.textPrimary
                font.pixelSize: 15
                font.weight: Font.DemiBold
                elide: Text.ElideRight

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            // --- Power + scan ---
            //
            // One square row: the settings panel's own power capsule and a scan
            // target. Both are disabled where they could not work - no adapter, a
            // powered-down radio, a scan already running - so neither ever
            // presents a button that does nothing.
            Rectangle {
                id: powerRow
                objectName: "bluetoothPowerRow"
                x: 0
                y: stateLabel.height + root.sectionGap
                width: parent.width
                height: root.powerRowHeight
                radius: 0
                color: powerHover.hovered && root.powerAvailable
                      ? LazerTheme.settingsCardHover : LazerTheme.settingsCard

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                Image {
                    id: powerGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: LazerTheme.iconSize
                    height: LazerTheme.iconSize
                    source: "../bar/icons/bluetooth.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: root.powerAvailable ? 1 : LazerTheme.settingsDisabledAlpha
                }

                Text {
                    id: powerText
                    anchors.left: powerGlyph.right
                    anchors.leftMargin: 10
                    anchors.right: scanButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.blocked ? Services.Tr.q("cc.bluetooth.blocked")
                        : (root.adapterAvailable ? Services.Tr.q("cc.bluetooth.title")
                           : Services.Tr.q("cc.bluetooth.noAdapter"))
                    color: LazerTheme.textPrimary
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                // Scan: one bounded one-shot through the service, disabled while
                // a scan is already running or the radio is off.
                Rectangle {
                    id: scanButton
                    objectName: "bluetoothScanButton"
                    anchors.right: powerToggle.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    height: 26
                    radius: 0
                    color: scanHover.hovered ? LazerTheme.settingsCardHover : "transparent"
                    enabled: root.powerAvailable && root.enabled && !root.scanningActive
                    opacity: enabled ? 1 : LazerTheme.settingsDisabledAlpha
                    activeFocusOnTab: enabled
                    Accessible.role: enabled ? Accessible.Button : Accessible.StaticText
                    Accessible.name: root.scanningActive
                        ? Services.Tr.q("cc.bluetooth.scanningA11y")
                        : Services.Tr.q("cc.bluetooth.scanForDevices")

                    // The one activation path, so a key press, a click and a probe
                    // cannot diverge.
                    function activate() {
                        if (!scanButton.enabled)
                            return
                        root.scan()
                    }

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: root.scanningActive
                              ? Services.Tr.q("cc.bluetooth.scanning")
                              : Services.Tr.q("cc.bluetooth.scan")
                        color: root.scanningActive ? LazerTheme.settingsAccent
                                                  : LazerTheme.textPrimary
                        font.pixelSize: 11
                    }

                    HoverHandler { id: scanHover; enabled: scanButton.enabled }
                    TapHandler { enabled: scanButton.enabled; onTapped: scanButton.activate() }
                    Keys.onPressed: event => {
                        if (!scanButton.enabled)
                            return
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space) {
                            scanButton.activate()
                            event.accepted = true
                        }
                    }
                }

                // The settings panel's own toggle, so adapter power looks like
                // every other power switch in the shell. No adapter, nothing to
                // switch: it is disabled rather than offering a dead action.
                LazerSettingsToggle {
                    id: powerToggle
                    objectName: "bluetoothPowerToggle"
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.enabled
                    enabled: root.powerAvailable
                    accessibleName: Services.Tr.q("cc.bluetooth.title")
                    onToggled: function (value) { root.setBluetoothEnabled(value) }
                }

                // The row's own hover observer. It watches without blocking, so
                // the power capsule and the scan target keep every pointer event -
                // the failure mode the settings panel's row catcher exists to
                // avoid.
                HoverHandler { id: powerHover; enabled: root.powerAvailable }
            }

            // --- Device list section ---
            //
            // The bounded scrollable area: `min(needed, budget)`. An empty list
            // occupies one reserved row so the page keeps its shape.
            Column {
                id: deviceSection
                objectName: "bluetoothDeviceSection"
                x: 0
                y: powerRow.y + powerRow.height + root.sectionGap
                width: parent.width
                spacing: root.rowGap

                // Section header: the device count, so a bounded viewport never
                // hides that the list continues below.
                //
                // Explicit offsets rather than a Row, because a positioner refuses
                // anchors on its children outright and would stack these three.
                Item {
                    id: deviceHeader
                    objectName: "bluetoothSectionHeader"
                    width: parent.width
                    height: root.sectionTitleHeight

                    Rectangle {
                        id: deviceHeaderBar
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 12
                        color: LazerTheme.settingsAccent
                        opacity: root.deviceCount > 0 ? 1 : 0

                        Behavior on opacity {
                            enabled: !MotionTokens.reducedMotion
                            NumberAnimation { duration: MotionTokens.fast }
                        }
                    }

                    Text {
                        id: deviceHeaderTitle
                        x: deviceHeaderBar.width + 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: Services.Tr.q("cc.bluetooth.devices")
                        color: LazerTheme.textPrimary
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        id: deviceHeaderCount
                        x: deviceHeaderTitle.x + deviceHeaderTitle.width + 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.deviceCount > 0 ? String(root.deviceCount) : ""
                        color: LazerTheme.textMuted
                        font.pixelSize: 11
                        visible: text.length > 0
                    }
                }

                // The bounded viewport.
                Item {
                    id: deviceListViewport
                    objectName: "bluetoothListViewport"
                    width: parent.width
                    height: root.deviceCount === 0 ? root.rowHeight
                        : Math.min(root.deviceContentHeight, root.maxListHeight)

                    Text {
                        id: emptyText
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: root.serviceAvailable
                            ? (root.adapterAvailable
                               ? (root.enabled
                                  ? Services.Tr.q(CcLogic.emptyLabels.bluetooth)
                                  : Services.Tr.q("cc.bluetooth.off"))
                               : Services.Tr.q("cc.bluetooth.noAdapterLong"))
                            : Services.Tr.q("cc.bluetooth.noService")
                        color: LazerTheme.textMuted
                        font.pixelSize: 12
                        visible: root.deviceCount === 0
                    }

                    Flickable {
                        id: deviceList
                        objectName: "bluetoothDeviceList"
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: deviceColumn.height
                        boundsBehavior: Flickable.StopAtBounds
                        // Pinned vertical: a detail list never scrolls sideways.
                        flickableDirection: Flickable.VerticalFlick
                        // A list that already fits leaves the wheel to the page.
                        interactive: root.deviceContentHeight > height
                        clip: true

                        Column {
                            id: deviceColumn
                            objectName: "bluetoothDeviceColumn"
                            x: 0
                            y: 0
                            width: deviceList.width
                            height: root.deviceContentHeight
                            spacing: root.rowGap

                            Repeater {
                                model: root.deviceList

                                delegate: Rectangle {
                                    id: deviceRow
                                    // The stable row key, from the adapter's own
                                    // deviceKey() where the service offers one.
                                    // A scan that returns the same devices in a
                                    // different order must not turn the action
                                    // buttons around.
                                    required property int index
                                    required property var modelData

                                    readonly property var device: modelData
                                    // The row's two targets, published so a test (or a
                                    // caller) can ask about them without sweeping the
                                    // column's children. They are the very items the
                                    // row paints, not copies of their state.
                                    readonly property Item forgetButton: forgetTarget
                                    readonly property Item deviceActionButton:
                                        actionTarget
                                    readonly property string rowKey: root.deviceKey(
                                        modelData, deviceRow.index)
                                    readonly property string rowLabel: root.deviceName(modelData)
                                    readonly property string rowIcon: root.deviceIcon(modelData)
                                    readonly property bool connected: modelData.connected === true
                                    readonly property bool busy: root.deviceBusy(modelData)
                                    readonly property string action: root.deviceAction(modelData)
                                    readonly property bool signalKnown:
                                        root.deviceSignalPercent(modelData) >= 0
                                    readonly property int signalPercent:
                                        deviceRow.signalKnown
                                            ? root.deviceSignalPercent(modelData) : -1

                                    // A row is a target only while the adapter can
                                    // actually act on it: a device mid-pairing
                                    // accepts nothing, or a second call would race
                                    // the one already running.
                                    readonly property bool rowEnabled: root.adapterEnabled
                                        && !deviceRow.busy && deviceRow.action !== "none"

                                    // Whether Forget is offered is NOT a delegate
                                    // property: it is `root.isForgetable(modelData)`,
                                    // and the Forget button asks the page for it (see
                                    // below). The same binding carried here was
                                    // intermittently handed `undefined` on its first
                                    // assignment by this Qt build, which disabled the
                                    // button permanently and logged "Unable to assign
                                    // [undefined] to bool". A per-row property is not
                                    // worth a rule that can come out undefined.

                                    function activate() {
                                        if (!deviceRow.rowEnabled)
                                            return
                                        root.activateDevice(deviceRow.rowKey)
                                    }

                                    width: deviceColumn.width
                                    height: root.rowHeight
                                    radius: 0
                                    color: rowHover.hovered && deviceRow.rowEnabled
                                          ? LazerTheme.settingsCardHover
                                          : LazerTheme.settingsCard
                                    opacity: deviceRow.rowEnabled || deviceRow.connected
                                        ? 1 : LazerTheme.settingsDisabledAlpha
                                    activeFocusOnTab: deviceRow.rowEnabled
                                    Accessible.role: deviceRow.rowEnabled
                                        ? Accessible.Button : Accessible.StaticText
                                    Accessible.name: deviceRow.rowLabel
                                        + (deviceRow.connected ? ", connected" : "")

                                    Behavior on color {
                                        ColorAnimation { duration: MotionTokens.fast }
                                    }

                                    // Connected marker: a leading colour bar.
                                    Rectangle {
                                        id: deviceBar
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 3
                                        height: parent.height - 16
                                        color: LazerTheme.settingsAccent
                                        opacity: deviceRow.connected ? 1 : 0

                                        Behavior on opacity {
                                            enabled: !MotionTokens.reducedMotion
                                            NumberAnimation { duration: MotionTokens.fast }
                                        }
                                    }

                                    // Device name, elided so a long name cannot
                                    // widen the row or push the actions out.
                                    Text {
                                        id: deviceNameText
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.right: signalText.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: deviceRow.rowLabel
                                        color: LazerTheme.textPrimary
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }

                                    // Signal as a percentage, or nothing at all
                                    // when the adapter never reported one.
                                    Text {
                                        id: signalText
                                        anchors.right: actionTarget.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: deviceRow.signalPercent < 0 ? ""
                                            : deviceRow.signalPercent + "%"
                                        color: LazerTheme.textMuted
                                        font.pixelSize: 11
                                        visible: text.length > 0
                                    }

                                    // The row's ONE action. A square target that
                                    // exists only while the row is live, so there
                                    // is never a button that does nothing.
                                    Rectangle {
                                        id: actionTarget
                                        anchors.right: forgetTarget.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: deviceRow.action === "none" ? 0 : 74
                                        height: root.actionHeight
                                        radius: 0
                                        visible: width > 0
                                        color: deviceActionHover.hovered
                                            && deviceRow.rowEnabled
                                            ? LazerTheme.settingsCardHover : "transparent"
                                        enabled: deviceRow.rowEnabled
                                        opacity: enabled ? 1 : LazerTheme.settingsDisabledAlpha

                                        // The one activation path, so a key press, a
                                        // click and a probe cannot diverge.
                                        function activate() {
                                            if (!actionTarget.enabled)
                                                return
                                            deviceRow.activate()
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: MotionTokens.fast }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: deviceRow.busy ? "Working…"
                                                : root.actionLabel(deviceRow.action)
                                            color: LazerTheme.settingsAccent
                                            font.pixelSize: 11
                                        }

                                        HoverHandler {
                                            id: deviceActionHover
                                            enabled: actionTarget.enabled
                                        }
                                        TapHandler {
                                            enabled: actionTarget.enabled
                                            onTapped: actionTarget.activate()
                                        }
                                        Keys.onPressed: event => {
                                            if (!actionTarget.enabled)
                                                return
                                            if (event.key === Qt.Key_Return
                                                    || event.key === Qt.Key_Enter
                                                    || event.key === Qt.Key_Space) {
                                                actionTarget.activate()
                                                event.accepted = true
                                            }
                                        }
                                    }

                                    // Forget: separate, smaller and quiet, because
                                    // it is destructive and never the row's primary
                                    // action.
                                    //
                                    // Its gate is asked of the page in ONE binding here,
                                    // rather than read off a delegate property: a child
                                    // binding reading a sibling delegate property during
                                    // construction is handed `undefined` on this Qt
                                    // build, which left this button permanently disabled
                                    // and logged "Unable to assign [undefined] to bool".
                                    Rectangle {
                                        id: forgetTarget
                                        readonly property bool live:
                                            root.isForgetable(modelData)
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 30
                                        height: 26
                                        radius: 0
                                        color: forgetHover.hovered && forgetTarget.live
                                            ? LazerTheme.settingsCardHover : "transparent"
                                        enabled: forgetTarget.live
                                        opacity: enabled ? 1 : LazerTheme.settingsDisabledAlpha
                                        activeFocusOnTab: enabled
                                        Accessible.role: enabled ? Accessible.Button
                                                                 : Accessible.StaticText
                                        Accessible.name: Services.Tr.q("cc.bluetooth.forget", { name: deviceRow.rowLabel })

                                        function activate() {
                                            if (!forgetTarget.enabled)
                                                return
                                            root.forgetDevice(deviceRow.rowKey)
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: MotionTokens.fast }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "⌫"
                                            color: LazerTheme.textMuted
                                            font.pixelSize: 13
                                        }

                                        HoverHandler {
                                            id: forgetHover
                                            enabled: forgetTarget.enabled
                                        }
                                        TapHandler {
                                            enabled: forgetTarget.enabled
                                            onTapped: forgetTarget.activate()
                                        }
                                        Keys.onPressed: event => {
                                            if (!forgetTarget.enabled)
                                                return
                                            if (event.key === Qt.Key_Return
                                                    || event.key === Qt.Key_Enter
                                                    || event.key === Qt.Key_Space) {
                                                forgetTarget.activate()
                                                event.accepted = true
                                            }
                                        }
                                    }

                                    HoverHandler {
                                        id: rowHover
                                        enabled: deviceRow.rowEnabled
                                        blocking: false
                                    }

                                    TapHandler {
                                        enabled: deviceRow.rowEnabled
                                        onTapped: deviceRow.activate()
                                    }

                                    Keys.onPressed: event => {
                                        if (!deviceRow.rowEnabled)
                                            return
                                        if (event.key === Qt.Key_Return
                                                || event.key === Qt.Key_Enter
                                                || event.key === Qt.Key_Space) {
                                            deviceRow.activate()
                                            event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Test and host seams ---

    readonly property Item deviceListItem: deviceList
    readonly property Item listItem: deviceList
    readonly property Item pageFlickItem: pageFlick
    readonly property Item powerRowItem: powerRow
    readonly property Item stateLabelItem: stateLabel
    readonly property Item powerTextItem: powerText
    readonly property Item deviceHeaderItem: deviceHeader
    readonly property Item deviceHeaderCountItem: deviceHeaderCount
    readonly property Item emptyStateItem: emptyText
    readonly property Item deviceListViewportItem: deviceListViewport
    readonly property Item powerToggleItem: powerToggle
    readonly property Item scanButtonItem: scanButton

    // One device row by its stable key, so a test (or a caller) addresses the row
    // the user would click rather than a child index that a rescan can move.
    function deviceRowItem(key) {
        var kids = deviceColumn.children
        var target = String(key)
        for (var i = 0; i < kids.length; i++) {
            if (kids[i].rowKey !== undefined && String(kids[i].rowKey) === target)
                return kids[i]
        }
        return null
    }
}
