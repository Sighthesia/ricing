import QtQuick
import "WaveSurfaceLogic.js" as Logic

// Own the fixed wave viewport as a content-agnostic surface for launcher and future routes.
//
// Its body wears one of TWO chrome layouts, both kept because the choice is a
// judgement call no amount of reading settles:
//
//   "blocks" — the wiki three-band stack. Identity masthead, page bar, content
//              column; three full-bleed planes a step lighter than the one above.
//   "rail"   — the earlier settings-panel shape. Masthead, collapsible vertical
//              navigation rail, content column.
//
// They spend different budgets: the rail spends width on navigation and returns
// height to the results; the page bar spends height and returns width. Which
// reads better depends on the display and on the habit of whoever is looking,
// so the layout is a value the owner sets, not one this file decides.
//
// The host knows the chrome and nothing about what fills it: which entries the
// navigation carries, and what the page calls itself, both arrive through the
// route-page contract.
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
    // --- Band 1: the identity masthead ---
    property string title: ""
    property string description: ""
    // Identity glyph for the masthead. Empty is a defined state: the band drops
    // its tile and the title takes the left margin, so a route without a glyph
    // never reserves an empty square.
    property string titleIcon: ""
    // --- Band 2: the page bar ---
    //
    // Section entries are the horizontal tabs that switch what the content
    // column shows (the launcher's modes). They replaced a vertical rail: the
    // row above already declares itself a page row, so a mode switch reads as a
    // page switch and the rail's whole column went back to content height.
    property var sectionEntries: []
    property string activeSectionId: ""
    // The page's own name for band 2's left-hand slot. Empty means "use the
    // active section's label" — the common case, where the page name IS the
    // selected tab. A route whose name comes from somewhere else (the control
    // center's sub-page stack) publishes it instead.
    property string pageLabel: ""
    // Band 2's left-hand slot, resolved: an explicit pageLabel wins, otherwise
    // the page name IS the selected tab's label. Derived here rather than in
    // each route so the two spellings cannot disagree.
    readonly property string resolvedPageLabel: {
        if (root.pageLabel !== "")
            return root.pageLabel
        var entries = root.sectionEntries || []
        for (var i = 0; i < entries.length; i++)
            if (entries[i].id === root.activeSectionId)
                return String(entries[i].label || "")
        return ""
    }
    // Which chrome the body wears: "blocks" (the wiki three-band stack) or
    // "rail" (masthead + collapsible vertical navigation). Both are real code
    // paths, not a variant with a dead branch — see the file comment for why
    // neither is going away.
    property string chromeLayout: "blocks"
    readonly property bool railChrome: root.chromeLayout === "rail"
    // Rail collapse state and width. Only the rail layout reads them; the page
    // bar has no such affordance, which is one of the two layouts' differences
    // rather than a missing feature in either.
    property bool railExpanded: true
    readonly property int railWidth: root.railExpanded
            ? LazerTheme.settingsSidebarExpandedWidth : LazerTheme.settingsSidebarContractedWidth
    // No hairline between the rail and the content column: the rail tone
    // already separates them, and a 1px rule through the query strip read
    // as a stray tick (visible in light mode even after insetting it below
    // the strip). Matches the block stack, which likewise draws no
    // dividers between bands.
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
    property alias contentItem: routeLoader.item
    // The retained page of the currently loaded route. Every host decision that
    // needs page content reads it through this one accessor, so no caller has to
    // know which route is mounted.
    readonly property alias routePage: routeLoader.item
    property alias waveRepeater: waveLayers.waveRepeater

    signal closed()
    signal opened()
    // The cross-fade between two sibling routes finished: `route` and the
    // mounted page are the new pair and the surface is still open. Distinct
    // from `opened()`, which a swap never emits.
    signal routeSwapped(string route)
    signal sectionSelected(string id)

    // Construct the real route during the shell's idle window. The host stays
    // invisible and disabled while closed, so cold QML and delegate work is
    // paid before the first visible opening instead of during it.
    function prewarmRoute() {
        root.routeRetained = true
        if (routeLoader.item && routeLoader.item.prewarmSlots !== undefined)
            routeLoader.item.prewarmSlots = true
    }

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
    //
    // The page's half of the contract is both halves or neither: a page that
    // publishes `canGoBack: true` with no callable `handleBack()` would take
    // every Escape press and do nothing with it, and since the page - not the
    // host - is the authority here, nothing could clear the claim afterwards.
    // That is a surface nobody can close, so a missing handler means the host
    // offers no page back at all and Escape closes as usual.
    readonly property bool canGoBack: {
        var page = routePage
        if (page === null || page.canGoBack === undefined)
            return pageCanGoBack
        if (page.canGoBack !== true)
            return false
        return typeof page.handleBack === "function"
    }

    // Hand a back press to the page. The page owns what "back" means (pop its own
    // detail stack); it reports whether it consumed the press. A page that
    // declines the press (`false`) has advertised a back step it cannot take:
    // asking it again next press would repeat the refusal forever, so the press
    // falls through to the close. Only a host with no contract page at all falls
    // back to clearing its own manual flag, which keeps the surface open for the
    // next press.
    function requestPageBack() {
        var page = routePage
        if (page && typeof page.handleBack === "function") {
            if (page.handleBack() !== false) {
                pageBackHandled()
                return true
            }
            close()
            return true
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
        //
        // Both chrome layouts paint from the same ladder
        // (LazerTheme.overlay*Surface): the "blocks" stack's three bands meet
        // edge to edge because the ladder IS the separation, while the "rail"
        // shape uses only the header rung and carries the navigation beside the
        // content on the content plane. The palette object still drives only
        // the wave backdrop behind them.
        Rectangle {
            id: body
            z: 5
            x: 0
            y: MotionTokens.reducedMotion ? 0 : root.height * (1 - root.bodyProgress)
            width: parent.width
            height: root.height
            radius: 0
            color: LazerTheme.overlayContentSurface
            opacity: root.bodyProgress

            // Band 1 in both layouts: the identity masthead.
            FullscreenHeader {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                title: root.title
                description: root.description
                iconSource: root.titleIcon
                onCloseRequested: root.close()
            }

            // Band 2 of the "blocks" layout: page name plus the section tabs
            // that switch the content column.
            //
            // Declared inline rather than behind a Loader. A Loader sizes the
            // item it loads to ITSELF, and this one is anchored on three sides
            // only — so its height is 0 and it would hand that 0 straight to the
            // band, which then reported no height at all. (A rail is worth a
            // Loader's indirection because its delegates are expensive; three
            // tab delegates are not.)
            OverlayPageBand {
                id: pageBand
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                entries: root.sectionEntries
                selected: root.activeSectionId
                pageLabel: root.resolvedPageLabel
                onSectionSelected: id => root.sectionSelected(id)
                // Collapses for BOTH of the reasons it can be absent: the rail
                // layout replaces it, and a route with no entries has no page bar
                // to show. Zero height is exactly what the content column reads,
                // so either way the content rises to meet band 1.
                height: root.railChrome ? 0 : implicitHeight
                visible: height > 0
            }

            // Navigation rail of the "rail" layout, standing in for band 2. In a
            // Loader because this one genuinely costs to keep alive: every entry
            // builds a nav item with its own icon, effect and animations, and
            // that is precisely what the page-bar layout exists to stop paying.
            Loader {
                id: railLoader
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                active: root.railChrome
                visible: active
                sourceComponent: Component {
                    FullscreenSidebar {
                        entries: root.sectionEntries
                        selected: root.activeSectionId
                        expanded: root.railExpanded
                        width: root.railWidth
                        Behavior on width {
                            enabled: !MotionTokens.reducedMotion
                            NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint }
                        }
                        onSelectedChangedByUser: id => root.sectionSelected(id)
                        onCollapseToggled: root.railExpanded = !root.railExpanded
                    }
                }
            }

            // Content column. It anchors to the page band's BOTTOM edge, which is
            // the masthead's own bottom edge in the rail layout (the band
            // collapses to zero there) and one band lower in the block stack —
            // so no layout branch is needed and the content can never end up
            // painting over the band instead of below it.
            Item {
                id: viewport
                anchors.top: pageBand.bottom
                anchors.left: parent.left
                anchors.leftMargin: root.railChrome ? root.railWidth : 0
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
                    onLoaded: {
                        if (root.routeRetained && item && item.prewarmSlots !== undefined)
                            item.prewarmSlots = true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.loading
                    color: LazerTheme.overlayContentSurface
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
    // osu APPEAR_DURATION: waves ride the same 800ms as the body, OutSine.
    NumberAnimation { id: openWaves; target: root; property: "waveProgress"; to: 1; duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveEnter; easing.type: Easing.OutSine }
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
        // The fade-in landing is the swap's completion: nothing emitted
        // `opened()` here, because the surface never closed, so this is the one
        // moment a caller learns the new page is mounted and can be given its
        // own focus target.
        NumberAnimation {
            target: routeLoader
            property: "opacity"
            to: 1
            duration: MotionTokens.waveRoute / 2
            easing.type: Easing.OutQuad
        }
        // Completion is observed on the sequence, not on the last step: a
        // nested animation's own `onFinished` is never emitted (verified on
        // this Qt), so a handler there would silently never run.
        onFinished: root.routeSwapped(root._loadedRoute)
    }
}
