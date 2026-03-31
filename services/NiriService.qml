pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property ListModel workspaces: ListModel {}
    property ListModel windows: ListModel {}
    property bool _windowsReloadQueued: false

    signal workspacesUpdated()
    signal windowsUpdated()
    signal workspaceActivated()

    function updateWorkspaces(workspacesEvent) {
        const list = (workspacesEvent.workspaces || []).slice();
        list.sort((a, b) => a.idx - b.idx);

        const activeWorkspaceIds = ({})

        for (let targetIndex = 0; targetIndex < list.length; targetIndex++) {
            const ws = list[targetIndex];
            const workspaceId = String(ws.id)
            activeWorkspaceIds[workspaceId] = true

            let currentIndex = -1
            for (let scanIndex = 0; scanIndex < workspaces.count; scanIndex++) {
                if (workspaces.get(scanIndex).wsId === workspaceId) {
                    currentIndex = scanIndex
                    break
                }
            }

            if (currentIndex < 0) {
                workspaces.insert(targetIndex, {
                    wsId: workspaceId,
                    idx: ws.idx,
                    isActive: ws.is_active,
                    name: ws.name || "",
                    output: ws.output || ""
                })
                continue
            }

            if (currentIndex !== targetIndex)
                workspaces.move(currentIndex, targetIndex, 1)

            const currentItem = workspaces.get(targetIndex)
            if (currentItem.idx !== ws.idx)
                workspaces.setProperty(targetIndex, "idx", ws.idx)
            if (currentItem.isActive !== ws.is_active)
                workspaces.setProperty(targetIndex, "isActive", ws.is_active)
            if (currentItem.name !== (ws.name || ""))
                workspaces.setProperty(targetIndex, "name", ws.name || "")
            if (currentItem.output !== (ws.output || ""))
                workspaces.setProperty(targetIndex, "output", ws.output || "")
        }

        for (let index = workspaces.count - 1; index >= 0; index--) {
            if (activeWorkspaceIds[workspaces.get(index).wsId])
                continue

            workspaces.remove(index, 1)
        }

        workspacesUpdated();
    }

    function activateWorkspace(event) {
        const activeId = String(event.id);
        for (let i = 0; i < workspaces.count; i++) {
            const item = workspaces.get(i);
            const isNowActive = (item.wsId === activeId);
            if (item.isActive !== isNowActive) {
                workspaces.setProperty(i, "isActive", isNowActive);
            }
        }
        workspaceActivated();
    }

    function updateWindows(windowList) {
        if (!windowList) return;
        windows.clear();
        for (let i = 0; i < windowList.length; i++) {
            const win = windowList[i];
            // Guard against non-array or short-array values from unexpected niri API changes.
            const rawPos = win.layout?.pos_in_scrolling_layout;
            const pos = (Array.isArray(rawPos) && rawPos.length >= 2) ? rawPos : null;
            windows.append({
                winId: String(win.id),
                title: win.title || "Unknown",
                appId: win.app_id || "unknown",
                // String(null) === "null" which is truthy, so || "" never fires — use explicit null check.
                workspaceId: win.workspace_id != null ? String(win.workspace_id) : "",
                isFocused: win.is_focused || false,
                // Floating windows (pos === null) have no tiled position; use a sentinel value
                // so they sort after all tiled windows rather than colliding with [0, 0].
                colIdx: pos ? pos[0] : 9999,
                rowIdx: pos ? pos[1] : 9999
            });
        }
        windowsUpdated();
    }

    function reloadWindows() {
        if (niriWindowsFetcher.running) {
            root._windowsReloadQueued = true;
            return;
        }

        niriWindowsFetcher.running = true;
    }

    // Initial window fetch
    Process {
        id: niriWindowsFetcher
        running: true
        command: ["niri", "msg", "-j", "windows"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.updateWindows(JSON.parse(data.trim()));
                } catch (e) {}
            }
        }
        onRunningChanged: {
            if (running || !root._windowsReloadQueued)
                return;

            root._windowsReloadQueued = false;
            running = true;
        }
    }

    // Event stream listener
    Process {
        id: niriEvents
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data.trim());
                    if (event.WorkspacesChanged)
                        root.updateWorkspaces(event.WorkspacesChanged);
                    else if (event.WorkspaceActivated)
                        root.activateWorkspace(event.WorkspaceActivated);
                    else if (event.WindowOpenedOrChanged || event.WindowClosed || event.WindowFocusChanged)
                        root.reloadWindows();
                } catch (e) {
                    console.log("NiriService event parse error:", e);
                }
            }
        }
    }
}
