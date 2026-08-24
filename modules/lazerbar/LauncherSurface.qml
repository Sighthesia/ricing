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

    // Launcher palette anchored on the osu pink family; independent of the
    // retired Wiki/News/Beatmap palettes.
    readonly property var launcherPalette: ({
        kind: "pink",
        body: "#33202B",
        header: "#B23A62",
        sidebar: "#3A2531",
        light4: "#F492B8",
        light3: "#E56E97",
        dark4: "#AC3F63",
        dark3: "#75293F",
        text: "#FFF2F6",
        muted: "#D9BCC9",
        accent: LazerTheme.osuPink
    })

    LauncherSession { id: embeddedSession }

    function page() { return waveHost.contentItem }

    function snapshot() {
        return {
            sessionVisible: !!root.session && root.session.visible,
            hostPhase: waveHost.phase,
            activeTarget: root.coordinator ? root.coordinator.activeTarget : "",
            transitioning: root.coordinator ? root.coordinator.transitioning : false,
            pendingTarget: root.coordinator ? root.coordinator.pendingTarget : ""
        }
    }

    // Land typing in the live search session of the current page instance.
    function focusSearch() {
        var currentPage = page()
        if (currentPage)
            currentPage.focusSearch()
    }

    // Every launcher activation funnels here: bar entry, IPC open, or a
    // session-visible flip. The opener Item is recorded so focus returns to
    // it once the surface closes.
    function requestOpen(opener) {
        var action = Logic.openAction(snapshot())
        if (action === "open-session") {
            pendingOpener = opener || null
            if (root.session)
                root.session.open()
            return
        }
        if (action === "refocus-search") {
            focusSearch()
            return
        }
        if (action === "reopen-host") {
            reopenHost(opener)
            return
        }
        if (root.coordinator)
            root.coordinator.request("launcher", opener, true, true)
    }

    // Recall the same live instance while it is mid-close (or queued behind
    // another owner's close): stop the close, drop any superseded hand-off,
    // record the newest opener for restoration, and reopen in place so the
    // latest open request is never swallowed.
    function reopenHost(opener) {
        pendingOpener = opener || null
        if (root.coordinator) {
            if (root.coordinator.transitioning)
                root.coordinator.cancelPending()
            root.coordinator.opener = opener || null
        }
        waveHost.openRoute("launcher", null)
    }

    // Mirror session visibility onto the surface; also runs for programmatic
    // open/close from the keyboard IPC path.
    function syncVisibility() {
        if (!root.session)
            return
        if (root.session.visible) {
            requestOpen(pendingOpener)
        } else {
            var action = Logic.closeAction(snapshot())
            console.log("[DBG-sync] closeAction=" + action + " phase=" + waveHost.phase)
            if (action === "request-coordinated-close" && root.coordinator)
                root.coordinator.request("launcher")
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
            // The surface grabbed focus on dispatch; land search only when
            // the launcher genuinely owns the coordinator now, which covers
            // both direct opens and opens queued behind another owner's close.
            if (root.coordinator && root.coordinator.activeTarget === "launcher")
                root.focusSearch()
        }
        function onClosed() {
            if (root.coordinator)
                root.coordinator.ownerClosed("wave")
            if (root.session && root.session.visible)
                root.session.close()
        }
    }

    // Probe/test access to the hosted page.
    property alias waveHostItem: waveHost

    WaveSurfaceHost {
        id: waveHost
        anchors.fill: parent
        title: root.page() ? root.page().title : "Launcher"
        description: root.page() ? root.page().description : ""
        sidebarEntries: root.page() ? root.page().sidebarEntries : []
        activeSidebarId: root.page() ? root.page().activeMode : "apps"
        palette: root.launcherPalette
        contentComponent: launcherPageComponent

        onSidebarSelected: id => {
            var currentPage = root.page()
            if (currentPage)
                currentPage.handleModeSelected(id)
        }
    }

    Component {
        id: launcherPageComponent
        LauncherPage {
            session: root.session
            onExitFlingRequested: spec => root.spawnExitCard(spec)
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
