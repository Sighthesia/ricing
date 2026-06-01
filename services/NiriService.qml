pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Niri window manager IPC: tracks workspaces and windows via event stream.
Singleton {
    id: root

    property ListModel workspaces: ListModel {}
    property ListModel windows: ListModel {}
    signal workspacesUpdated()
    signal workspaceActivated()
    signal windowsUpdated()

    readonly property string _homeDir: {
        const home = Quickshell.env("HOME")
        return home ? home : Quickshell.workingDirectory
    }
    readonly property string _configDir: root._homeDir + "/.config/niri"
    readonly property string _configFile: root._configDir + "/config.kdl"
    readonly property string _hotkeysIncludeFile: root._configDir + "/afloat-hotkeys.kdl"
    readonly property string _hotkeysIncludeLine: 'include "./afloat-hotkeys.kdl"'
    readonly property string _ipcHelperPath: Quickshell.shellDir + "/scripts/afloat-ipc"

    // Find focused window title
    readonly property string activeTitle: {
        for (let i = 0; i < windows.count; i++) {
            let win = windows.get(i)
            if (win.isFocused) return win.title
        }
        return ""
    }

    readonly property string activeAppId: {
        for (let i = 0; i < windows.count; i++) {
            let win = windows.get(i)
            if (win.isFocused) return win.appId
        }
        return ""
    }

    function _kdlString(value) {
        return '"' + String(value || "").replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'
    }

    function _managedHotkeysConfigText() {
        const helper = root._kdlString(root._ipcHelperPath)
        const entries = [
            {
                sequence: "Super+Shift+Space",
                title: "Launcher: afloat",
                target: "launcher",
                action: "toggle"
            },
            {
                sequence: "Super+Shift+V",
                title: "Clipboard: afloat",
                target: "launcher",
                action: "openClipboard"
            },
            {
                sequence: "Super+Shift+Slash",
                title: "Shortcuts: afloat",
                target: "launcher",
                action: "openShortcuts"
            },
            {
                sequence: "Super+Shift+D",
                title: "Settings: afloat",
                target: "settings",
                action: "toggle"
            }
        ]
        const lines = [
            "// Managed by afloat.",
            "binds {"
        ]

        for (let index = 0; index < entries.length; index++) {
            const entry = entries[index]
            lines.push(
                "    "
                + entry.sequence
                + " hotkey-overlay-title="
                + root._kdlString(entry.title)
                + " { spawn \"sh\" "
                + helper
                + " \""
                + entry.target
                + "\" \""
                + entry.action
                + "\"; }"
            )
        }

        lines.push("}")
        // Render afloat's overview-backdrop surface inside niri's overview backdrop
        // (below the scaled workspace tiles), not scaled into the tiles.
        lines.push("layer-rule {")
        lines.push('    match namespace="^afloat-overview-backdrop$"')
        lines.push("    place-within-backdrop true")
        lines.push("}")
        return lines.join("\n") + "\n"
    }

    function syncManagedHotkeys() {
        _hotkeysWriter.command = [
            "sh",
            "-c",
            "mkdir -p \"$1\"; if [ -f \"$2\" ] && ! grep -Fqx \"$4\" \"$2\"; then printf '\\n%s\\n' \"$4\" >> \"$2\"; fi; tmp=$(mktemp \"$3.XXXXXX\") || exit 1; printf '%s' \"$5\" > \"$tmp\" && mv \"$tmp\" \"$3\"",
            "sh",
            root._configDir,
            root._configFile,
            root._hotkeysIncludeFile,
            root._hotkeysIncludeLine,
            root._managedHotkeysConfigText()
        ]
        _hotkeysWriter.running = false
        _hotkeysWriter.running = true
    }

    function updateWindows(windowListArray) {
        if (!windowListArray) return
        windows.clear()
        for (let i = 0; i < windowListArray.length; i++) {
            let win = windowListArray[i]
            const rawPos = win.layout ? win.layout.pos_in_scrolling_layout : null
            const pos = (Array.isArray(rawPos) && rawPos.length >= 2) ? rawPos : null
            windows.append({
                winId: String(win.id),
                title: win.title || "",
                appId: win.app_id || "",
                isFocused: win.is_focused || false,
                workspaceId: win.workspace_id != null ? String(win.workspace_id) : "",
                colIdx: pos ? pos[0] : 9999,
                rowIdx: pos ? pos[1] : 9999
            })
        }
        windowsUpdated()
    }

    function updateWorkspaces(workspacesEvent) {
        const list = (workspacesEvent.workspaces || []).slice()
        list.sort((a, b) => a.idx - b.idx)

        const activeWorkspaceIds = ({})

        for (let targetIndex = 0; targetIndex < list.length; targetIndex++) {
            const ws = list[targetIndex]
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
                    isActive: ws.is_active || false,
                    name: ws.name || ""
                })
                continue
            }

            if (currentIndex !== targetIndex)
                workspaces.move(currentIndex, targetIndex, 1)

            const currentItem = workspaces.get(targetIndex)
            if (currentItem.idx !== ws.idx)
                workspaces.setProperty(targetIndex, "idx", ws.idx)
            if (currentItem.isActive !== (ws.is_active || false))
                workspaces.setProperty(targetIndex, "isActive", ws.is_active || false)
            if (currentItem.name !== (ws.name || ""))
                workspaces.setProperty(targetIndex, "name", ws.name || "")
        }

        for (let index = workspaces.count - 1; index >= 0; index--) {
            if (activeWorkspaceIds[workspaces.get(index).wsId])
                continue
            workspaces.remove(index, 1)
        }

        workspacesUpdated()
    }

    function activateWorkspace(event) {
        const activeId = String(event.id)
        for (let i = 0; i < workspaces.count; i++) {
            const item = workspaces.get(i)
            const isNowActive = (item.wsId === activeId)
            if (item.isActive !== isNowActive)
                workspaces.setProperty(i, "isActive", isNowActive)
        }
        workspaceActivated()
    }

    // Initial fetch
    property Process _fetcher: Process {
        id: fetcher
        running: true
        command: ["niri", "msg", "-j", "windows"]
        stdout: SplitParser {
            onRead: data => {
                try { root.updateWindows(JSON.parse(data.trim())) }
                catch (e) {}
            }
        }
    }

    // Initial workspace fetch
    property Process _workspaceFetcher: Process {
        id: workspaceFetcher
        running: true
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim())
                    root.updateWorkspaces({ workspaces: parsed })
                } catch (e) {}
            }
        }
    }

    function reloadWindows() { fetcher.running = true }

    // Event stream for live updates
    property Process _eventStream: Process {
        id: eventStream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let event = JSON.parse(data.trim())
                    if (event.WorkspacesChanged)
                        root.updateWorkspaces(event.WorkspacesChanged)
                    else if (event.WorkspaceActivated)
                        root.activateWorkspace(event.WorkspaceActivated)
                    else if (event.WindowOpenedOrChanged || event.WindowClosed || event.WindowFocusChanged)
                        root.reloadWindows()
                } catch (e) {}
            }
        }
    }

    function reloadConfig() {
        _configReloader.running = true
    }

    Component.onCompleted: root.syncManagedHotkeys()

    // Trigger niri to reload its config after binds.kdl is written.
    property Process _configReloader: Process {
        command: ["niri", "msg", "action", "load-config-file"]
        running: false
    }

    // Keep the generated niri include in sync with afloat's fixed shell hotkeys.
    property Process _hotkeysWriter: Process {
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("NiriService: failed to write managed hotkey include, exitCode =", exitCode)
                return
            }

            root.reloadConfig()
        }
    }
}
