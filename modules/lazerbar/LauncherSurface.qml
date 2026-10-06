pragma ComponentBehavior: Bound
import QtQuick
import "../../services/launcher"
import "LauncherSurfaceLogic.js" as Logic

// Self-contained launcher overlay stack: the wave surface, its launcher page,
// and the session↔surface mirror that routes every open intent (bar entry,
// keyboard IPC) through one coordinator-serialized path. Mount inside a
// full-screen owner window and pass the owning OverlayCoordinator so launcher
// transitions serialize with settings/music; production binds
// Services.LauncherService as the shared session.
Item {
    id: root

    // Shared session contract; defaults to an embedded Quickshell-free
    // session so tests can instantiate the stack standalone.
    property var session: embeddedSession
    // Owning serialization coordinator; null keeps the stack self-contained.
    property var coordinator: null

    // --- Injected services for the control-center view ---
    //
    // The control center is a VIEW inside the launcher page rather than a route on
    // this surface, so its services are injected rather than imported: the bar
    // that mounts this surface passes the Services.* singletons in production, and
    // a test passes fakes. That keeps this file loadable by the component suite
    // with no Quickshell module, and keeps the launcher page the only place that
    // knows what a card reads.
    //
    // Every one defaults to null, which is a defined state rather than a broken
    // one: the page renders its explicit unavailable/optional states for a
    // missing service instead of throwing. Battery stays read-only and weather
    // stays optional - both are forwarded here unchanged and the view decides
    // what an absent service means.
    property var networkService: null
    property var bluetoothService: null
    property var volumeService: null
    property var mediaService: null
    property var batteryService: null
    property var notificationService: null
    property var weatherService: null

    // Exposed for owner-window mask and layer keyboard-focus bindings.
    readonly property alias host: waveHost
    // Exit-card layer above the host, exposed for tests.
    readonly property alias ghostLayer: ghostLayer

    // Opener Item awaiting the coordinated open dispatch (bar entry path).
    property Item pendingOpener: null

    // What a plain open means. The session is a visibility mirror and names no
    // route, so this is what its flips replay whenever no route intent is in
    // flight.
    readonly property string defaultRoute: "launcher"

    // The route the newest open intent asked for. The wave has ONE route left -
    // the control center is a view inside the launcher page, not a sibling route
    // - so this is always `defaultRoute`. It survives as the funnel's own
    // parameter rather than being deleted, because `LauncherSurfaceLogic` makes
    // every open/close decision against the route the caller asked for, and
    // collapsing the parameter would put the comparison back into a hard-coded
    // "launcher" at each call site.
    property string requestedRoute: "launcher"

    // Launcher palette anchored on the osu pink family; the wave bands come
    // from the shared LazerTheme.wavePalette so the launcher and the lock
    // screen sweep the same pinks. Independent of the retired
    // Wiki/News/Beatmap palettes.
    readonly property var launcherPalette: ({
        kind: "pink",
        body: "#33202B",
        header: "#B23A62",
        sidebar: "#3A2531",
        light4: LazerTheme.wavePalette.light4,
        light3: LazerTheme.wavePalette.light3,
        dark4: LazerTheme.wavePalette.dark4,
        dark3: LazerTheme.wavePalette.dark3,
        text: "#FFF2F6",
        muted: "#D9BCC9",
        accent: LazerTheme.osuPink
    })

    LauncherSession { id: embeddedSession }

    function page() { return root.launcherPage }

    // The page the shared wave host currently holds, whatever route it serves.
    // This is the route-safe accessor: `page()` answers only for the launcher.
    function activePage() { return waveHost.routePage }

    // The launcher page, and only while the launcher route owns the surface.
    // `page()` and this are the same object today, and they stay separate on
    // purpose: `page()` is the named contract callers use, while this one states
    // the route condition explicitly so the next real route does not have to
    // rewrite every caller.
    readonly property Item launcherPage: waveHost.loadedRoute === "launcher" ? waveHost.routePage : null

    function snapshot() {
        return {
            sessionVisible: !!root.session && root.session.visible,
            hostPhase: waveHost.phase,
            activeTarget: root.coordinator ? root.coordinator.activeTarget : "",
            transitioning: root.coordinator ? root.coordinator.transitioning : false,
            pendingTarget: root.coordinator ? root.coordinator.pendingTarget : "",
            requestedRoute: root.requestedRoute
        }
    }

    // Land typing in the live search session of the current page instance.
    function focusSearch() {
        var currentPage = root.launcherPage
        if (currentPage)
            currentPage.focusSearch()
    }

    // Focus the active route's own default target: the launcher's search field, or
    // the control-center view's own landing when that view is the one on screen.
    // Going through the page rather than reaching for the editor is what keeps the
    // two from diverging - `LauncherPage.focusDefault` already knows which of the
    // two owns the keyboard, and the hidden search editor refuses focus anyway.
    function focusActivePage() {
        var currentPage = root.activePage()
        if (!currentPage)
            return
        if (typeof currentPage.focusDefault === "function")
            currentPage.focusDefault()
        else if (typeof currentPage.focusSearch === "function")
            currentPage.focusSearch()
    }

    // Every launcher activation funnels here: bar entry, IPC open, or a
    // session-visible flip. The opener Item is recorded so focus returns to
    // it once the surface closes.
    function requestOpen(opener) { requestRoute(root.defaultRoute, opener) }

    // Every activation funnels through one route-parameterised path: bar entry,
    // IPC open, or a session-visible flip. The opener Item is recorded so focus
    // returns to it once the surface closes.
    function requestRoute(route, opener) {
        root.requestedRoute = route
        var action = Logic.openAction(snapshot())
        if (action === "open-session") {
            pendingOpener = opener || null
            if (root.session)
                root.session.open()
            return
        }
        if (action === "refocus-search") {
            focusActivePage()
            return
        }
        if (action === "reopen-host") {
            reopenHost(route, opener)
            return
        }
        if (root.coordinator)
            root.coordinator.request(route, opener, true, true)
    }

    // Recall the same live instance while it is mid-close (or queued behind
    // another owner's close): stop the close, drop any superseded hand-off,
    // record the newest opener for restoration, and reopen in place so the
    // latest open request is never swallowed.
    function reopenHost(route, opener) {
        pendingOpener = opener || null
        if (root.coordinator) {
            if (root.coordinator.transitioning)
                root.coordinator.cancelPending()
            root.coordinator.opener = opener || null
        }
        waveHost.openRoute(route, null)
    }

    // Mirror session visibility onto the surface; also runs for programmatic
    // open/close from the keyboard IPC path.
    function syncVisibility() {
        if (!root.session)
            return
        if (root.session.visible) {
            // `requestedRoute` is the newest intent, not a remembered outcome:
            // a genuine close puts it back to the default, so a session-visible
            // flip never carries a route from an open that already ended.
            requestRoute(root.requestedRoute, pendingOpener)
        } else {
            var action = Logic.closeAction(snapshot())
            if (action === "request-coordinated-close" && root.coordinator)
                root.coordinator.request(root.requestedRoute)
            else if (action === "cancel-stale-open" && root.coordinator)
                root.coordinator.pendingTarget = ""
        }
        pendingOpener = null
    }

    Connections {
        target: root.session
        function onVisibleChanged() { root.syncVisibility() }
    }

    Connections {
        target: waveHost
        function onOpened() {
            // The surface grabbed focus on dispatch; land the route's own focus
            // target only when it genuinely owns the coordinator now, which
            // covers both direct opens and opens queued behind another owner's
            // close.
            if (root.coordinator && root.coordinator.activeTarget === waveHost.route)
                root.focusActivePage()
        }
        function onRouteSwapped() {
            // A route swap crosses over inside the live surface, so no open
            // event fires for the page that was just mounted - and a freshly
            // mounted page holds no keyboard focus, which would leave the
            // surface open with nowhere to type. The owner check is skipped
            // here on purpose: a swap is not a coordinator hand-off, it is the
            // already-open surface changing what it shows.
            root.focusActivePage()
        }
        function onClosed() {
            // A close is not always a hide. The coordinator closes this owner to
            // hand it a sibling route, and that close ends in this same signal:
            // `ownerClosed` dispatches the next route synchronously, so the
            // session mirror below would run against a surface that has just
            // been reopened and ask it to close again - the hand-off would land
            // shut, with the coordinator left owning nothing.
            var outcome = root.coordinator ? root.coordinator.ownerClosed("wave") : "released"
            if (outcome === "reopened")
                return
            // A real close, so nothing is in flight. Drop the sticky route with
            // it: the session names no route, and the next session-visible flip
            // replays `requestedRoute`, so an intent from an open that already
            // ended would leak into the next one. Default opens go back to the
            // launcher.
            root.requestedRoute = root.defaultRoute
            if (root.session && root.session.visible)
                root.session.close()
        }
    }

    // Probe/test access to the hosted page.
    property alias waveHostItem: waveHost

    Timer {
        id: prewarmArmTimer
        interval: 0
        repeat: false
        // The launcher page is a cold-path prewarm, not startup chrome. Hold
        // it until the shell's quiet-ready window so its delegate construction
        // cannot compete with wallpaper reveal or first bar staging.
        running: !!root.session && root.startupPrewarmAllowed === true
        onTriggered: waveHost.prewarmRoute()
    }

    // Production owners set this after quiet-ready; standalone tests keep the
    // historical default so the component remains self-contained.
    property bool startupPrewarmAllowed: true

    WaveSurfaceHost {
        id: waveHost
        anchors.fill: parent
        // Chrome is read from the active route page through the shared page
        // contract, so a route renders its own header without the host knowing
        // anything about it. With the control center folded into the launcher
        // page, that page answers for the header of whichever view it is
        // showing, and the host is unchanged by either.
        title: {
            var currentPage = root.activePage()
            return currentPage && currentPage.title !== undefined
                    ? String(currentPage.title) : "Launcher"
        }
        description: {
            var currentPage = root.activePage()
            return currentPage && currentPage.description !== undefined
                    ? String(currentPage.description) : ""
        }
        titleIcon: {
            var currentPage = root.activePage()
            return currentPage && currentPage.titleIcon !== undefined
                    ? String(currentPage.titleIcon) : ""
        }
        sectionEntries: {
            var currentPage = root.activePage()
            return currentPage && currentPage.sectionEntries !== undefined
                    ? currentPage.sectionEntries : []
        }
        activeSectionId: {
            var currentPage = root.activePage()
            if (!currentPage)
                return ""
            if (currentPage.activeSectionId !== undefined)
                return String(currentPage.activeSectionId)
            return currentPage.activeMode !== undefined ? String(currentPage.activeMode) : ""
        }
        pageLabel: {
            var currentPage = root.activePage()
            return currentPage && currentPage.pageLabel !== undefined
                    ? String(currentPage.pageLabel) : ""
        }
        // Chrome layout: read from the session so the IPC/env switch and the
        // body can never disagree, with the block stack as the defined default
        // for a session that publishes nothing (the embedded test session).
        chromeLayout: {
            var layout = root.session && root.session.chromeLayout !== undefined
                    ? String(root.session.chromeLayout) : ""
            return layout === "rail" ? "rail" : "blocks"
        }
        palette: root.launcherPalette
        contentComponent: launcherPageComponent
        routeComponents: root.routeComponents

        onSectionSelected: id => {
            // Contract first, launcher spelling second: the page bar is shared
            // chrome, so the mounted page decides what a section id means. The
            // launcher's own vocabulary is "mode", and its handler keeps that
            // honest name rather than adopting the chrome's.
            var currentPage = root.activePage()
            if (!currentPage)
                return
            if (typeof currentPage.handleSectionSelected === "function")
                currentPage.handleSectionSelected(id)
            else if (typeof currentPage.handleModeSelected === "function")
                currentPage.handleModeSelected(id)
        }
    }

    // Route components for every route this surface serves. The wave has ONE
    // route: the launcher page, which owns the control-center view inside its
    // content area. Registering a route is still the entire wiring - the host
    // selects by route name and keeps one retained Loader across them - so
    // adding a real second route later needs no change here.
    readonly property var routeComponents: ({
        "launcher": launcherPageComponent
    })

    Component {
        id: launcherPageComponent
        LauncherPage {
            session: root.session
            prewarmSlots: root.startupPrewarmAllowed === true
            thumbnailsActive: waveHost.phase === "open"
            // The page's own query surface answers the chrome layout, so the two
            // are a genuine A/B rather than two navigation shapes over one
            // surface: the rail layout restores the full-bleed strip this page
            // had before the three-band stack.
            chromeLayout: waveHost.chromeLayout
            onExitFlingRequested: spec => root.spawnExitCard(spec)
            // The control center's services reach it through this page, which is
            // where its Loader lives. Forwarded unchanged, so the overview and a
            // mounted detail sub-page can never describe two different instances
            // of one service.
            networkService: root.networkService
            bluetoothService: root.bluetoothService
            volumeService: root.volumeService
            mediaService: root.mediaService
            batteryService: root.batteryService
            notificationService: root.notificationService
            weatherService: root.weatherService
        }
    }

    // Ghost layer above the wave host: exit cards continue their parabolic
    // fling here while (and after) the panel closes underneath.
    Item {
        id: ghostLayer
        anchors.fill: parent
        z: 100
    }

    function spawnExitCard(spec) {
        var card = Qt.createComponent("LauncherExitCard.qml")
        if (card.status !== Component.Ready)
            return
        var instance = card.createObject(ghostLayer, {
            x: spec.x, y: spec.y,
            width: spec.width, height: spec.height,
            title: spec.title || "",
            description: spec.description || "",
            iconSource: spec.icon || "",
            accent: !!spec.accent
        })
    }
}
