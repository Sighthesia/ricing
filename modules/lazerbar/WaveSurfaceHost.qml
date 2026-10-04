import QtQuick
import "WaveSurfaceLogic.js" as Logic

// Own the fixed wave viewport as a content-agnostic surface for launcher and future routes.
Item {
    id: root

    property string route: ""
    property string phase: "closed"
    property real bodyProgress: 0
    property real waveProgress: 0
    property bool loading: false
    property bool inputActive: false
    // Manual back flag, for a host mounted without a contract page. The active
    // route page is the authority whenever it publishes `canGoBack`; read
    // canGoBack, never this.
    property bool pageCanGoBack: false
    property Item opener: null
    property string title: ""
    property string description: ""
    property var sidebarEntries: []
    property string activeSidebarId: ""
    // Collapsible settings-style rail; the width eases between the two
    // canonical settings sidebar sizes.
    property bool sidebarExpanded: true
    readonly property int sidebarWidth: root.sidebarExpanded
            ? LazerTheme.settingsSidebarExpandedWidth : LazerTheme.settingsSidebarContractedWidth
    // `final` keeps this intentional name from shadowing Item.palette.
    final property var palette: ({})
    // Route page components, keyed by route name. The host holds no knowledge of
    // what any route contains; registering a component is the whole wiring.
    property var routeComponents: ({})
    // Fallback page for a route with no registered component, and the single
    // content hook a host mounted without a registry keeps using.
    property Component contentComponent: null
    // The route whose component is loaded right now. Unlike `route` this is
    // never cleared on close: the retained page has to outlive the closed phase,
    // and a lookup on an emptied route would resolve to nothing and tear it down.
    property string _loadedRoute: ""
    // Public read of the mounted route. Unlike `route` this survives the close,
    // so a caller asking "which page is retained?" gets an answer while the
    // surface is closed.
    readonly property string loadedRoute: _loadedRoute
    readonly property Component loadedComponent: {
        var registry = root.routeComponents || {}
        var registered = root._loadedRoute !== "" ? registry[root._loadedRoute] : undefined
        return registered !== undefined && registered !== null ? registered : root.contentComponent
    }
    property string _pendingRoute: ""
    // Latched the first time the surface opens: from then on the route stays
    // constructed. See routeLoader.
    property bool routeRetained: false
    readonly property bool interactive: phase === "opening" || phase === "open"
    readonly property real surfaceWidth: Logic.surfaceWidth(width)
    property alias surface: body
    property alias outsideLeft: outsideLeft
    property alias outsideRight: outsideRight
    property alias sidebar: sidebar
    property alias contentItem: routeLoader.item
    // The retained page of the currently loaded route. Every host decision that
    // needs page content reads it through this one accessor, so no caller has to
    // know which route is mounted.
    readonly property alias routePage: routeLoader.item
    property alias waveRepeater: waveLayers.waveRepeater

    signal closed()
    signal opened()
    signal sidebarSelected(string id)

    function openRoute(nextRoute, source) {
        var normalized = Logic.normalizeRoute(nextRoute)
        if (!normalized)
            return false

        if (source)
            opener = source

        if (phase === "open" && route && normalized !== route) {
            _pendingRoute = normalized
            routeSwap.restart()
            return true
        }

        closeBody.stop()
        closeWaves.stop()
        if (phase === "closed") {
            bodyProgress = 0
            waveProgress = 0
        }
        route = normalized
        // The loaded component follows the route, and stays put across a close:
        // only a route change swaps it.
        _loadedRoute = normalized
        // Past the first open the page is kept, so this only ever decides the
        // very first construction.
        root.routeRetained = true
        phase = "opening"
        openBody.restart()
        openWaves.restart()
        forceActiveFocus()
        // Announce after the surface focus grab so listeners can land
        // content focus (search) without losing it back to the shell.
        opened()
        return true
    }

    function close() {        if (!interactive)
            return
        openBody.stop()
        openWaves.stop()
        routeSwap.stop()
        _pendingRoute = ""
        phase = "closing"
        closeBody.restart()
        closeWaves.restart()
    }

    function handleEscape() {
        var action = Logic.escapeAction(inputActive, canGoBack, interactive)
        if (action === "input") { inputActive = false; return true }
        if (action === "back") { requestPageBack(); return true }
        if (action === "close") { close(); return true }
        return false
    }

    // Whether a back press belongs to the page rather than to the surface. A page
    // that publishes `canGoBack` owns the answer outright, so no caller mutates
    // the host; a page that publishes nothing leaves the manual flag in charge,
    // which is what a bare content page has always used.
    readonly property bool canGoBack: routePage !== null
            && routePage.canGoBack !== undefined
            ? routePage.canGoBack === true
            : pageCanGoBack

    // Hand a back press to the page. The page owns what "back" means (pop its own
    // detail stack); it reports whether it consumed the press. Only a page with
    // no handler falls back to the host clearing the manual flag.
    function requestPageBack() {
        var page = routePage
        if (page && typeof page.handleBack === "function") {
            if (page.handleBack() !== false) {
                pageBackHandled()
                return true
            }
        }
        pageCanGoBack = false
        return true
    }

    // The page took the press instead of the surface closing.
    signal pageBackHandled()

    function finishClose() {
        phase = "closed"
        route = ""
        bodyProgress = 0
        waveProgress = 0
        _pendingRoute = ""
        if (opener)
            opener.forceActiveFocus()
        opener = null
        closed()
    }

    // Invisible while closed so the window mask can release the desktop underneath.
    visible: phase !== "closed"
    enabled: visible
    focus: visible
    Keys.onEscapePressed: handleEscape()

    // Capture the exposed left side without passing the closing click to the desktop.
    MouseArea {
        id: outsideLeft
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Math.max(0, (root.width - root.surfaceWidth) / 2)
        enabled: root.interactive
        onClicked: root.close()
    }

    // Capture the exposed right side without expanding the visible body.
    MouseArea {
        id: outsideRight
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: outsideLeft.width
        enabled: root.interactive
        onClicked: root.close()
    }

    // Clip all angled layers to the exact 85% osu overlay viewport below the top bar.
    Item {
        id: clippedViewport
        x: (root.width - width) / 2
        width: root.surfaceWidth
        height: root.height
        clip: true

        WaveRevealLayers {
            id: waveLayers
            progress: root.waveProgress
            palette: root.palette
        }

        // Move the continuous body inside the fixed compositor-facing owner.
        // The body uses the settings-panel surface hierarchy; the palette
        // drives only the wave backdrop behind it.
        Rectangle {
            id: body
            z: 5
            x: 0
            y: MotionTokens.reducedMotion ? 0 : root.height * (1 - root.bodyProgress)
            width: parent.width
            height: root.height
            radius: 0
            color: LazerTheme.settingsPanel
            opacity: root.bodyProgress

            FullscreenHeader {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                title: root.title
                description: root.description
                onCloseRequested: root.close()
            }

            Rectangle {
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: LazerTheme.divider
            }

            FullscreenSidebar {
                id: sidebar
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                entries: root.sidebarEntries
                selected: root.activeSidebarId
                expanded: root.sidebarExpanded
                width: root.sidebarWidth
                visible: root.sidebarEntries.length > 0
                Behavior on width {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint }
                }
                onSelectedChangedByUser: id => root.sidebarSelected(id)
                onCollapseToggled: root.sidebarExpanded = !root.sidebarExpanded
            }

            // Hairline divider between the navigation rail and the content column.
            Rectangle {
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.left: sidebar.visible ? sidebar.right : parent.left
                width: 1
                color: LazerTheme.divider
            }

            Item {
                id: viewport
                anchors.top: header.bottom
                anchors.left: sidebar.visible ? sidebar.right : parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true

                Loader {
                    id: routeLoader
                    anchors.fill: parent
                    // A route page is cold interactive content, so nothing is
                    // built until the first open asks for it - the shell must
                    // not pay for a launcher nobody has opened. From then on it
                    // is retained: a launcher open costs a whole screen of row
                    // delegates, and tearing them down on close meant every
                    // open rebuilt the chrome, the rows, their shaped text and
                    // their icons from nothing. Held live behind a closed wave,
                    // they cost memory and nothing else.
                    active: root.phase !== "closed" || root.routeRetained
                    // Route-selected, so one retained Loader serves every
                    // sibling route; swapping routes swaps the component
                    // without a second window or a second Loader.
                    sourceComponent: root.loadedComponent
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.loading
                    color: LazerTheme.settingsPanel
                    Text { anchors.centerIn: parent; text: "Loading..."; color: LazerTheme.textMuted }
                }
            }
        }
    }

    NumberAnimation {
        id: openBody
        target: root
        property: "bodyProgress"
        to: 1
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveEnter
        easing.type: Easing.OutQuint
        onFinished: if (root.phase === "opening") root.phase = "open"
    }
    // Backdrop waves lead the body so they stay visible while content slides over them.
    NumberAnimation { id: openWaves; target: root; property: "waveProgress"; to: 1; duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveBackdropEnter; easing.type: Easing.OutQuad }
    NumberAnimation {
        id: closeBody
        target: root
        property: "bodyProgress"
        to: 0
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveExit
        easing.type: Easing.InQuad
        onFinished: if (root.phase === "closing") root.finishClose()
    }
    NumberAnimation { id: closeWaves; target: root; property: "waveProgress"; to: 0; duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveExit; easing.type: Easing.InSine }

    SequentialAnimation {
        id: routeSwap
        NumberAnimation { target: routeLoader; property: "opacity"; to: 0; duration: MotionTokens.waveRoute / 2; easing.type: Easing.InQuad }
        ScriptAction { script: {
            // Route and loaded component move together, so the cross-fade always
            // swaps the pair instead of stranding a route name over a page that
            // belongs to the previous one.
            root.route = root._pendingRoute
            root._loadedRoute = root._pendingRoute
            root._pendingRoute = ""
        } }
        NumberAnimation { target: routeLoader; property: "opacity"; to: 1; duration: MotionTokens.waveRoute / 2; easing.type: Easing.OutQuad }
    }
}
