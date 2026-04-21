pragma Singleton

import Quickshell
import QtQuick
import qs.services

// Derives a live snapshot for the center-lane window hint preview.
Singleton {
    id: root

    property bool hintHeld: false
    property var activeHint: _emptyHint()
    property var workspaceSummaries: []
    readonly property bool _overlayBlocked:
        IslandOverlayService.mode !== "none"
        && IslandOverlayService.state !== "closed"

    readonly property bool hintVisible: activeHint.visible === true && !root._overlayBlocked
    readonly property bool triggerBridgeAvailable: WindowHintTriggerService.available
    readonly property bool triggerBridgeRunning: WindowHintTriggerService.running

    property int _revision: 0

    property var _lastVisibleHint: _emptyHint()

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

        _hintRefreshCoalesceTimer.stop()
        root.activeHint = root._emptyHint()
        root._lastVisibleHint = root._emptyHint()
        SuperIslandService.hideWindowHint()
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

    function _semanticWindow(windowData) {
        return {
            windowId: windowData ? (windowData.windowId || "") : "",
            title: windowData ? (windowData.title || "") : "",
            appId: windowData ? (windowData.appId || "") : "",
            icon: windowData ? (windowData.icon || "") : "",
            isFocused: windowData ? !!windowData.isFocused : false,
            columnIndex: windowData && windowData.columnIndex !== undefined ? windowData.columnIndex : -1
        }
    }

    function _semanticWorkspaceSummary(summary) {
        return {
            workspaceId: summary ? (summary.workspaceId || "") : "",
            workspaceIndex: summary && summary.workspaceIndex !== undefined ? summary.workspaceIndex : -1,
            icons: summary && summary.icons
                ? summary.icons.map(iconData => ({
                    windowId: iconData.windowId || "",
                    icon: iconData.icon || "",
                    isFocused: !!iconData.isFocused
                }))
                : []
        }
    }

    function _semanticHintKey(hint) {
        if (!hint)
            return ""

        return JSON.stringify({
            presentation: hint.presentation || "",
            visible: hint.visible === true,
            workspaceId: hint.workspaceId || "",
            workspaceIndex: hint.workspaceIndex !== undefined ? hint.workspaceIndex : -1,
            activeWorkspacePosition: hint.activeWorkspacePosition !== undefined ? hint.activeWorkspacePosition : -1,
            currentWindowId: hint.currentWindowId || "",
            currentWindowTitle: hint.currentWindowTitle || "",
            currentWindowIcon: hint.currentWindowIcon || "",
            currentIndex: hint.currentIndex !== undefined ? hint.currentIndex : -1,
            windows: hint.windows ? hint.windows.map(windowData => root._semanticWindow(windowData)) : [],
            workspaces: hint.workspaces
                ? hint.workspaces.map(summary => root._semanticWorkspaceSummary(summary))
                : [],
            previousWindow: root._semanticWindow(hint.previousWindow),
            nextWindow: root._semanticWindow(hint.nextWindow),
            previousWorkspace: root._semanticWorkspaceSummary(hint.previousWorkspace),
            nextWorkspace: root._semanticWorkspaceSummary(hint.nextWorkspace)
        })
    }

    function _publishHint(nextHint) {
        if (!nextHint || !nextHint.visible)
            return

        const repeatedHint = root._semanticHintKey(nextHint) === root._semanticHintKey(root._lastVisibleHint)

        root._lastVisibleHint = nextHint
        root.activeHint = nextHint

        if (root._overlayBlocked || repeatedHint)
            return

        SuperIslandService.showWindowHint(nextHint)
    }

    function _refreshHint() {
        const nextHint = root._buildHint(root.hintHeld)

        if (!root.hintHeld)
            return

        if (!nextHint.visible) {
            if (root._lastVisibleHint.visible) {
                root.activeHint = root._lastVisibleHint
                SuperIslandService.showWindowHint(root._lastVisibleHint)
            }
            return
        }

        root._publishHint(nextHint)
    }

    function _refreshWorkspaceSummaries() {
        root.workspaceSummaries = root._workspaceSummaries(true)
    }

    function workspaceIcons(workspaceId) {
        const targetWorkspaceId = String(workspaceId || "")

        for (let index = 0; index < root.workspaceSummaries.length; index++) {
            const summary = root.workspaceSummaries[index]
            if ((summary.workspaceId || "") === targetWorkspaceId)
                return summary.icons || []
        }

        return []
    }

    function _workspaceSummaries(includeTrailingPlaceholder) {
        const items = []
        let lastNonEmptyIndex = -1

        for (let index = 0; index < NiriService.workspaces.count; index++) {
            const summary = root._workspaceSummaryAt(index)
            items.push(summary)

            if ((summary.icons || []).length > 0)
                lastNonEmptyIndex = index
        }

        if (items.length === 0)
            return items

        if (includeTrailingPlaceholder && lastNonEmptyIndex === items.length - 1) {
            items.push({
                workspaceId: "",
                workspaceIndex: (items[items.length - 1].workspaceIndex || 0) + 1,
                isActive: false,
                icons: []
            })
        }

        return items
    }

    function _emptyWindow() {
        return {
            windowId: "",
            title: "",
            appId: "",
            icon: "",
            isFocused: false,
            columnIndex: -1
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
            presentation: "bar-expanded",
            revision: root._revision,
            workspaceId: "",
            workspaceIndex: -1,
            activeWorkspacePosition: -1,
            currentWindowId: "",
            currentWindowTitle: "",
            currentWindowIcon: "",
            currentIndex: -1,
            windows: [],
            workspaces: [],
            previousWindow: root._emptyWindow(),
            nextWindow: root._emptyWindow(),
            previousWorkspace: root._emptyWorkspaceSummary(),
            nextWorkspace: root._emptyWorkspaceSummary()
        }
    }

    function _activeWorkspace() {
        for (let index = 0; index < NiriService.workspaces.count; index++) {
            const workspace = NiriService.workspaces.get(index)
            if (workspace.isActive)
                return workspace
        }

        return null
    }

    function _activeWorkspacePosition() {
        for (let index = 0; index < NiriService.workspaces.count; index++) {
            if (NiriService.workspaces.get(index).isActive)
                return index
        }

        return -1
    }

    function _iconPathForApp(appId) {
        if (!appId)
            return Quickshell.iconPath("application-x-executable")

        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable")

        return Quickshell.iconPath("application-x-executable")
    }

    function _workspaceWindows(workspaceId) {
        const items = []

        for (let index = 0; index < NiriService.windows.count; index++) {
            const window = NiriService.windows.get(index)
            if (window.workspaceId !== workspaceId)
                continue

            items.push({
                windowId: window.winId,
                title: window.title || window.appId || "Window",
                appId: window.appId || "",
                icon: root._iconPathForApp(window.appId || ""),
                isFocused: !!window.isFocused,
                columnIndex: window.colIdx,
                rowIndex: window.rowIdx
            })
        }

        items.sort((left, right) => {
            if (left.columnIndex !== right.columnIndex)
                return left.columnIndex - right.columnIndex
            if (left.rowIndex !== right.rowIndex)
                return left.rowIndex - right.rowIndex
            return left.windowId.localeCompare(right.windowId)
        })

        return items.map(item => ({
            windowId: item.windowId,
            title: item.title,
            appId: item.appId,
            icon: item.icon,
            isFocused: item.isFocused,
            columnIndex: item.columnIndex
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
            isFocused: windows[index].isFocused,
            columnIndex: windows[index].columnIndex
        }
    }

    function _workspaceSummaryAt(position) {
        if (position < 0 || position >= NiriService.workspaces.count)
            return root._emptyWorkspaceSummary()

        const workspace = NiriService.workspaces.get(position)
        return {
            workspaceId: workspace.wsId,
            workspaceIndex: workspace.idx,
            isActive: !!workspace.isActive,
            icons: root._workspaceIcons(workspace.wsId)
        }
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
            presentation: "bar-expanded",
            revision: nextRevision,
            workspaceId: workspace.wsId,
            workspaceIndex: workspace.idx,
            activeWorkspacePosition: activePosition,
            currentWindowId: currentWindow.windowId,
            currentWindowTitle: currentWindow.title || workspace.name || ("Workspace " + workspace.idx),
            currentWindowIcon: currentWindow.icon,
            currentIndex: currentIndex,
            windows: windows,
            workspaces: root._workspaceSummaries(false),
            previousWindow: root._windowAt(windows, currentIndex - 1),
            nextWindow: root._windowAt(windows, currentIndex + 1),
            previousWorkspace: root._workspaceSummaryAt(activePosition - 1),
            nextWorkspace: root._workspaceSummaryAt(activePosition + 1)
        }
    }

    Connections {
        target: NiriService

        function onWindowsUpdated() {
            root._refreshWorkspaceSummaries()
            if (root.hintHeld)
                root._scheduleHintRefresh(false)
        }

        function onWorkspaceActivated() {
            root._refreshWorkspaceSummaries()
            if (root.hintHeld)
                root._scheduleHintRefresh(false)
        }

        function onWorkspacesUpdated() {
            root._refreshWorkspaceSummaries()
            if (root.hintHeld)
                root._scheduleHintRefresh(false)
        }
    }

    Component.onCompleted: root._refreshWorkspaceSummaries()

    Connections {
        target: WindowHintTriggerService

        function onHoldChanged(active) {
            root.setHintHeld(active)
        }
    }

    Connections {
        target: IslandOverlayService

        function _resumeHintIfNeeded() {
            if (!root.hintHeld || root._overlayBlocked)
                return

            root._scheduleHintRefresh(true)
        }

        function onModeChanged() {
            _resumeHintIfNeeded()
        }

        function onStateChanged() {
            _resumeHintIfNeeded()
        }
    }
}
