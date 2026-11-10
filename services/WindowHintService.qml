pragma Singleton

import Quickshell
import QtQuick
import "./" as Services

// Derives a live snapshot for the workspace/window hint OSD popup.
Singleton {
    id: root

    property bool hintHeld: false
    property var activeHint: _emptyHint()
    property var centerSurfaceWidths: ({})
    // hintVisible driven directly by hintHeld so activeHint data is never cleared during exit.
    readonly property bool hintVisible: root.hintHeld

    // Pull progress for dockzone background deformation (0=idle, 1=fully pulled).
    property real pullProgress: 0.0
    Behavior on pullProgress {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
    onHintHeldChanged: root.pullProgress = root.hintHeld ? 1.0 : 0.0

    function setCenterSurfaceWidth(screenName, width) {
        var nextWidths = Object.assign({}, centerSurfaceWidths)

        if (screenName && width > 0)
            nextWidths[screenName] = width
        else if (screenName)
            delete nextWidths[screenName]

        centerSurfaceWidths = nextWidths
    }

    function centerSurfaceWidthFor(screenName) {
        if (!screenName)
            return 0

        return centerSurfaceWidths[screenName] || 0
    }

    property int _revision: 0
    property int _lastActiveWorkspacePosition: -1
    property int _workspaceTransitionRevision: 0

    Timer {
        id: _hintRefreshCoalesceTimer

        interval: 40
        repeat: false
        onTriggered: root._refreshHint()
    }

    function setHintHeld(active) {
        const nextHeld = !!active
        if (root.hintHeld === nextHeld) {
            if (nextHeld)
                root._refreshHint()
            return
        }

        root.hintHeld = nextHeld

        if (root.hintHeld) {
            _hintRefreshCoalesceTimer.stop()
            root._refreshHint()
            return
        }

        // Release: stop refresh timer. Do NOT clear activeHint —
        // the UI exit animation still needs the data.
        _hintRefreshCoalesceTimer.stop()
    }

    function _scheduleHintRefresh(immediate) {
        if (!root.hintHeld)
            return

        if (immediate) {
            _hintRefreshCoalesceTimer.stop()
            root._refreshHint()
            return
        }

        _hintRefreshCoalesceTimer.restart()
    }

    function _refreshHint() {
        if (!root.hintHeld)
            return

        const nextHint = root._buildHint(true)
        // Cold-start guard: only reject the snapshot when no active workspace
        // exists yet. An active workspace with zero windows is a valid empty
        // workspace and must be committed so its capsule can enter.
        if (!nextHint.workspaceId) {
            Services.NiriService.reloadWindows()
            _hintRefreshCoalesceTimer.restart()
            if (root.activeHint && root.activeHint.workspaceId)
                return
        }
        root.activeHint = nextHint
    }

    function _emptyWindow() {
        return {
            windowId: "",
            title: "",
            appId: "",
            icon: "",
            isFocused: false
        }
    }

    function _emptyWorkspaceSummary() {
        return {
            workspaceId: "",
            workspaceIndex: -1,
            icons: []
        }
    }

    function _emptyHint() {
        return {
            visible: false,
            revision: root._revision,
            workspaceId: "",
            workspaceIndex: -1,
            activeWorkspacePosition: -1,
            previousActiveWorkspacePosition: -1,
            workspaceTransitionRevision: 0,
            currentWindowTitle: "",
            currentWindowAppId: "",
            currentWindowIcon: "",
            currentIndex: -1,
            windows: [],
            // The workspaces either side of the active one, so the view can lay
            // out a previous / active / next column without reaching into
            // NiriService itself. Empty at either end of the list, which is the
            // honest answer: there is no workspace there.
            previousWindows: [],
            nextWindows: [],
            workspaces: [],
            previousWindow: root._emptyWindow(),
            nextWindow: root._emptyWindow(),
            // The title rail's second half: which niri bind the key being held
            // resolves to. On the snapshot rather than read by the popup body,
            // because the body that paints them is the body the host measures -
            // a second reader there would be a second answer to the same
            // question.
            bindLabel: "",
            bindSequence: "",
            bindToken: 0,
            bindIsNavigational: false
        }
    }

    function iconAliasCandidates(appId) {
        return root._iconAliasCandidates(appId)
    }

    function iconPathForApp(appId) {
        return root._iconPathForApp(appId)
    }

    function _iconAliasCandidates(appId) {
        const raw = String(appId || "")
        if (!raw)
            return []
        const lower = raw.toLowerCase()
        const aliases = {
            "jlceda-pro": ["lceda-pro", "easyeda", "easyeda-pro"],
            "lceda-pro": ["jlceda-pro", "easyeda", "easyeda-pro"],
            "linuxqq": ["qq"],
            "qq": ["linuxqq"]
        }
        const all = []
        const seen = {}
        function push(v) {
            const s = String(v || "")
            if (!s || seen[s])
                return
            seen[s] = true
            all.push(s)
        }
        push(raw)
        push(lower)
        const a1 = aliases[raw] || []
        const a2 = aliases[lower] || []
        for (let i = 0; i < a1.length; i++) push(a1[i])
        for (let i = 0; i < a2.length; i++) push(a2[i])
        // Prefer aliases/lowercase over a mismatched raw app id when falling
        // back to icon names (e.g. jlceda-pro -> lceda-pro, QQ -> qq).
        const preferred = []
        const preferredSeen = {}
        function pushPreferred(v) {
            const s = String(v || "")
            if (!s || preferredSeen[s])
                return
            preferredSeen[s] = true
            preferred.push(s)
        }
        if (lower !== raw)
            pushPreferred(lower)
        const aliasList = (aliases[raw] || []).concat(aliases[lower] || [])
        for (let j = 0; j < aliasList.length; j++)
            pushPreferred(aliasList[j])
        pushPreferred(raw)
        if (lower === raw)
            pushPreferred(lower)
        return { all: all, preferred: preferred }
    }

    function _iconPathForApp(appId) {
        const fallback = Quickshell.iconPath("application-x-executable")
        const groups = root._iconAliasCandidates(appId)
        const all = groups.all || []
        const preferred = groups.preferred || []
        if (all.length === 0)
            return fallback

        const entries = Quickshell.desktopEntries
        for (let i = 0; i < all.length; i++) {
            const id = all[i]
            const entry = entries ? entries.byId(id) : null
            if (entry && entry.icon)
                return Quickshell.iconPath(String(entry.icon), "application-x-executable")
        }
        // iconPath() returns an image://icon URL even when missing; using
        // preferred order lets known aliases (lceda-pro/qq) win over raw ids.
        return Quickshell.iconPath(preferred[0] || all[0], "application-x-executable")
    }

    function _activeWorkspace() {
        for (let index = 0; index < Services.NiriService.workspaces.count; index++) {
            const workspace = Services.NiriService.workspaces.get(index)
            if (workspace.isActive)
                return workspace
        }
        return null
    }

    function _activeWorkspacePosition() {
        for (let index = 0; index < Services.NiriService.workspaces.count; index++) {
            if (Services.NiriService.workspaces.get(index).isActive)
                return index
        }
        return -1
    }

    function _workspaceWindows(workspaceId) {
        const items = []

        for (let index = 0; index < Services.NiriService.windows.count; index++) {
            const window = Services.NiriService.windows.get(index)
            if (window.workspaceId !== workspaceId)
                continue

            items.push({
                windowId: window.winId,
                title: window.title || window.appId || "Window",
                appId: window.appId || "",
                icon: root._iconPathForApp(window.appId || ""),
                isFocused: !!window.isFocused,
                colIdx: window.colIdx,
                rowIdx: window.rowIdx
            })
        }

        items.sort((left, right) => {
            if (left.colIdx !== right.colIdx)
                return left.colIdx - right.colIdx
            if (left.rowIdx !== right.rowIdx)
                return left.rowIdx - right.rowIdx
            return left.windowId.localeCompare(right.windowId)
        })

        // `colIdx` / `rowIdx` are carried through, and they are the whole reason a
        // REORDER can be told apart from a row that was replaced. The list is already
        // sorted by them, so their order in the array says the same thing - but a
        // reorder is the same array of identities in a different order, and telling that
        // apart from "one left and another arrived in its place" needs the position each
        // window HOLDS, not just where it sits in the projection.
        return items.map(item => ({
            windowId: item.windowId,
            title: item.title,
            appId: item.appId,
            icon: item.icon,
            isFocused: item.isFocused,
            colIdx: item.colIdx,
            rowIdx: item.rowIdx
        }))
    }

    function _workspaceIcons(workspaceId) {
        const icons = []
        const windows = root._workspaceWindows(workspaceId)

        for (let index = 0; index < windows.length; index++) {
            icons.push({
                windowId: windows[index].windowId,
                icon: windows[index].icon,
                isFocused: windows[index].isFocused
            })
        }

        return icons
    }

    function _currentIndex(windows) {
        for (let index = 0; index < windows.length; index++) {
            if (windows[index].isFocused)
                return index
        }

        if (windows.length > 0)
            return 0

        return -1
    }

    function _windowAt(windows, index) {
        if (index < 0 || index >= windows.length)
            return root._emptyWindow()

        return {
            windowId: windows[index].windowId,
            title: windows[index].title,
            appId: windows[index].appId,
            icon: windows[index].icon,
            isFocused: windows[index].isFocused
        }
    }

    function _workspaceSummaryAt(position) {
        if (position < 0 || position >= Services.NiriService.workspaces.count)
            return root._emptyWorkspaceSummary()

        const workspace = Services.NiriService.workspaces.get(position)
        return {
            workspaceId: workspace.wsId,
            workspaceIndex: workspace.idx,
            isActive: !!workspace.isActive,
            icons: root._workspaceIcons(workspace.wsId)
        }
    }

    function _workspaceSummaries() {
        const items = []
        for (let index = 0; index < Services.NiriService.workspaces.count; index++) {
            items.push(root._workspaceSummaryAt(index))
        }
        return items
    }

    function _buildHint(visible) {
        const workspace = root._activeWorkspace()
        if (!workspace)
            return root._emptyHint()

        const windows = root._workspaceWindows(workspace.wsId)
        const currentIndex = root._currentIndex(windows)
        const currentWindow = root._windowAt(windows, currentIndex)
        const activePosition = root._activeWorkspacePosition()
        const prevPosition = root._lastActiveWorkspacePosition
        const nextRevision = root._revision + 1

        if (activePosition !== prevPosition)
            root._workspaceTransitionRevision += 1

        root._lastActiveWorkspacePosition = activePosition
        root._revision = nextRevision

        // The neighbours of the active workspace, by position. Each is filtered
        // from the same window list the active column uses, so all three columns
        // describe the same instant. Out of range yields an empty list, which the
        // view renders as a blank column rather than a neighbour.
        const previousSummary = root._workspaceSummaryAt(activePosition - 1)
        const nextSummary = root._workspaceSummaryAt(activePosition + 1)

        return {
            visible: !!visible,
            revision: nextRevision,
            workspaceId: workspace.wsId,
            workspaceIndex: workspace.idx,
            activeWorkspacePosition: activePosition,
            previousActiveWorkspacePosition: prevPosition,
            workspaceTransitionRevision: root._workspaceTransitionRevision,
            currentWindowTitle: currentWindow.title || workspace.name || ("Workspace " + workspace.idx),
            currentWindowAppId: currentWindow.appId,
            currentWindowIcon: currentWindow.icon,
            currentIndex: currentIndex,
            windows: windows,
            previousWindows: previousSummary.workspaceId
                ? root._workspaceWindows(previousSummary.workspaceId) : [],
            nextWindows: nextSummary.workspaceId
                ? root._workspaceWindows(nextSummary.workspaceId) : [],
            workspaces: root._workspaceSummaries(),
            previousWindow: root._windowAt(windows, currentIndex - 1),
            nextWindow: root._windowAt(windows, currentIndex + 1),
            bindLabel: root._liveBindLabel(),
            // How many shortcuts have been fired since the shell started. The rail
            // announces on THIS changing, so a repeat press of one bind still gets
            // an answer while the overview's title gaining its workspace number
            // does not - see `NiriKeybindService.triggerToken`.
            bindToken: Services.NiriKeybindService.triggerToken,
            // Whether the answer names a WORKSPACE action, which is what decides
            // if the title carries the workspace number too.
            bindIsNavigational: Services.NiriKeybindService.liveBindIsNavigational,
            // `holdSequence`, not `liveSequence`: it falls back to the mod key's
            // own name while no bound key has been pressed, so the overview reads
            // "Overview / Super" instead of leaving the second line blank.
            bindSequence: Services.NiriKeybindService.holdSequence
        }
    }

    // The action the held shortcut runs, as one line. Empty while no bound key
    // has been pressed - the rail then says what the panel is instead.
    function _liveBindLabel() {
        const service = Services.NiriKeybindService
        if (!service || service.liveBind === null)
            return ""
        return String(service.bindLabel || "")
    }

    Connections {
        target: Services.NiriService

        function onWindowsUpdated() {
            if (root.hintHeld)
                root._scheduleHintRefresh(false)
        }

        function onWorkspaceActivated() {
            if (root.hintHeld)
                root._scheduleHintRefresh(true)
        }

        function onWorkspacesUpdated() {
            if (root.hintHeld)
                root._scheduleHintRefresh(false)
        }
    }

    Connections {
        target: Services.WindowHintTriggerService

        function onHoldChanged(active) {
            root.setHintHeld(active)
        }
    }

    // A key pressed WHILE the hint is held is a change to what the rail says, not
    // a reason to reopen the panel: the snapshot is republished in place, so the
    // host treats it as the same popup and the title transitions instead of the
    // whole surface being replaced.
    Connections {
        target: Services.NiriKeybindService

        function onBindResolved() {
            if (root.hintHeld)
                root._scheduleHintRefresh(true)
        }
    }
}
