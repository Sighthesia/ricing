import QtQuick
import "ControlCenterLogic.js" as CcLogic

// Same-surface network detail page: a sub-page of the control-center route, not
// a sibling Wave route.
//
// It is MOUNTED INSIDE ControlCenter, which owns the wave host's single retained
// Loader. So this file creates no window, opens no overlay and asks nobody for a
// route: it is content, and the only thing it changes is which sub-page the
// overview is showing. Escape is the host's to route - this page publishes
// `canGoBack` and a `handleBack()` so the host hands it the press, and it
// answers with `backRequested()` for the owner to pop it.
//
// Every read goes through the injected `networkService`, and every write is a
// single call into one of its existing methods. There is no second network
// implementation here: no nmcli, no process, no parsing. The service owns the
// scan, the profiles and the error wording; this page decides only how a state
// looks.
//
// Sharp language: right-angled row surfaces, state carried by square colour
// bars and brightness, motion from MotionTokens only.
Item {
    id: root
    objectName: "controlCenterNetworkDetail"

    // --- Injected service seam ---
    //
    // Null is the production state until the wiring task passes
    // Services.NetworkService, and it renders an explicit state rather than
    // throwing. Every read below therefore goes through a snapshot object.

    property var networkService: null

    // --- Sub-page contract ---
    //
    // A detail page always has the overview to pop back to, so `canGoBack` is a
    // constant `true` - not a flag the page flips. Only the host's own Escape
    // routing decides whether the press arrives; a constant claim cannot get out
    // of step with what is actually mounted.

    readonly property bool canGoBack: true

    // The owner pops the sub-page. Announced rather than performed, because this
    // page does not own the overview: mounting and unmounting it is the
    // ControlCenter's decision, and the back press is only the request.
    signal backRequested()

    // Which detail page this is, read from the module rather than restated, so
    // the name the overview switches on and the name the module declares cannot
    // drift apart.
    readonly property string detailRoute: CcLogic.detailRoutes.network

    // Host chrome for this sub-page, in the same shape the overview publishes.
    // The header is the host's, so a sub-page changes what it says without the
    // host learning anything about sub-pages: it still reads one route page.
    readonly property string title: "Network"
    readonly property string description: "Wi-Fi and wired"
    readonly property var sidebarEntries: []
    readonly property string activeSidebarId: ""

    // Focus lands on the page itself, never on a control: the rows join the tab
    // chain on their own, and the page must be able to take focus back from the
    // overview without the host knowing which control that was.
    function focusDefault() { root.forceActiveFocus() }

    // Take the host's back press and report it. Returning anything but `false`
    // is what stops the host falling through to closing the whole surface, so
    // this is the one place that must not return false.
    function handleBack() {
        root.backRequested()
        return true
    }

    // --- Fixed geometry tokens ---
    //
    // Every list is bounded by a MAXIMUM, never by its content: the wave surface
    // is a fixed viewport, so a dense band scrolls inside the page rather than
    // growing it.

    readonly property real pagePadding: 24
    readonly property real sectionGap: 18
    readonly property real rowGap: 6
    readonly property real rowHeight: 40
    readonly property real sectionTitleHeight: 20
    readonly property real errorHeight: 24
    readonly property real passwordHeight: 34
    readonly property real powerRowHeight: 44

    // The bounded list budget: the most vertical space any one section may take
    // on a short viewport. A list that fits shows no scrollbar and takes no wheel.
    readonly property real maxListHeight: 260

    // --- Service snapshot ---
    //
    // One plain object per read, so a binding depends on the properties it
    // actually uses. A fake that omits one yields undefined, which every read
    // below treats as "nothing to report" rather than as a crash.

    readonly property bool serviceAvailable: root.networkService !== null

    readonly property bool wifiEnabled: root.networkService
            && root.networkService.wifiEnabled !== undefined
            ? root.networkService.wifiEnabled !== false : false
    readonly property bool wifiConnected: root.networkService
            && root.networkService.wifiConnected === true
    // The in-flight attempt's target, so its own row can say "Connecting…".
    readonly property string connectingTo: root.networkService
            ? String(root.networkService.connectingTo == null
                     ? "" : root.networkService.connectingTo) : ""
    readonly property bool connecting: root.networkService
            && root.networkService.connecting === true

    readonly property bool ethernetAvailable: root.networkService
            && root.networkService.ethernetAvailable !== undefined
            ? root.networkService.ethernetAvailable !== false : false
    readonly property bool ethernetConnected: root.networkService
            && root.networkService.ethernetConnected === true
    readonly property string activeEthernetConnection: root.networkService
            && root.networkService.activeEthernetConnection != null
            ? String(root.networkService.activeEthernetConnection) : ""
    readonly property string activeEthernetIf: root.networkService
            && root.networkService.activeEthernetIf != null
            ? String(root.networkService.activeEthernetIf) : ""

    // The link the service is currently reporting, in its own words. An empty
    // object means "no link", which is a normal state here, not a failure.
    readonly property var linkDetails: {
        var details = root.networkService ? root.networkService.linkDetails : null
        return details != null && typeof details === "object" ? details : ({})
    }
    readonly property string linkIp4: String(root.linkDetails.ip4 == null
        ? "" : root.linkDetails.ip4)
    readonly property string linkGateway: String(root.linkDetails.gateway == null
        ? "" : root.linkDetails.gateway)

    // The service's own failure words, kept raw. Nothing here re-classifies them:
    // NetworkService already ran them through NetworkLogic.classifyConnectError,
    // and a second opinion would be a second vocabulary.
    readonly property string errorText: root.networkService
            ? String(root.networkService.lastError == null
                     ? "" : root.networkService.lastError) : ""
    readonly property string errorForSsid: root.networkService
            && root.networkService.lastErrorSsid != null
            ? String(root.networkService.lastErrorSsid) : ""

    // Whether the current failure is a rejected secret. The service owns that
    // classification (`isCredentialFailure`), and asking it is what keeps the
    // recovery path - re-enter the password - offered exactly when it can work.
    readonly property bool errorIsCredential: root.errorText !== ""
            && root.networkService
            && typeof root.networkService.isCredentialFailure === "function"
            && root.networkService.isCredentialFailure(root.errorText) === true

    // The connected network's name.
    //
    // NetworkService has NO flat activeSsid: it keeps a `networks` scan map keyed
    // by SSID whose entries carry `ssid` and `connected`, and it reassigns that
    // whole map on every status change. So the connected entry of that map is the
    // only place the name lives, and a flat accessor - if some service ever grows
    // one - is honoured first so this stays a fallback rather than a second
    // source of truth.
    readonly property string connectedSsid: {
        var service = root.networkService
        if (!service)
            return ""
        var flat = String(service.activeSsid == null ? "" : service.activeSsid)
        if (flat !== "")
            return flat
        var networks = service.networks
        if (networks == null || typeof networks !== "object")
            return ""
        var keys = Object.keys(networks)
        for (var i = 0; i < keys.length; i++) {
            var entry = networks[keys[i]]
            if (entry != null && entry.connected === true)
                return String(entry.ssid == null || entry.ssid === ""
                    ? keys[i] : entry.ssid)
        }
        return ""
    }

    // Every visible network, connected first then strongest. The whole map is
    // carried, never a slice of it: the bound is on the VIEWPORT below, so a
    // dense band stays reachable instead of losing its tenth row.
    readonly property var networkList: {
        var service = root.networkService
        var nets = service ? service.networks : null
        if (nets == null || typeof nets !== "object")
            return []
        var rows = Object.keys(nets).map(function (key) {
            var entry = nets[key]
            if (entry == null)
                return null
            return {
                key: key,
                ssid: String(entry.ssid == null || entry.ssid === "" ? key : entry.ssid),
                security: String(entry.security == null ? "" : entry.security),
                signal: Number(entry.signal),
                connected: entry.connected === true,
                existing: entry.existing === true
            }
        })
        var kept = []
        for (var i = 0; i < rows.length; i++) {
            if (rows[i] !== null)
                kept.push(rows[i])
        }
        kept.sort(function (a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1
            return (isFinite(b.signal) ? b.signal : 0) - (isFinite(a.signal) ? a.signal : 0)
        })
        return kept
    }
    readonly property int wifiRowCount: root.networkList.length
    readonly property int wifiContentHeight: root.wifiRowCount * root.rowHeight
            + Math.max(0, root.wifiRowCount - 1) * root.rowGap

    // The SSID the service reports an in-flight attempt against. Only that one
    // row is marked busy - a service that marks all of them would make the list
    // look frozen rather than busy.
    readonly property string busySsid: root.connecting && root.connectingTo !== ""
            ? root.connectingTo : ""

    // --- One state word for the whole page ---
    //
    // The module's own vocabulary, in the module's precedence: a failure, then
    // an in-flight read, then a missing adapter, then emptiness. This is a
    // report, never a gate: a page with no adapter still lays out and still
    // explains itself.
    readonly property string state: !root.serviceAvailable ? "unavailable"
        : (root.errorText !== "" ? "error"
            : (root.connecting || root.scanningActive ? "loading"
                : (!root.wifiEnabled && !root.ethernetAvailable ? "off"
                    : (root.wifiRowCount === 0 ? "empty" : "ready"))))
    readonly property string stateLabel: {
        if (root.state === "unavailable")
            return "Network service unavailable"
        if (root.state === "error")
            return root.errorText
        if (root.state === "loading")
            return root.connecting && root.connectingTo !== ""
                ? "Connecting to " + root.connectingTo : "Scanning…"
        if (root.state === "off")
            return "Wi-Fi is off"
        if (root.state === "empty")
            return "No networks found"
        return root.wifiConnected && root.connectedSsid !== ""
            ? "Connected to " + root.connectedSsid : "Not connected"
    }
    readonly property bool scanningActive: root.networkService
            && root.networkService.scanningActive === true

    // --- Wired status ---
    //
    // The service's own profile name where there is one, else the port. Never a
    // derived phrase: an ethernet profile really is called something.
    readonly property string wiredStatusText: root.ethernetConnected
        ? (root.activeEthernetConnection !== "" ? root.activeEthernetConnection
            : (root.activeEthernetIf !== "" ? root.activeEthernetIf : "Wired"))
        : (root.ethernetAvailable ? "Wired - not connected" : "")

    // --- Credentials ---
    //
    // A prompt that owns a typed secret for the life of the page is a secret
    // nobody can clear, so it is cleared on every exit path: submit, cancel,
    // and a new prompt. `passwordSsid` being non-empty is what makes the field
    // live, and it is the ONLY thing that gives the field focus.

    property string password: ""
    readonly property string passwordSsid: root._passwordSsid
    property string _passwordSsid: ""

    readonly property bool passwordActive: root.passwordSsid !== ""

    // --- Open refresh ---
    //
    // What this page owes the service on its way in: one fresh read of the radio.
    // The scan behind the overview's summary can be minutes old, and a network
    // that appeared since then is simply not in the list - the same reason the
    // bar's network popup re-reads the radio when it becomes visible.
    //
    // It is that call, unchanged: the service's own refreshForOpen(), which
    // throttles itself, reached through the same typeof guard so no service - or
    // no service at all - is called on a method it does not have. There is no
    // scan() fallback here, unlike BarPopupActions: this page's rescan is a user
    // action with its own arguments, and "the page opened" is not that action.
    //
    // Asked ONCE per mount, from Component.onCompleted. A binding or an
    // onNetworkServiceChanged handler would ask again for every re-render and
    // every service swap - which is exactly what a test does when it seeds a
    // fake - and an open that re-reads the radio per binding churn is a scan per
    // frame. The count is published so the once-ness is asserted rather than
    // assumed.
    readonly property int openRefreshCount: _openRefreshCount
    property int _openRefreshCount: 0

    Component.onCompleted: root.refreshForOpen()

    function refreshForOpen() {
        var service = root.networkService
        if (!service || typeof service.refreshForOpen !== "function")
            return
        root._openRefreshCount++
        service.refreshForOpen()
    }

    // --- Actions ---
    //
    // Each is one guarded call into an existing service method. The guards are
    // not defensive padding: the production page starts with a null service, and
    // a partial fake reaches here too.

    function setWifiEnabled(enabled) {
        if (!root.networkService
                || typeof root.networkService.setWifiEnabled !== "function")
            return
        root.networkService.setWifiEnabled(enabled === true)
    }

    function rescan() {
        if (!root.networkService || typeof root.networkService.requestScan !== "function")
            return
        // rescan=true asks NetworkManager for a fresh radio scan; clearError is
        // left false because this is the user's own deliberate action and must
        // not wipe a message they have not read yet.
        root.networkService.requestScan(true, false)
    }

    // Tapping a row: disconnect the connected one, otherwise connect - and
    // collect the password first whenever the service says this SSID needs one.
    function activateNetwork(ssid) {
        var service = root.networkService
        if (!service || ssid === null || ssid === undefined || ssid === "")
            return
        var network = root.networkFor(ssid)
        if (network === null)
            return
        if (network.connected) {
            if (typeof service.disconnect === "function")
                service.disconnect(network.ssid)
            return
        }
        if (typeof service.needsPasswordFor === "function"
                && service.needsPasswordFor(network.ssid)) {
            root.openPassword(network.ssid)
            return
        }
        if (typeof service.connect === "function")
            service.connect(network.ssid, "", false, network.security)
    }

    // The row behind an SSID, resolved from the page's own list rather than from
    // the raw service map, so an activation and a paint always agree on the same
    // record's security word.
    function networkFor(ssid) {
        var list = root.networkList
        for (var i = 0; i < list.length; i++) {
            if (list[i].ssid === ssid || list[i].key === ssid)
                return list[i]
        }
        return null
    }

    function openPassword(ssid) {
        root.password = ""
        root._passwordSsid = ssid
        // Focus is taken HERE, not by a binding on `passwordActive`: the field
        // is created before the prompt opens, so only the opening turn can hand
        // it focus.
        passwordFocusTimer.restart()
    }

    function cancelPassword() {
        root.closePassword()
    }

    function submitPassword() {
        var ssid = root.passwordSsid
        if (ssid === "" || root.password === "" || !root.networkService)
            return
        var network = root.networkFor(ssid)
        var security = network !== null && network.security !== ""
            ? network.security : "wpa-psk"
        // Submit BEFORE closing, so the secret is read while the prompt still
        // names its SSID. Closing first would clear it out from under the call.
        if (typeof root.networkService.connect === "function")
            root.networkService.connect(ssid, root.password, false, security)
        root.closePassword()
    }

    function closePassword() {
        root.password = ""
        root._passwordSsid = ""
        passwordInput.focus = false
    }

    // Focus lands one turn after the prompt opens, which is the first turn the
    // field exists with content behind it. A Timer rather than Qt.callLater for
    // the reason ControlCenter gives: a queued closure can outlive the component
    // it names.
    Timer {
        id: passwordFocusTimer
        interval: 0
        repeat: false
        onTriggered: if (root.passwordActive) passwordInput.forceActiveFocus()
    }

    implicitWidth: 640
    implicitHeight: 520

    // The page's vertical scroller. Vertical-only by construction, so the panel
    // can never scroll sideways: `contentWidth` is pinned to the viewport and a
    // horizontal flick has nothing to move.
    Flickable {
        id: pageFlick
        objectName: "networkPageFlick"
        x: root.pagePadding
        y: root.pagePadding
        width: Math.max(0, root.width - root.pagePadding * 2)
        height: Math.max(0, root.height - y - root.pagePadding)
        contentWidth: width
        contentHeight: pageContent.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        // Unqualified, deliberately: reaching back through `root.pageFlick` reads
        // this same property through the parent, and during construction that
        // hand-back is not assigned yet, so the binding threw a TypeError on
        // every mount instead of reading the height it wanted.
        interactive: contentHeight > height

        // The content box every section is placed in. Declared explicitly so the
        // sections do not land on the Flickable's own built-in content item.
        Item {
            id: pageContent
            objectName: "networkPageContent"
            width: pageFlick.width
            height: wifiSection.y + wifiSection.height

            // --- Wired + Wi-Fi status band ---
            //
            // Two read-only lines above the power control: the wired link's own
            // profile name and the Wi-Fi state, because a machine on ethernet
            // still has a radio, and reporting only Wi-Fi would read as "no
            // network" on a wired desktop.
            Column {
                id: statusBand
                objectName: "networkStatusBand"
                x: 0
                y: 0
                width: parent.width
                spacing: 4

                Text {
                    id: stateLabel
                    width: parent.width
                    height: implicitHeight
                    text: root.stateLabel
                    color: root.state === "error" ? LazerTheme.settingsWarning
                        : LazerTheme.textPrimary
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                Text {
                    id: wiredLabel
                    width: parent.width
                    height: visible ? implicitHeight : 0
                    visible: root.wiredStatusText !== ""
                    text: root.wiredStatusText
                    color: LazerTheme.textMuted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    id: linkLabel
                    width: parent.width
                    height: visible ? implicitHeight : 0
                    visible: root.linkIp4 !== ""
                    text: root.linkGateway !== ""
                        ? root.linkIp4 + "   ·   gw " + root.linkGateway
                        : root.linkIp4
                    color: LazerTheme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            // --- Wi-Fi power ---
            //
            // One square row: the radio's own state as text, the toggle, and a
            // rescan target. The toggle is the settings panel's own capsule, so
            // power control reads identically here and in the settings.
            Rectangle {
                id: powerRow
                objectName: "wifiPowerRow"
                x: 0
                y: statusBand.height + root.sectionGap
                width: parent.width
                height: root.powerRowHeight
                radius: 0
                color: powerHover.hovered ? LazerTheme.settingsCardHover
                                          : LazerTheme.settingsCard
                // Absent radio is a state, not a target: the capsule is disabled
                // and reads dimmed, exactly as an unavailable card does.
                enabled: root.serviceAvailable

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                Image {
                    id: powerGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: LazerTheme.iconSize
                    height: LazerTheme.iconSize
                    source: "../bar/icons/wifi.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: powerRow.enabled ? 1 : LazerTheme.settingsDisabledAlpha
                }

                Text {
                    id: powerText
                    anchors.left: powerGlyph.right
                    anchors.leftMargin: 10
                    anchors.right: rescanButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    color: LazerTheme.textPrimary
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                // Rescan: a square target, enabled only where a rescan can do
                // something. A radio that is already scanning needs no second tap,
                // and a disabled one has nothing to scan.
                Rectangle {
                    id: rescanButton
                    objectName: "wifiRescanButton"
                    anchors.right: wifiToggle.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 0
                    color: rescanHover.hovered ? LazerTheme.settingsCardHover : "transparent"
                    enabled: powerRow.enabled && !root.scanningActive
                    opacity: enabled ? 1 : LazerTheme.settingsDisabledAlpha
                    activeFocusOnTab: enabled
                    Accessible.role: enabled ? Accessible.Button : Accessible.StaticText
                    Accessible.name: "Rescan networks"

                    // The one activation path, so a key press, a click and a
                    // probe cannot diverge.
                    function activate() {
                        if (!rescanButton.enabled)
                            return
                        root.rescan()
                    }

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "⟳"
                        color: root.scanningActive ? LazerTheme.settingsAccent
                            : LazerTheme.textPrimary
                        font.pixelSize: 15
                    }

                    HoverHandler { id: rescanHover; enabled: rescanButton.enabled }
                    TapHandler { enabled: rescanButton.enabled; onTapped: rescanButton.activate() }
                    Keys.onPressed: event => {
                        if (!rescanButton.enabled)
                            return
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space) {
                            rescanButton.activate()
                            event.accepted = true
                        }
                    }
                }

                // The settings panel's own toggle, so radio power looks like
                // every other power switch in the shell.
                LazerSettingsToggle {
                    id: wifiToggle
                    objectName: "wifiToggle"
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.wifiEnabled
                    enabled: root.serviceAvailable
                    accessibleName: "Wi-Fi"
                    onToggled: function (value) { root.setWifiEnabled(value) }
                }

                // The row's own hover observer. It watches without blocking, so
                // the toggle and the rescan target keep every pointer event -
                // the failure mode the settings panel's row catcher exists to
                // avoid.
                HoverHandler { id: powerHover; enabled: powerRow.enabled }
            }

            // --- Inline error ---
            //
            // A square warning band inside the page, never a modal and never a
            // popup: a failed adapter must not be able to block the surface. It
            // is placed above the list so it is read before the user acts again.
            Rectangle {
                id: errorBand
                objectName: "networkErrorBand"
                x: 0
                y: powerRow.y + powerRow.height + root.sectionGap
                width: parent.width
                height: root.errorText === "" ? 0 : root.errorHeight
                radius: 0
                color: "transparent"
                clip: true

                Behavior on height {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
                }

                Rectangle {
                    id: errorBar
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: root.errorHeight - 8
                    color: LazerTheme.settingsWarning
                }

                Text {
                    id: errorTextItem
                    x: errorBar.right + 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: root.errorHeight - 8
                    text: root.errorText
                    color: LazerTheme.settingsWarning
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            // --- Wi-Fi list section ---
            //
            // The bounded scrollable area. Its height is the LESSER of what the
            // rows need and what the page can spare, so a dense band scrolls and
            // a short list leaves its remaining space to the sections below.
            Column {
                id: wifiSection
                objectName: "wifiSection"
                x: 0
                y: errorBand.y + errorBand.height + root.sectionGap
                width: parent.width
                spacing: root.rowGap

                // Section header: the radio's state as a word, plus the count, so
                // a bounded viewport never hides that the list is longer.
                //
                // Laid out from explicit offsets, NOT a Row: a positioner refuses
                // anchors on its children outright ("Row will not function"), and
                // the count sits next to the title in the same band - so a single
                // top-left-anchored Row would stack the three items and drop the
                // square state bar on the title.
                Item {
                    id: wifiHeader
                    objectName: "wifiSectionHeader"
                    width: parent.width
                    height: root.sectionTitleHeight

                    Rectangle {
                        id: wifiHeaderBar
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 12
                        color: root.wifiConnected ? LazerTheme.settingsAccent
                                                  : LazerTheme.iconInactive
                        opacity: root.wifiRowCount > 0 ? 1 : 0

                        Behavior on opacity {
                            enabled: !MotionTokens.reducedMotion
                            NumberAnimation { duration: MotionTokens.fast }
                        }
                    }

                    Text {
                        id: wifiHeaderTitle
                        x: wifiHeaderBar.width + 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Available networks"
                        color: LazerTheme.textPrimary
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        id: wifiHeaderCount
                        x: wifiHeaderTitle.x + wifiHeaderTitle.width + 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.wifiRowCount > 0 ? String(root.wifiRowCount) : ""
                        color: LazerTheme.textMuted
                        font.pixelSize: 11
                        visible: text.length > 0
                    }
                }

                // The bounded viewport. Height is `min(needed, budget)`, and the
                // empty state occupies the same reserved band, so a page with
                // nothing to show still holds its shape.
                Item {
                    id: listViewport
                    objectName: "wifiListViewport"
                    width: parent.width
                    height: root.wifiRowCount === 0 ? root.rowHeight
                        : Math.min(root.wifiContentHeight, root.maxListHeight)

                    Text {
                        id: emptyText
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: root.serviceAvailable
                            ? (root.wifiEnabled ? CcLogic.emptyLabels.network : "Wi-Fi is off")
                            : "No network service"
                        color: LazerTheme.textMuted
                        font.pixelSize: 12
                        visible: root.wifiRowCount === 0
                    }

                    Flickable {
                        id: wifiList
                        objectName: "wifiList"
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: wifiColumn.height
                        boundsBehavior: Flickable.StopAtBounds
                        // Pinned vertical, so a detail list can never scroll
                        // sideways: a horizontal flick has nothing to move.
                        flickableDirection: Flickable.VerticalFlick
                        // A list that already fits must leave the wheel to the
                        // page; an overlong one scrolls.
                        interactive: root.wifiContentHeight > height
                        clip: true

                        Column {
                            id: wifiColumn
                            objectName: "wifiListColumn"
                            x: 0
                            y: 0
                            width: wifiList.width
                            height: root.wifiContentHeight
                            spacing: root.rowGap

                            Repeater {
                                model: root.networkList

                                delegate: Rectangle {
                                    id: networkRow
                                    // The stable row key. A device list that
                                    // reorders on every scan must not turn its
                                    // action targets around, so the row is
                                    // addressed by SSID rather than by position.
                                    readonly property string rowKey: String(modelData.key)
                                    readonly property string rowSsid: String(modelData.ssid)
                                    readonly property string rowLabel: rowSsid
                                    readonly property bool connected: modelData.connected === true
                                    readonly property bool busy: root.busySsid === rowSsid
                                    readonly property bool signalKnown: isFinite(modelData.signal)
                                    readonly property int signalPercent: networkRow.signalKnown
                                        ? Math.round(Math.max(0, Math.min(100,
                                              modelData.signal)))
                                        : -1

                                    // A row is a target unless the service is
                                    // mid-flight on THIS row: a connect in
                                    // progress must not be re-triggered, and the
                                    // rest of the list must stay usable.
                                    readonly property bool rowEnabled: root.serviceAvailable
                                        && !networkRow.busy

                                    function activate() {
                                        if (!networkRow.rowEnabled)
                                            return
                                        root.activateNetwork(networkRow.rowSsid)
                                    }

                                    required property var modelData
                                    width: wifiColumn.width
                                    height: root.rowHeight
                                    radius: 0
                                    color: rowHover.hovered && networkRow.rowEnabled
                                          ? LazerTheme.settingsCardHover
                                          : LazerTheme.settingsCard
                                    opacity: networkRow.rowEnabled ? 1
                                        : LazerTheme.settingsDisabledAlpha
                                    activeFocusOnTab: networkRow.rowEnabled
                                    Accessible.role: networkRow.rowEnabled
                                        ? Accessible.Button : Accessible.StaticText
                                    Accessible.name: networkRow.rowLabel
                                        + (networkRow.connected ? ", connected" : "")

                                    Behavior on color {
                                        ColorAnimation { duration: MotionTokens.fast }
                                    }

                                    // Connected marker: a leading colour bar, the
                                    // project's state idiom rather than a check
                                    // glyph or a rounded outline.
                                    Rectangle {
                                        id: rowBar
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 3
                                        height: parent.height - 14
                                        color: LazerTheme.settingsAccent
                                        opacity: networkRow.connected ? 1 : 0

                                        Behavior on opacity {
                                            enabled: !MotionTokens.reducedMotion
                                            NumberAnimation { duration: MotionTokens.fast }
                                        }
                                    }

                                    Text {
                                        id: rowSsidText
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.right: signalText.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: networkRow.busy
                                            ? "Connecting to " + networkRow.rowLabel + "…"
                                            : networkRow.rowLabel
                                        color: LazerTheme.textPrimary
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: signalText
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: networkRow.signalPercent < 0 ? ""
                                            : networkRow.signalPercent + "%"
                                        color: LazerTheme.textMuted
                                        font.pixelSize: 11
                                        visible: text.length > 0 && !networkRow.busy
                                    }

                                    HoverHandler {
                                        id: rowHover
                                        enabled: networkRow.rowEnabled
                                        blocking: false
                                    }

                                    TapHandler {
                                        enabled: networkRow.rowEnabled
                                        onTapped: networkRow.activate()
                                    }

                                    Keys.onPressed: event => {
                                        if (!networkRow.rowEnabled)
                                            return
                                        if (event.key === Qt.Key_Return
                                                || event.key === Qt.Key_Enter
                                                || event.key === Qt.Key_Space) {
                                            networkRow.activate()
                                            event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Password prompt ---
                //
                // Sits under the list and takes no space when closed, so opening
                // it does not push the rows the user was reading off the panel.
                Rectangle {
                    id: passwordRow
                    objectName: "wifiPasswordPanel"
                    width: parent.width
                    height: root.passwordActive ? root.passwordHeight : 0
                    visible: root.passwordActive
                    radius: 0
                    color: LazerTheme.settingsCard
                    clip: true

                    Behavior on height {
                        enabled: !MotionTokens.reducedMotion
                        NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
                    }

                    TextInput {
                        id: passwordInput
                        objectName: "wifiPasswordInput"
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: passwordConnect.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        height: root.passwordHeight - 10
                        // The page owns the secret; the field is bound to it in
                        // both directions so a cancel clears the editor too.
                        text: root.password
                        echoMode: TextInput.Password
                        color: LazerTheme.textPrimary
                        selectionColor: LazerTheme.settingsAccent
                        clip: true

                        onTextChanged: root.password = text
                        onAccepted: root.submitPassword()
                        // Escape belongs to the PROMPT, not to the page.
                        //
                        // Claimed explicitly, the way every consumed key in this
                        // shell is claimed. Qt happens to stop an Escape at the
                        // first Keys handler that runs, but that is an implicit
                        // default, not this page saying so - and a prompt whose
                        // Escape is nobody's business hands the press to whichever
                        // ancestor answers next, which is the wave host: its
                        // handler pops the whole detail page and throws away the
                        // user's place along with the half-typed secret.
                        Keys.onEscapePressed: event => {
                            root.cancelPassword()
                            event.accepted = true
                        }
                    }

                    // Submit without exposing the secret anywhere on screen.
                    Rectangle {
                        id: passwordConnect
                        anchors.right: passwordCancel.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 62
                        height: root.passwordHeight - 8
                        radius: 0
                        // The accent fill, lightened on hover by the theme's own
                        // lighter() rather than by a hand-picked second colour,
                        // so a theme change cannot leave the hover state stale.
                        color: passwordConnectHover.hovered
                            ? Qt.lighter(LazerTheme.settingsAccent, 1.2)
                            : LazerTheme.settingsAccent
                        enabled: root.password !== ""
                        opacity: enabled ? 1 : LazerTheme.settingsDisabledAlpha

                        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            color: LazerTheme.textPrimary
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        HoverHandler { id: passwordConnectHover; enabled: passwordConnect.enabled }
                        TapHandler {
                            enabled: passwordConnect.enabled
                            onTapped: root.submitPassword()
                        }
                    }

                    // Dismiss the prompt without touching network state. It is
                    // here so a keyboard user is never trapped in a prompt they
                    // cannot leave.
                    Rectangle {
                        id: passwordCancel
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 52
                        height: root.passwordHeight - 8
                        radius: 0
                        color: passwordCancelHover.hovered
                            ? LazerTheme.settingsCardHover : "transparent"

                        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: LazerTheme.textMuted
                            font.pixelSize: 11
                        }

                        HoverHandler { id: passwordCancelHover }
                        TapHandler { onTapped: root.cancelPassword() }
                    }
                }
            }
        }
    }

    // --- Test and host seams ---

    readonly property Item listItem: wifiList
    readonly property Item networkListItem: wifiList
    readonly property Item pageFlickItem: pageFlick
    readonly property Item powerRowItem: powerRow
    readonly property Item errorBandItem: errorBand
    readonly property Item errorTextItem: errorTextItem
    readonly property Item stateLabelItem: stateLabel
    readonly property Item wiredLabelItem: wiredLabel
    readonly property Item wifiHeaderItem: wifiHeader
    readonly property Item wifiHeaderCountItem: wifiHeaderCount
    readonly property Item emptyStateItem: emptyText
    readonly property Item listViewportItem: listViewport
    readonly property Item wifiToggleItem: wifiToggle
    readonly property Item rescanButtonItem: rescanButton
    readonly property Item passwordPanelItem: passwordRow
    readonly property Item passwordItem: passwordInput
    readonly property Item passwordConnectItem: passwordConnect
    readonly property Item passwordCancelItem: passwordCancel

    // One row by its stable SSID key, so a test (or a caller) addresses the row
    // the user would click rather than a child index that a rescan can move.
    function wifiRowItem(ssid) {
        var kids = wifiColumn.children
        for (var i = 0; i < kids.length; i++) {
            if (kids[i].rowKey !== undefined && String(kids[i].rowKey) === String(ssid))
                return kids[i]
        }
        return null
    }
}
