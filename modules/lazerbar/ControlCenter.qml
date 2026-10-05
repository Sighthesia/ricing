import QtQuick
import "ControlCenterLogic.js" as CcLogic

// B1 control-center overview: a balanced two-column surface on the shared Wave
// host, sibling to the launcher and reached through
// WaveSurfaceHost.openRoute("control-center").
//
// It implements the Wave route-page contract the host reads - title,
// description, sidebarEntries, activeSidebarId, canGoBack, handleBack(),
// focusDefault() - and adds exactly four core controls: network, Bluetooth,
// volume and media. Battery is read-only header state and weather is an
// optional header, so neither is a card, and neither can block the first open.
//
// Services arrive as injected properties; the production owner edge passes
// Services.* singletons and a test passes fakes. This page therefore never
// imports a service. Its own side effects are exactly the four a control
// performs when the user acts on it (set volume, toggle mute, media transport);
// opening a detail page or the full notification list is a REQUEST, because this
// page does not own those destinations. It creates no window and opens no
// overlay: it is content inside the host's one retained Loader, which is what
// keeps the launcher and the control center siblings on a single surface.
//
// One set of sections, two arrangements. Each section is declared exactly once
// and only its x/y/width differs between wide and narrow, so the two layouts
// cannot drift apart. Every position comes from ControlCenterLogic's own section
// order, so neither arrangement invents a vocabulary.
//
// Sharp language: every block is a right-angled rectangle, state is carried by
// colour blocks and square bars, and motion comes only from MotionTokens.
Item {
    id: root
    objectName: "controlCenterPage"

    // --- Injected service seams ---
    //
    // Every one is optional. A null service is the production state until the
    // wiring task passes Services.*, and it renders as an explicit unavailable
    // state rather than throwing - which is why every read below goes through a
    // snapshot object instead of touching a service directly.

    property var networkService: null
    property var bluetoothService: null
    property var volumeService: null
    property var mediaService: null
    property var batteryService: null
    property var notificationService: null
    property var weatherService: null

    // Injectable clock, so the header is deterministic under test. Production
    // never assigns it and follows the wall clock through `liveClock`.
    //
    // The binding IS the override mechanism. `new Date()` as a plain initialiser
    // is evaluated once, which is why a retained overview used to freeze on the
    // minute it was opened; a live clock the tick advances fixes that. Assigning
    // `now` - a test freezing the header at a fixed moment - removes the binding,
    // and the tick's later writes to `liveClock` can then no longer reach that
    // value. Measured rather than assumed, because the whole override story rests
    // on it: after such an assignment the property does NOT re-attach to the next
    // `liveClock` write, through either createObject properties or a plain
    // assignment.
    property date now: root.liveClock
    // What the clock tick writes. Published so a test can read the value the tick
    // itself produced, not only its effect on the rendered header strings.
    property date liveClock: new Date()
    // Tick period, in milliseconds. Exposed so a behaviour test can drive the
    // real Timer quickly instead of calling a function production never calls.
    property int clockTickInterval: 1000

    // Focus landings, so a caller can prove the route's own focus target was used
    // rather than the launcher's search field. Diagnostics only.
    readonly property int focusDefaultCount: _focusDefaultCount
    property int _focusDefaultCount: 0

    // --- Wave route-page contract ---

    readonly property string title: "Control Center"
    readonly property string description: "System, audio and media"
    // No rail entries: the host hides the sidebar for an empty list, so the page
    // fills the full width instead of reserving an empty 176px column.
    readonly property var sidebarEntries: []
    readonly property string activeSidebarId: ""

    // --- Same-surface sub-pages ---
    //
    // The network and Bluetooth details are SUB-PAGES of this route, not sibling
    // Wave routes: the host keeps ONE Loader on ONE surface, and this page swaps
    // what that Loader shows. So the names come from the module - which is where
    // they are declared - and a name the module does not declare mounts nothing.
    //
    // Empty string is the overview. It is not a route name, so it can never be
    // confused with one, and no caller has to invent a third vocabulary.
    property string activeSubPage: ""
    readonly property bool detailActive: root.activeSubPage !== ""

    // The overview is a top-level route with nothing to pop, and a sub-page
    // always has the overview to pop back to. So this is exactly the mirror of
    // `detailActive`: it is the ONE place that decides whether a back press
    // belongs to this page or to the surface.
    readonly property bool canGoBack: root.detailActive

    // Back is route-local. With no sub-page mounted there is nothing to pop, so
    // the page reports it cannot handle the press - which is what lets the host
    // fall through to closing the surface. With one mounted, it pops it and
    // reports the refresh for the next turn.
    function handleBack() {
        if (!root.detailActive)
            return false
        root.closeSubPage()
        return true
    }

    // Where keyboard focus lands when this route opens. The page itself, never a
    // control: the cards join the tab chain on their own, so Tab moves from here
    // into the first ready card without the host having to know which that is.
    //
    // While a sub-page is mounted, the focus target is that page's own: a card
    // under an invisible overview must not swallow the keystroke meant for the
    // password field.
    function focusDefault() {
        root._focusDefaultCount++
        if (root.detailActive && root.detailPageItem !== null
                && typeof root.detailPageItem.focusDefault === "function") {
            root.detailPageItem.focusDefault()
            return
        }
        root.forceActiveFocus()
    }

    // Switch to one same-surface sub-page by name. An unknown name opens nothing
    // rather than an empty page, so a typo in a caller cannot produce a blank
    // viewport that looks like a load failure.
    function requestSubPage(route) {
        if (!CcLogic.isDetailRoute(route))
            return false
        root._subPageOpenCount++
        root.activeSubPage = route
        // Hand focus to the page that just mounted, one turn later: a Loader
        // builds its item ASYNCHRONOUSLY, so reading `detailPageItem` in the
        // same turn as the route change reads null (or the page being replaced),
        // and focusing the outgoing one would put the caret in an invisible page.
        subPageFocusTimer.restart()
        return true
    }

    Timer {
        id: subPageFocusTimer
        interval: 0
        repeat: false
        onTriggered: {
            var page = root.detailPageItem
            if (page !== null && typeof page.focusDefault === "function")
                page.focusDefault()
        }
    }

    // Pop the sub-page. The overview is restored in THIS turn - the retained
    // layout is never torn down - and the status refresh is scheduled for the
    // next one.
    function closeSubPage() {
        root.activeSubPage = ""
        returnRefreshTimer.restart()
    }

    // The deferred refresh, deferred because doing it in the same turn as the pop
    // meant the overview's own cards were still bound to the pre-return state:
    // the summary lagged a whole frame behind the operation that caused it.
    //
    // A Timer rather than Qt.callLater for the reason LauncherPage gives: a
    // queued closure can outlive the page it belongs to.
    function refreshAfterReturn() {
        root._returnRefreshCount++
        var service = root.networkService
        if (service && typeof service.refreshForOpen === "function")
            service.refreshForOpen()
    }

    // One turn of separation between restoring the overview and refreshing it.
    // The overview is the owner, so this timer outlives the sub-page it was
    // scheduled alongside.
    Timer {
        id: returnRefreshTimer
        interval: 0
        repeat: false
        onTriggered: root.refreshAfterReturn()
    }

    // --- Requests out of the page ---
    //
    // A card's activation is a REQUEST, and this page is also the component that
    // answers it: the details live here, so the request never leaves the route.
    signal networkDetailsRequested()
    signal bluetoothDetailsRequested()
    signal notificationsOpenRequested()

    // --- Service snapshots ---
    //
    // Each snapshot is a plain object built from whatever the injected service
    // happens to expose. ControlCenterLogic.normalizeCard turns it into the card
    // the frame renders, so every state decision (ready / loading / unavailable /
    // empty / error, the summary wording, the action) is the module's and not this
    // file's. A fake that omits a property yields undefined, which the module
    // already treats as "nothing to report".

    // The connected Wi-Fi network's name.
    //
    // NetworkService has NO flat activeSsid: it keeps a `networks` scan map keyed
    // by SSID whose entry carries `ssid` and `connected`, and it reassigns that
    // whole map on every status change - which is exactly the notification a
    // binding needs, so reading it here stays live. A flat accessor, if some
    // service ever grows one, still wins, so this is a fallback rather than a
    // second source of truth.
    //
    // Only the connected entry is consulted, and the module's own ladder still
    // decides what the card says: an ethernet-only link never reaches this value,
    // and a connected link whose entry the scan has not reported yet still falls
    // back to the module's "Connected".
    readonly property string connectedWifiSsid: {
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

    readonly property var networkSnapshot: {
        var service = root.networkService
        if (!service)
            return { available: false }
        return {
            available: true,
            wifiEnabled: service.wifiEnabled !== false,
            wifiConnected: service.wifiConnected === true,
            activeSsid: root.connectedWifiSsid,
            ethernetConnected: service.ethernetConnected === true,
            activeEthernetConnection: String(
                service.activeEthernetConnection == null
                    ? "" : service.activeEthernetConnection),
            // An in-flight scan or connection is the adapter's loading state.
            loading: service.scanningActive === true || service.connecting === true,
            error: String(service.lastError == null ? "" : service.lastError)
        }
    }

    readonly property var bluetoothSnapshot: {
        var service = root.bluetoothService
        if (!service)
            return { available: false }
        return {
            // An adapter that does not exist is unavailable; one that is rfkilled
            // or powered off is still a present adapter, so it reports through
            // enabled/blocked and stays legible instead of going inert.
            available: service.bluetoothAvailable !== false,
            enabled: service.enabled === true,
            blocked: service.blocked === true,
            scanningActive: service.scanningActive === true,
            devices: service.devices,
            connectedDevices: service.connectedDevices,
            loading: service.scanningActive === true,
            error: ""
        }
    }

    readonly property var volumeSnapshot: {
        var service = root.volumeService
        if (!service)
            return { available: false }
        return {
            available: true,
            sinkVolume: Number(service.sinkVolume),
            sinkMuted: service.sinkMuted === true
        }
    }

    readonly property var mediaSnapshot: {
        var service = root.mediaService
        if (!service)
            return { available: false }
        return {
            available: true,
            hasPlayer: service.hasPlayer !== false,
            title: String(service.title == null ? "" : service.title),
            artist: String(service.artist == null ? "" : service.artist),
            playing: service.playing === true,
            playbackState: String(
                service.playbackState == null ? "" : service.playbackState),
            canGoPrevious: service.canGoPrevious === true,
            canTogglePlayback: service.canTogglePlayback === true,
            canGoNext: service.canGoNext === true
        }
    }

    // --- Normalized cards ---
    //
    // One call per kind through the module. Nothing in this file decides a state.

    readonly property var networkCardData: CcLogic.normalizeCard("network", root.networkSnapshot)
    readonly property var bluetoothCardData: CcLogic.normalizeCard(
        "bluetooth", root.bluetoothSnapshot)
    readonly property var volumeCardState: CcLogic.normalizeCard("volume", root.volumeSnapshot)
    readonly property var mediaCardState: CcLogic.normalizeCard("media", root.mediaSnapshot)

    readonly property var cardList: [root.networkCardData, root.bluetoothCardData,
        root.volumeCardState, root.mediaCardState]
    readonly property var controlCardKinds: CcLogic.cardKinds

    // Published for probes and tests: the normalized object behind one kind, and
    // the snapshot it was derived from, so an assertion can re-derive it through
    // the module and compare.
    function cardData(kind) {
        for (var i = 0; i < root.cardList.length; i++) {
            if (CcLogic.cardKinds[i] === kind)
                return root.cardList[i]
        }
        return null
    }

    function snapshotFor(kind) {
        if (kind === "network")
            return root.networkSnapshot
        if (kind === "bluetooth")
            return root.bluetoothSnapshot
        if (kind === "volume")
            return root.volumeSnapshot
        if (kind === "media")
            return root.mediaSnapshot
        return null
    }

    // --- Header state ---
    //
    // Optional and never blocking. An absent or failed service renders a value in
    // the header instead of removing it, because a header that appears and
    // disappears with the network is worse than one that says "Unavailable".

    readonly property var weatherSnapshot: {
        var service = root.weatherService
        if (!service)
            return { available: false }
        return {
            available: service.available !== false,
            loading: service.loading === true,
            temperature: Number(service.temperature),
            condition: String(service.condition == null ? "" : service.condition),
            location: String(service.location == null ? "" : service.location),
            // updatedAt is full epoch milliseconds. It is carried through
            // unconverted because the module's weatherState already treats
            // isStale and lastError as the stale answer; no epoch arithmetic
            // happens in this file, so a truncation upstream cannot become a
            // second and wrong notion of staleness here.
            updatedAt: Number(service.updatedAt),
            isStale: service.isStale === true,
            lastError: String(service.lastError == null ? "" : service.lastError)
        }
    }
    readonly property string weatherState: CcLogic.weatherState(root.weatherSnapshot)
    readonly property bool weatherReady: root.weatherState === "ready"
            || root.weatherState === "stale"

    readonly property var batterySnapshot: {
        var service = root.batteryService
        if (!service)
            return { available: false }
        return {
            available: service.available === true,
            ready: service.ready === true,
            percentage: Number(service.percentage),
            charging: service.charging === true,
            pluggedIn: service.pluggedIn === true,
            // The service's own state word (BAT / AC / CHG / ?), not a second
            // vocabulary invented here.
            stateWord: String(service.iconText == null ? "" : service.iconText)
        }
    }
    readonly property bool batteryReady: root.batterySnapshot.ready === true

    // --- Layout mode and section order ---
    //
    // Both come from the module, so the page cannot invent a second breakpoint or
    // a second section vocabulary.

    readonly property string layoutMode: CcLogic.layoutMode(root.width,
        CcLogic.minimumTwoColumnWidth)
    readonly property bool wideLayout: root.layoutMode === "wide"
    readonly property var sections: CcLogic.sectionOrder(root.layoutMode)

    // Fixed geometry tokens. A section's width comes from the page, never from
    // its content, and every label inside it elides - which is what makes "a long
    // label cannot resize the panel" structural rather than a hope.
    readonly property real pagePadding: 24
    readonly property real columnGap: 20
    readonly property real sectionGap: 18
    readonly property real cardGap: 10
    readonly property real cardHeight: 88
    // Explicit minimums for the wide arrangement, where there is room to honour
    // them: the control column keeps a usable card, and the information column
    // keeps a calendar that needs 260px plus its summary.
    readonly property real controlColumnMinimumWidth: 300
    readonly property real infoColumnMinimumWidth: 320
    readonly property real headerHeight: 56

    readonly property real usableWidth: Math.max(0, root.width - root.pagePadding * 2)
    readonly property real leftColumnWidth: Math.max(root.controlColumnMinimumWidth,
        Math.floor((root.usableWidth - root.columnGap) * 0.5))
    readonly property real rightColumnWidth: Math.max(root.infoColumnMinimumWidth,
        root.usableWidth - root.columnGap - root.leftColumnWidth)
    readonly property real wideContentWidth: root.leftColumnWidth + root.columnGap
            + root.rightColumnWidth

    // Per-section slot height, in the current arrangement. Read by offsetInOrder()
    // so the module's order array is what positions anything.
    function sectionHeight(name) {
        if (name === "overview")
            return headerHost.height
        if (name === "controls")
            return controlsColumn.height
        if (name === "notifications")
            return notificationsSection.height
        if (name === "calendar")
            return calendarSection.height
        return 0
    }

    // Cumulative y of one named section inside one order array. One implementation
    // for both arrangements, so wide's right column and narrow's stack cannot
    // compute an offset differently.
    //
    // `belowOverview` prepends the full-width overview band. The wide arrays
    // (["controls"], ["calendar", "notifications"]) describe a COLUMN, so they
    // never mention the band that sits above both columns - and the header is laid
    // out at y 0 inside the same content box. Without that prepend every wide
    // section resolved its offset to 0 and landed on the header's own row.
    function offsetInOrder(order, name, belowOverview) {
        var list = belowOverview === true ? ["overview"].concat(order) : order
        var offset = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i] === name)
                return offset
            offset += root.sectionHeight(list[i])
            if (i < list.length - 1)
                offset += root.sectionGap
        }
        return 0
    }

    implicitWidth: 1024
    implicitHeight: 640

    // The clock tick. It writes `liveClock` and never `now`, so it cannot break the
    // binding an injected clock depends on. It keeps running while the surface is
    // retained rather than only while visible, so a header that was hidden behind
    // another route reads the right time the moment it comes back.
    Timer {
        id: clockTick
        objectName: "clockTick"
        interval: root.clockTickInterval
        repeat: true
        running: true
        onTriggered: root.liveClock = new Date()
    }

    // --- Layout surface ---
    //
    // A vertical-only scroller wrapping every section, so the narrow stack can
    // give height back on a short viewport without the panel ever scrolling
    // sideways: `flickableDirection` is pinned vertical and `contentWidth` is the
    // page's own width, so a horizontal flick has nothing to move.
    Flickable {
        id: layoutSurface
        objectName: "layoutSurface"
        // The overview yields the viewport while a same-surface sub-page is up,
        // and is RESTORED - not rebuilt - on the way back: it stays laid out and
        // retained behind an invisible flag, so returning costs one property
        // write instead of a whole screen of card, calendar and summary
        // delegates. `visible` rather than `active` is what makes that possible.
        visible: !root.detailActive
        x: root.pagePadding
        // The scroller starts at the page padding in BOTH arrangements, because the
        // header is not in a strip above it: it is the first section of the content
        // box, and the wide columns are offset below it (see offsetInOrder). An
        // earlier version reserved `headerHeight + sectionGap` here as well, which
        // left 74px of empty panel above the clock in both layouts - and in wide,
        // where nothing scrolls, that band is pure dead surface.
        y: root.pagePadding
        width: root.usableWidth
        height: Math.max(0, root.height - y - root.pagePadding)
        contentWidth: width
        contentHeight: layoutContent.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        // Wide mode fits its viewport by construction, so the wheel belongs to
        // whatever else owns it; narrow mode scrolls.
        interactive: !root.wideLayout && contentHeight > height

        // The content box every section is placed in. A Flickable re-parents its
        // declarative children into its own contentItem, so this one Item is what
        // the arrangement's geometry is measured against - and declaring it
        // explicitly is what keeps the sections off the Flickable's own built-in
        // content item.
        Item {
            id: layoutContent
            objectName: "layoutContent"
            width: root.wideLayout ? root.wideContentWidth : root.usableWidth
            height: Math.max(
                layoutSurface.contentY + layoutSurface.height,
                root.wideLayout
                    ? Math.max(controlsColumn.y + controlsColumn.height,
                               calendarSection.y + calendarSection.height,
                               notificationsSection.y + notificationsSection.height)
                    : root.offsetInOrder(root.sections.stacked, "calendar")
                        + calendarSection.height)
        }

        // --- Overview section: read-only header ---
        //
        // Clock and date, optional weather, read-only battery. It declares no
        // input handler at all - a band that is not a control cannot invite a
        // click, and the battery block is asserted to stay that way.
        Item {
            id: headerHost
            objectName: "overviewHeader"
            parent: layoutContent
            x: 0
            y: 0
            width: layoutContent.width
            height: root.headerHeight

            // Clock and date, from the injectable `now`.
            Column {
                id: clockColumn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.42
                spacing: 2

                Text {
                    id: clockText
                    width: parent.width
                    text: Qt.formatTime(root.now, "HH:mm")
                    color: LazerTheme.textPrimary
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    id: dateText
                    width: parent.width
                    text: Qt.formatDate(root.now, "yyyy-MM-dd dddd")
                    color: LazerTheme.textMuted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            // Weather: value plus condition, rendered in every state. A stale
            // reading is dimmed rather than removed, so a failed refresh does not
            // make the header jump.
            Row {
                id: weatherHost
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                opacity: root.weatherState === "unavailable" || root.weatherState === "empty"
                         ? LazerTheme.settingsDisabledAlpha : 1

                Behavior on opacity {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
                }

                Text {
                    id: weatherText
                    height: 22
                    verticalAlignment: Text.AlignVCenter
                    text: root.weatherReady
                        ? Math.round(root.weatherSnapshot.temperature) + "°"
                        : (root.weatherState === "loading" ? "…" : "—")
                    color: LazerTheme.textPrimary
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

                Text {
                    id: weatherCondition
                    height: 22
                    verticalAlignment: Text.AlignVCenter
                    text: root.weatherReady ? root.weatherSnapshot.condition
                        : (root.weatherState === "loading" ? "Loading"
                           : (root.weatherState === "stale" ? "Stale" : "Unavailable"))
                    color: root.weatherState === "stale"
                           ? LazerTheme.textMuted : LazerTheme.textPrimary
                    font.pixelSize: 12

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }
            }

            // Battery: read-only. No handler, no focus, nothing to click.
            Item {
                id: batteryState
                objectName: "batteryState"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width * 0.24)
                height: 30
                enabled: false
                opacity: root.batteryReady ? 1 : LazerTheme.settingsDisabledAlpha

                Behavior on opacity {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
                }

                // Square charge bar: the level as a colour block, not a rounded
                // capsule, so it reads as sharp state rather than a pill.
                Rectangle {
                    id: batteryTrack
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 8
                    radius: 0
                    color: LazerTheme.settingsTrack

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                Rectangle {
                    id: batteryFill
                    anchors.left: batteryTrack.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: batteryTrack.width * (root.batteryReady
                        ? Math.max(0, Math.min(1, root.batterySnapshot.percentage / 100)) : 0)
                    height: batteryTrack.height
                    color: root.batterySnapshot.charging ? LazerTheme.osuGreen
                        : LazerTheme.settingsAccent

                    Behavior on width {
                        enabled: !MotionTokens.reducedMotion
                        NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
                    }

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                Text {
                    id: batteryText
                    anchors.right: batteryTrack.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryReady
                        ? (Math.round(root.batterySnapshot.percentage) + "%")
                        : (root.batterySnapshot.available ? "…" : "—")
                    color: LazerTheme.textPrimary
                    font.pixelSize: 12
                    font.weight: Font.DemiBold

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }
            }
        }

        // --- Controls section: the four core controls ---
        //
        // Declared once, in the module's kind order, and positioned by the
        // arrangement rather than by a nested positioner - so wide and narrow read
        // the same four cards.
        Column {
            id: controlsColumn
            objectName: "controlsColumn"
            parent: layoutContent
            spacing: root.cardGap
            x: 0
            y: root.wideLayout ? root.offsetInOrder(root.sections.left, "controls", true)
                               : root.offsetInOrder(root.sections.stacked, "controls")
            width: root.wideLayout ? root.leftColumnWidth : root.usableWidth

            // Network: a click asks for its same-surface detail page.
            ControlCenterCard {
                id: networkCardItem
                objectName: "networkCard"
                width: parent.width
                height: root.cardHeight
                title: root.networkCardData.title
                summary: root.networkCardData.summary
                icon: root.networkCardData.icon
                status: root.networkCardData.status
                available: root.networkCardData.available
                error: root.networkCardData.error
                // An inert card is announced as text carrying its state, never as a
                // button that does nothing. The module already answers "none" for
                // every non-ready status, and this reads that same word.
                Accessible.role: root.networkCardData.action === "detail"
                                 ? Accessible.Button : Accessible.StaticText
                Accessible.name: root.networkCardData.title + ", " + root.networkCardData.summary
                onActivated: root.openNetworkDetails()
            }

            // Bluetooth: the same shape and the same request.
            ControlCenterCard {
                id: bluetoothCardItem
                objectName: "bluetoothCard"
                width: parent.width
                height: root.cardHeight
                title: root.bluetoothCardData.title
                summary: root.bluetoothCardData.summary
                icon: root.bluetoothCardData.icon
                status: root.bluetoothCardData.status
                available: root.bluetoothCardData.available
                error: root.bluetoothCardData.error
                Accessible.role: root.bluetoothCardData.action === "detail"
                                 ? Accessible.Button : Accessible.StaticText
                Accessible.name: root.bluetoothCardData.title + ", "
                    + root.bluetoothCardData.summary
                onActivated: root.openBluetoothDetails()
            }

            // Volume: a slider and a mute button embedded under the card's own
            // title and summary, so neither control ever covers the status line it
            // reports. The card's own activation is the mute toggle, which is why
            // an embedded control has to claim its tap before the card sees it -
            // see claimEmbeddedTap below.
            ControlCenterCard {
                id: volumeCardItem
                objectName: "volumeCard"
                width: parent.width
                height: root.cardHeight
                title: root.volumeCardState.title
                summary: root.volumeCardState.summary
                icon: root.volumeCardState.icon
                status: root.volumeCardState.status
                available: root.volumeCardState.available
                error: root.volumeCardState.error
                Accessible.role: root.volumeCardState.action === "direct"
                                 ? Accessible.Button : Accessible.StaticText
                Accessible.name: root.volumeCardState.title + ", "
                    + root.volumeCardState.summary
                onActivated: root.onVolumeCardActivated()

                // The embedded slider, read-only from the service and one-way into
                // it: the slider reads sinkVolume and asks for changes rather than
                // holding a copy the card's summary could disagree with.
                //
                // Width is handed over as the slider's own requested/available
                // pair, because that component owns its width and would fight an
                // external assignment.
                LazerSettingsSlider {
                    id: volumeSlider
                    objectName: "volumeSlider"
                    x: volumeCardItem.contentPadding
                    y: volumeCardItem.height - volumeSliderHeight - volumeCardItem.contentPadding
                    requestedWidth: Math.max(0, volumeCardItem.width - x * 2
                                              - muteButton.width - root.cardGap)
                    availableWidth: requestedWidth
                    from: 0
                    to: 1
                    stepSize: 0.02
                    value: root.volumeService ? root.volumeService.sinkVolume : 0
                    // A committed step is an embedded-control tap like any other:
                    // the ancestor card's handler still sees this event, and a
                    // scrub must not also toggle mute.
                    onValueModified: next => {
                        root.claimEmbeddedTap()
                        root.setVolume(next)
                    }
                    accessibleName: "Output volume"
                }

                // Mute toggle: a square action, the card's second control. A
                // keyboard activation is routed through activate() too, so the two
                // paths cannot diverge - including the tap claim, since a key press
                // must not leave the next tap unclaimed.
                Rectangle {
                    id: muteButton
                    objectName: "muteButton"
                    x: volumeCardItem.width - volumeCardItem.contentPadding - width
                    y: volumeSlider.y + (volumeSlider.height - height) / 2
                    width: 26
                    height: 26
                    radius: 0
                    color: muteHover.hovered ? LazerTheme.settingsCardHover : "transparent"
                    enabled: root.volumeCardState.action === "direct"
                    opacity: enabled ? 1 : LazerTheme.settingsDisabledAlpha
                    activeFocusOnTab: enabled
                    Accessible.role: enabled ? Accessible.Button : Accessible.StaticText
                    Accessible.name: root.volumeService && root.volumeService.sinkMuted
                                         ? "Unmute" : "Mute"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    // The programmatic activation path, matching ControlCenterCard's
                    // own activate() so a test and a key press agree.
                    function activate() {
                        if (!muteButton.enabled)
                            return
                        root.claimEmbeddedTap()
                        root.toggleMute()
                    }

                    Image {
                        id: muteGlyph
                        anchors.fill: parent
                        anchors.margins: 3
                        // The bar's own asset set, swapped on state: the muted glyph
                        // is a different shape, not a recoloured one.
                        source: root.volumeService && root.volumeService.sinkMuted
                            ? "../bar/icons/volume-muted.svg" : "../bar/icons/volume.svg"
                        fillMode: Image.PreserveAspectFit
                        opacity: muteButton.enabled ? 1 : LazerTheme.settingsDisabledAlpha
                    }

                    HoverHandler { id: muteHover; enabled: muteButton.enabled }

                    TapHandler {
                        enabled: muteButton.enabled
                        onTapped: muteButton.activate()
                    }

                    Keys.onPressed: event => {
                        if (!muteButton.enabled)
                            return
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space) {
                            muteButton.activate()
                            event.accepted = true
                        }
                    }
                }
            }

            // Media: transport on its own row, gated on the player's own
            // capability, so a player that cannot go next has no live next button
            // rather than one that does nothing.
            ControlCenterCard {
                id: mediaCardItem
                objectName: "mediaCard"
                width: parent.width
                height: root.cardHeight
                title: root.mediaCardState.title
                summary: root.mediaCardState.summary
                icon: root.mediaCardState.icon
                status: root.mediaCardState.status
                available: root.mediaCardState.available
                error: root.mediaCardState.error
                Accessible.role: root.mediaCardState.action === "direct"
                                 ? Accessible.Button : Accessible.StaticText
                Accessible.name: root.mediaCardState.title + ", " + root.mediaCardState.summary
                onActivated: root.onMediaCardActivated()

                // Transport buttons. The model carries ONLY what identifies a
                // button, and nothing in it is bound to the player's state: a
                // Repeater rebuilds every delegate when its model changes, so a
                // model whose glyph, label or enabled flag came from `playing` or
                // from a capability flag replaced all three buttons - and the
                // keyboard focus the user had parked on one - on every play/pause.
                // The dynamic words are therefore read inside the delegate, where
                // they are ordinary bindings on properties that already exist.
                Row {
                    id: mediaTransport
                    objectName: "mediaTransport"
                    x: mediaCardItem.contentPadding
                    y: mediaCardItem.height - 26 - mediaCardItem.contentPadding
                    spacing: root.cardGap

                    Repeater {
                        // Constant by construction: nothing here reads a service, so
                        // this array is evaluated once and never reassigned.
                        model: [
                            { id: "previous", action: "previous", capability: "canGoPrevious" },
                            { id: "toggle", action: "playPause", capability: "canTogglePlayback" },
                            { id: "next", action: "next", capability: "canGoNext" }
                        ]

                        delegate: Rectangle {
                            id: transportButton
                            required property var modelData
                            readonly property string transportId: String(modelData.id)
                            readonly property Item glyphItem: transportGlyph

                            // Everything the player decides, read here and nowhere
                            // else: the model's own words are the player's, named by
                            // the snapshot key it belongs to.
                            readonly property bool mediaEnabled:
                                root.mediaSnapshot[modelData.capability] === true
                            readonly property string glyph: transportButton.transportId === "toggle"
                                ? (root.mediaSnapshot.playing
                                   ? "icons/pause.svg" : "icons/play.svg")
                                : "icons/" + transportButton.transportId + ".svg"
                            readonly property string label: transportButton.transportId === "toggle"
                                ? (root.mediaSnapshot.playing ? "Pause" : "Play")
                                : (transportButton.transportId === "previous"
                                   ? "Previous" : "Next")

                            width: 26
                            height: 26
                            radius: 0
                            color: transportHover.hovered ? LazerTheme.settingsCardHover
                                                          : "transparent"
                            enabled: transportButton.mediaEnabled
                            opacity: enabled ? 1 : LazerTheme.settingsDisabledAlpha
                            activeFocusOnTab: enabled
                            Accessible.role: enabled ? Accessible.Button : Accessible.StaticText
                            Accessible.name: transportButton.label

                            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                            // The programmatic activation path, matching
                            // ControlCenterCard's own activate().
                            function activate() {
                                if (!transportButton.enabled)
                                    return
                                root.claimEmbeddedTap()
                                root.mediaAction(transportButton.modelData.action)
                            }

                            Image {
                                id: transportGlyph
                                anchors.fill: parent
                                anchors.margins: 3
                                source: transportButton.glyph
                                fillMode: Image.PreserveAspectFit
                                opacity: transportButton.enabled ? 1
                                    : LazerTheme.settingsDisabledAlpha
                            }

                            HoverHandler { id: transportHover; enabled: transportButton.enabled }

                            TapHandler {
                                enabled: transportButton.enabled
                                onTapped: transportButton.activate()
                            }

                            Keys.onPressed: event => {
                                if (!transportButton.enabled)
                                    return
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                        || event.key === Qt.Key_Space) {
                                    transportButton.activate()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Calendar section ---
        //
        // The month grid and its math belong to ControlCenterCalendar, which
        // renders the bar module's own ClockCalendar.js. The page only gives it a
        // width and a place.
        ControlCenterCalendar {
            id: calendarSection
            objectName: "calendar"
            parent: layoutContent
            x: root.wideLayout ? root.leftColumnWidth + root.columnGap : 0
            y: root.wideLayout ? root.offsetInOrder(root.sections.right, "calendar", true)
                               : root.offsetInOrder(root.sections.stacked, "calendar")
            width: root.wideLayout ? root.rightColumnWidth : root.usableWidth
        }

        // --- Notifications section ---
        //
        // Bounded by its own cap. The page passes the module's fixed constant, never
        // a value derived from the incoming history, so a busy history cannot
        // reshape the layout.
        ControlCenterNotifications {
            id: notificationsSection
            objectName: "notifications"
            parent: layoutContent
            x: root.wideLayout ? root.leftColumnWidth + root.columnGap : 0
            y: root.wideLayout ? root.offsetInOrder(root.sections.right, "notifications", true)
                               : root.offsetInOrder(root.sections.stacked, "notifications")
            width: root.wideLayout ? root.rightColumnWidth : root.usableWidth
            notificationService: root.notificationService
            maxEntries: CcLogic.notificationEntryCap
            onOpenRequested: root.notificationsOpenRequested()
        }
    }

    // --- Same-surface sub-page slot ---
    //
    // ONE Loader for the whole route, holding whichever detail page is active.
    // It is inside this page, not inside the wave host, which is what makes the
    // details sub-pages: the host keeps a single retained Loader on a single
    // surface, and this swaps its content without a route change, a cross-fade,
    // a second window, or a coordinator hand-off.
    //
    // `active` is bound to the active sub-page, so a page with none mounted pays
    // for nothing, and the two Components are created lazily on first use rather
    // than at the shell's startup.
    Loader {
        id: subPageLoader
        objectName: "controlCenterSubPage"
        anchors.fill: parent
        active: root.detailActive
        visible: root.detailActive
        // Route-selected by name from the module's own detail routes, so a caller
        // cannot mount an arbitrary component under a detail route's name.
        sourceComponent: root.activeSubPage === CcLogic.detailRoutes.network
            ? networkDetailComponent
            : (root.activeSubPage === CcLogic.detailRoutes.bluetooth
               ? bluetoothDetailComponent : null)
    }

    // The network detail sub-page. It receives the SAME injected service the
    // overview reads, so the two pages can never disagree about the state.
    Component {
        id: networkDetailComponent
        ControlCenterNetwork {
            networkService: root.networkService
            onBackRequested: root.closeSubPage()
        }
    }

    // The Bluetooth detail sub-page, same arrangement.
    Component {
        id: bluetoothDetailComponent
        ControlCenterBluetooth {
            bluetoothService: root.bluetoothService
            onBackRequested: root.closeSubPage()
        }
    }

    // The slider's own height, so the volume card can place it against its bottom
    // edge without hardcoding the component's 30px.
    readonly property int volumeSliderHeight: volumeSlider.height > 0
            ? volumeSlider.height : 30

    // --- Embedded-control tap arbitration ---
    //
    // Qt delivers a tap to the DEEPEST handler first and then still delivers it to
    // every ancestor handler (measured under this repo's offscreen test platform,
    // not assumed). So a tap on the volume slider also reaches the volume card's
    // own TapHandler: without an arbitration step, every scrub would toggle mute.
    //
    // An embedded control therefore claims the tap it took and the card's
    // activation consults the claim. Latched rather than passed as an argument,
    // because the two are separate signals with no parameter carrying state between
    // them. Released on the next event-loop turn so the next tap starts clean; a
    // Timer rather than Qt.callLater, for the reason LauncherPage gives: a queued
    // closure can outlive the page it belongs to.
    property bool _embeddedControlTap: false

    function claimEmbeddedTap() {
        root._embeddedControlTap = true
        embeddedTapReset.restart()
    }

    Timer {
        id: embeddedTapReset
        interval: 0
        repeat: false
        onTriggered: root._embeddedControlTap = false
    }

    // The volume card's own activation is the mute toggle: it is the one direct
    // action the module assigns the kind, and it is what a tap on the card's dead
    // space should do. An embedded control's tap is not the card's.
    function onVolumeCardActivated() {
        if (root._embeddedControlTap)
            return
        if (root.volumeCardState.action !== "direct")
            return
        root.toggleMute()
    }

    // The media card's own activation is play/pause, for the same reason.
    function onMediaCardActivated() {
        if (root._embeddedControlTap)
            return
        if (root.mediaCardState.action !== "direct")
            return
        if (!root.mediaSnapshot.canTogglePlayback)
            return
        root.mediaAction("playPause")
    }

    // --- Control actions ---
    //
    // Each one is a single call into the injected service and nothing else. An
    // absent service means its card is not `direct`, so these guards never fire on
    // the missing-service path; they exist so a partial fake cannot throw.

    function setVolume(value) {
        if (!root.volumeService || typeof root.volumeService.setSinkVolume !== "function")
            return
        var requested = Number(value)
        // An unusable value clamps to the bottom rather than reaching PipeWire:
        // Math.max/min pass NaN straight through, and a NaN volume is a sink the
        // shell can no longer describe.
        if (!isFinite(requested))
            requested = 0
        root.volumeService.setSinkVolume(Math.max(0, Math.min(1, requested)))
    }

    function toggleMute() {
        if (!root.volumeService || typeof root.volumeService.toggleSinkMute !== "function")
            return
        root.volumeService.toggleSinkMute()
    }

    function mediaAction(action) {
        var service = root.mediaService
        if (!service || typeof service[action] !== "function")
            return
        if (action === "playPause" && service.canTogglePlayback !== true)
            return
        if (action === "previous" && service.canGoPrevious !== true)
            return
        if (action === "next" && service.canGoNext !== true)
            return
        service[action]()
    }

    // --- Detail-page requests ---
    //
    // The overview's own answer to a detail request: announce it, then mount the
    // page. The card's activation is gated on the module's action, so an inert
    // card - loading, empty or failed - neither announces nor mounts anything.
    function openNetworkDetails() {
        if (root.networkCardData.action !== "detail")
            return
        root.networkDetailsRequested()
        root.requestSubPage(CcLogic.detailRoutes.network)
    }

    function openBluetoothDetails() {
        if (root.bluetoothCardData.action !== "detail")
            return
        root.bluetoothDetailsRequested()
        root.requestSubPage(CcLogic.detailRoutes.bluetooth)
    }

    // --- Test and host seams ---

    // The clock timer itself, so a probe can read its period and running state
    // instead of inferring them from the rendered header.
    readonly property var clockTickTimer: clockTick

    readonly property var controlCards: [networkCardItem, bluetoothCardItem,
        volumeCardItem, mediaCardItem]
    readonly property int controlCardCount: root.controlCards.length

    readonly property Item networkCard: networkCardItem
    readonly property Item bluetoothCard: bluetoothCardItem
    readonly property Item volumeCard: volumeCardItem
    readonly property Item mediaCard: mediaCardItem

    readonly property Item volumeSliderItem: volumeSlider
    readonly property Item muteButtonItem: muteButton
    readonly property Item mediaPreviousButtonItem: transportItem("previous")
    readonly property Item mediaPlayPauseButtonItem: transportItem("toggle")
    readonly property Item mediaNextButtonItem: transportItem("next")

    // Resolve one transport button by its declared id. `children` includes the
    // Repeater's role-less placeholder, so this filters on a declared delegate
    // property instead of counting children.
    function transportItem(transportId) {
        var kids = mediaTransport.children
        for (var i = 0; i < kids.length; i++) {
            if (kids[i].transportId !== undefined
                    && String(kids[i].transportId) === transportId)
                return kids[i]
        }
        return null
    }

    readonly property Item batteryStateItem: batteryState
    readonly property Item batteryTextItem: batteryText
    readonly property Item clockTextItem: clockText
    readonly property Item dateTextItem: dateText
    readonly property Item weatherTextItem: weatherText
    readonly property Item weatherConditionItem: weatherCondition
    readonly property Item weatherStateItem: weatherHost
    readonly property Item headerItem: headerHost
    readonly property Item controlsColumnItem: controlsColumn
    readonly property Item leftColumnItem: controlsColumn
    readonly property Item layoutSurfaceItem: layoutSurface
    readonly property Item layoutContentItem: layoutContent
    // The overview's own scroller, published as one name because "is the
    // overview on screen" is the other half of "is a sub-page on screen" - two
    // separate items flipping independently is how a page ends up showing both
    // or neither.
    readonly property Item overviewItem: layoutSurface
    // The mounted sub-page, or null when the overview is showing. Read through
    // this one accessor so a caller never has to know which page is mounted or
    // how the Loader spells it.
    readonly property Item detailPageItem: subPageLoader.item
    readonly property Item subPageLoaderItem: subPageLoader
    // Counters for the refresh handshake, so the deferral is observable rather
    // than inferred from a service's side effects.
    readonly property int returnRefreshCount: _returnRefreshCount
    property int _returnRefreshCount: 0
    readonly property int subPageOpenCount: _subPageOpenCount
    property int _subPageOpenCount: 0
    readonly property Item calendarItem: calendarSection
    readonly property Item notificationsItem: notificationsSection

    // No battery card exists. Published as an explicit null so a caller can ask the
    // question instead of inferring the answer from a list.
    readonly property Item batteryCard: null

    readonly property int entryCount: notificationsSection.entryCount

    // A named section of the current arrangement, resolved by the module's own
    // section vocabulary rather than by a hardcoded id list.
    function sectionItem(sectionName) {
        if (sectionName === "controls")
            return controlsColumn
        if (sectionName === "calendar")
            return calendarSection
        if (sectionName === "notifications")
            return notificationsSection
        if (sectionName === "overview")
            return headerHost
        return null
    }

    // How many of the module's sections this arrangement renders. Both render
    // every section, so a stacked layout is not a pager and the wide surface is
    // not missing one.
    readonly property int visibleSectionCount: root.sections.stacked.length
}
