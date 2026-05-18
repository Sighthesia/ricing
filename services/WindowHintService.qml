pragma Singleton

import Quickshell
import QtQuick
import "./" as Services

// Derives a live snapshot for the workspace/window hint OSD popup.
Singleton {
    id: root

    property bool hintHeld: false
    property var activeHint: _emptyHint()
    // hintVisible driven directly by hintHeld so activeHint data is never cleared during exit.
    readonly property bool hintVisible: root.hintHeld

    property int _revision: 0

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
            currentWindowTitle: "",
            currentWindowAppId: "",
            currentWindowIcon: "",
            currentIndex: -1,
            windows: [],
            workspaces: [],
            previousWindow: root._emptyWindow(),
            nextWindow: root._emptyWindow()
        }
    }

    function _iconPathForApp(appId) {
        if (!appId)
            return Quickshell.iconPath("application-x-executable")

        const entry = Quickshell.desktopEntries
            ? Quickshell.desktopEntries.byId(appId)
            : null
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable")

        return Quickshell.iconPath(appId, "application-x-executable")
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

        return items.map(item => ({
            windowId: item.windowId,
            title: item.title,
            appId: item.appId,
            icon: item.icon,
            isFocused: item.isFocused
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
        const nextRevision = root._revision + 1

        root._revision = nextRevision

        return {
            visible: !!visible,
            revision: nextRevision,
            workspaceId: workspace.wsId,
            workspaceIndex: workspace.idx,
            activeWorkspacePosition: activePosition,
            currentWindowTitle: currentWindow.title || workspace.name || ("Workspace " + workspace.idx),
            currentWindowAppId: currentWindow.appId,
            currentWindowIcon: currentWindow.icon,
            currentIndex: currentIndex,
            windows: windows,
            workspaces: root._workspaceSummaries(),
            previousWindow: root._windowAt(windows, currentIndex - 1),
            nextWindow: root._windowAt(windows, currentIndex + 1)
        }
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
}
