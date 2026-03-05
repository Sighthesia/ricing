pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property ListModel workspaces: ListModel {}
    property ListModel windows: ListModel {}

    signal windowsUpdated()
    signal workspaceActivated()

    function updateWorkspaces(workspacesEvent) {
        const list = workspacesEvent.workspaces;
        list.sort((a, b) => a.idx - b.idx);

        workspaces.clear();
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            workspaces.append({
                wsId: String(ws.id),
                idx: ws.idx,
                isActive: ws.is_active,
                name: ws.name || "",
                output: ws.output || ""
            });
        }
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
            const pos = win.layout && win.layout.pos_in_scrolling_layout;
            windows.append({
                winId: String(win.id),
                title: win.title || "Unknown",
                appId: win.app_id || "unknown",
                workspaceId: String(win.workspace_id) || "",
                isFocused: win.is_focused || false,
                colIdx: pos ? pos[0] : 0,
                rowIdx: pos ? pos[1] : 0
            });
        }
        windowsUpdated();
    }

    function reloadWindows() {
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
