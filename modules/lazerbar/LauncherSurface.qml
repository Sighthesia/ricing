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

    // --- Injected services for the control-center route ---
    //
    // The control center is the one route on this surface that reports system
    // state, so its services are injected rather than imported: the bar that
    // mounts this surface passes the Services.* singletons in production, and a
    // test passes fakes. That keeps this file loadable by the component suite
    // with no Quickshell module, and keeps the route page the only place that
    // knows what a card reads.
    //
    // Every one defaults to null, which is a defined state rather than a broken
    // one: the route page renders its explicit unavailable/optional states for a
    // missing service instead of throwing. Battery stays read-only and weather
    // stays optional - both are forwarded here unchanged and the page decides
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

    // The route the newest open intent asked for. The session mirror reacts to
    // this rather than assuming the launcher, so a control-center open is not
    // turned back into a launcher open by the session turning visible - and it
    // is dropped again on every genuine close, so it only ever describes a
    // request that is still in flight.
    property string requestedRoute: "launcher"

    // Where the newest open intent came from, latched for the same reason and the
    // same lifetime as `requestedRoute`: whether the launcher was the surface's
    // route when this open began is what the control center's back press means,
    // and the route page cannot work it out from inside itself.
    //
    // "Came from the launcher" is read as what is actually on screen - the
    // launcher route loaded AND the surface interactive - rather than from
    // coordinator ownership, because a retained launcher route from an earlier
    // visit must not turn a fresh bar-entry open into "go back to the launcher".
    property bool requestedFromLauncher: false

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

    // The launcher page, and only while the launcher route owns the surface: a
    // control-center open replaces the retained page, and a stale launcher
    // reference would then be a destroyed object.
    readonly property Item launcherPage: waveHost.loadedRoute === "launcher" ? waveHost.routePage : null

    // Whether the launcher is what the user is looking at right now. Both halves
    // matter: the retained route survives every close, so "loaded" alone would
    // answer yes for a surface nobody can see.
    function launcherRouteOnScreen() {
        return waveHost.loadedRoute === "launcher" && waveHost.interactive
    }

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

    // Focus the active route's own default target: the launcher's search field,
    // a sibling route's page decides through the same contract. A control-center
    // open must never steal the launcher's search box.
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

    // The control center is a sibling route on this same surface and session, not
    // a second overlay: one coordinator, one retained Loader, one opener.
    function requestControlCenter(opener) { requestRoute("control-center", opener) }

    // The launcher return that a launcher-entered control center's back press
    // earns. This is the same open continuing on the same surface, NOT a new open
    // intent, so it must not replace the opener record: `requestRoute` hands the
    // coordinator a reset on every call, so returning with no opener would clear
    // the Item focus is restored to when the surface finally closes - the control
    // the user opened this from, thrown away by the press that went back.
    //
    // The record is read back from the coordinator because that is where the
    // focus hand-off is settled and therefore where it lives. Handing the same
    // Item back changes nothing, and when the open had no opener at all this
    // passes null - so a return still never invents one.
    function returnToDefaultRoute() {
        requestRoute(root.defaultRoute, root.coordinator ? root.coordinator.opener : null)
    }

    // The launcher's rail entry for the control center. This is the SAME open
    // continuing on the SAME surface, not a new open intent, so it must not
    // replace the opener record - exactly the rule `returnToDefaultRoute`
    // follows. The record is read back off the coordinator, where the focus
    // hand-off was settled: passing the same Item changes nothing, and an open
    // that never had one still passes null, so a rail switch never invents an
    // opener either.
    //
    // Going through `requestRoute` rather than reaching for the host is what
    // keeps the switch inside the one funnel: it settles to `reopen-host`
    // because this surface is already open, so the route changes on the live
    // host with no coordinator round trip and no second window.
    function requestControlCenterFromLauncher() {
        requestRoute("control-center", root.coordinator ? root.coordinator.opener : null)
    }

    // Every activation funnels through one route-parameterised path: bar entry,
    // IPC open, or a session-visible flip. The opener Item is recorded so focus
    // returns to it once the surface closes.
    function requestRoute(route, opener) {
        root.requestedRoute = route
        // Latch the entry context, but only on a genuine route change.
        //
        // A hand-off re-enters this function a second time: the coordinator
        // closes this owner to give it the sibling route and then dispatches the
        // same route again to reopen it, by which point the coordinator already
        // owns the NEW target. Recomputing there would read "not the launcher"
        // and erase the very fact this open began on the launcher - so the latch
        // is written by the call that changed the route and left alone by the
        // one that only completes it.
        if (!root.coordinator || root.coordinator.activeTarget !== route)
            root.requestedFromLauncher = root.launcherRouteOnScreen()
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
            // flip carries a route only while a control-center open is still
            // being handed off.
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
            // replays `requestedRoute`, so a control-center intent that survived
            // the close would turn every later open into a control center.
            // Default opens go back to the launcher.
            root.requestedRoute = root.defaultRoute
            // ...and the entry context with it: "came from the launcher" describes
            // one open, and a stale true would give the next open's control center
            // a back press that returns to a launcher the user never left.
            root.requestedFromLauncher = false
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
        // contract, so a sibling route renders its own header without the host
        // knowing anything about it.
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
        sidebarEntries: {
            var currentPage = root.activePage()
            return currentPage && currentPage.sidebarEntries !== undefined
                    ? currentPage.sidebarEntries : []
        }
        activeSidebarId: {
            var currentPage = root.activePage()
            if (!currentPage)
                return ""
            if (currentPage.activeSidebarId !== undefined)
                return String(currentPage.activeSidebarId)
            return currentPage.activeMode !== undefined ? String(currentPage.activeMode) : ""
        }
        palette: root.launcherPalette
        contentComponent: launcherPageComponent
        routeComponents: root.routeComponents

        onSidebarSelected: id => {
            // Contract first, launcher spelling second: the sidebar rail is
            // shared chrome, so the mounted page decides what an id means.
            var currentPage = root.activePage()
            if (!currentPage)
                return
            if (typeof currentPage.handleSidebarSelected === "function")
                currentPage.handleSidebarSelected(id)
            else if (typeof currentPage.handleModeSelected === "function")
                currentPage.handleModeSelected(id)
        }
    }

    // Page components for every sibling route this surface serves. Registering a
    // route is the entire wiring: the host selects by route name and keeps one
    // retained Loader across all of them.
    readonly property var routeComponents: ({
        "launcher": launcherPageComponent,
        "control-center": controlCenterPageComponent
    })

    Component {
        id: launcherPageComponent
        LauncherPage {
            session: root.session
            prewarmSlots: root.startupPrewarmAllowed === true
            thumbnailsActive: waveHost.phase === "open"
            onExitFlingRequested: spec => root.spawnExitCard(spec)
            // The rail's footer action. The page owns what the id MEANS; the
            // surface owns what it DOES, because only this surface can switch
            // its own route.
            onControlCenterRequested: root.requestControlCenterFromLauncher()
        }
    }

    Component {
        id: controlCenterPageComponent
        // The route page receives the injected singletons unchanged. The page
        // forwards the same objects to its same-surface sub-pages, so the
        // overview and a detail page can never describe two different services.
        ControlCenter {
            networkService: root.networkService
            bluetoothService: root.bluetoothService
            volumeService: root.volumeService
            mediaService: root.mediaService
            batteryService: root.batteryService
            notificationService: root.notificationService
            weatherService: root.weatherService
            // Entry context, from the latch this surface keeps. The page is
            // retained across opens, so this is a live binding rather than a
            // one-time assignment - which is what lets one page instance answer
            // differently for a bar-entry open and a launcher-entry open.
            enteredFromLauncher: root.requestedFromLauncher
            // The one request the route cannot answer itself. It re-enters the
            // same funnel as every other open of this surface, so the launcher is
            // reached through the coordinator exactly as an entry reaches it -
            // one dispatch path, one owner, one host. The opener rides along
            // unchanged, because this is the same open continuing.
            onOverviewBackRequested: root.returnToDefaultRoute()
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
