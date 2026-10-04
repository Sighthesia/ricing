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
            if (root.session && root.session.visible)
                root.session.close()
        }
    }

    // Probe/test access to the hosted page.
    property alias waveHostItem: waveHost

    // Cold-path prewarm: the first open pays LauncherPage compilation plus
    // delegate/icon/font warmup all at once and visibly stalls. Arm a
    // hidden, disabled copy at idle shortly after startup, let the engine
    // caches fill, then release it; the real open path is untouched.
    Loader {
        id: prewarmLoader
        active: false
        visible: false
        enabled: false
        opacity: 0
        x: -10000
        y: -10000
        width: 480
        height: 640

        sourceComponent: LauncherPage {
            session: root.session
            enabled: false
        }
    }

    // The pool fills asynchronously (desktop-entry scan, 5s clipboard poll),
    // usually well after arm time — releasing before the first data landed
    // would tear the hidden page down with zero rows built and the first
    // open would pay the delegate cold path anyway. Start the release
    // countdown only once the pool can actually materialize rows.
    readonly property bool prewarmPoolReady: !!root.session
            && root.session.displayPool != null && root.session.displayPool.length > 0

    Timer {
        id: prewarmArmTimer
        interval: 0
        repeat: false
        // The launcher page is a cold-path prewarm, not startup chrome. Hold it
        // until the shell's quiet-ready window so its delegates cannot compete
        // with wallpaper reveal, lock wave, or first bar staging.
        running: !!root.session && root.startupPrewarmAllowed === true
        onTriggered: prewarmLoader.active = true
    }

    // Production owners set this after quiet-ready; standalone tests keep the
    // historical default so the component remains self-contained.
    property bool startupPrewarmAllowed: true

    Timer {
        id: prewarmReleaseTimer
        interval: 4000
        repeat: false
        running: prewarmLoader.active && root.prewarmPoolReady
        onTriggered: prewarmLoader.active = false
    }

    // Hard cap: a session that never yields data has nothing to warm, so
    // the hidden page must not outlive the startup window indefinitely.
    Timer {
        id: prewarmCapTimer
        interval: 30000
        repeat: false
        running: prewarmLoader.active && !root.prewarmPoolReady
        onTriggered: prewarmLoader.active = false
    }

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
            onExitFlingRequested: spec => root.spawnExitCard(spec)
        }
    }

    Component {
        id: controlCenterPageComponent
        ControlCenter {}
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
