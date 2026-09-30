pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services
import "./FullscreenDetect.js" as FullscreenDetect

// Niri window manager IPC: tracks workspaces and windows via event stream.
Singleton {
    id: root

    property ListModel workspaces: ListModel {}
    property ListModel windows: ListModel {}
    // ListModel role changes do not reliably invalidate bindings that scan
    // `get()` rows, so expose an explicit revision for derived focus state.
    property int _windowsRevision: 0
    // Logical output extents keyed by connector name, plus the fullscreen
    // verdict derived from them. Both are plain vars recomputed imperatively,
    // never bindings over `get()` rows, so a consumer can bind to them safely.
    property var outputSizes: ({})
    property var _fullscreenOutputs: ({})
    signal workspacesUpdated()
    signal workspaceActivated()
    signal windowsUpdated()

    // True when a fullscreen window covers this output. See FullscreenDetect.js
    // for why tile geometry is the only fullscreen signal niri exposes.
    function isOutputFullscreen(outputName) {
        const name = outputName == null ? "" : String(outputName)
        if (!name)
            return false
        const map = root._fullscreenOutputs || {}
        return map[name] === true
    }

    readonly property string _homeDir: {
        const home = Quickshell.env("HOME")
        return home ? home : Quickshell.workingDirectory
    }
    readonly property string _configDir: root._homeDir + "/.config/niri"
    readonly property string _configFile: root._configDir + "/config.kdl"
    readonly property string _hotkeysIncludeFile: root._configDir + "/afloat-hotkeys.kdl"
    readonly property string _hotkeysIncludeLine: 'include "./afloat-hotkeys.kdl"'
    readonly property string _blurConfigFile: root._configDir + "/blur.kdl"
    readonly property string _ipcHelperPath: Quickshell.shellDir + "/scripts/afloat-ipc"

    // Find focused window title
    readonly property string activeTitle: {
        const revision = root._windowsRevision
        for (let i = 0; i < windows.count; i++) {
            let win = windows.get(i)
            if (win.isFocused) return win.title
        }
        return ""
    }

    readonly property string activeAppId: {
        const revision = root._windowsRevision
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
                target: "island",
                action: "toggle"
            },
            {
                sequence: "Super+Shift+V",
                title: "Clipboard: afloat",
                target: "island",
                action: "openClipboard"
            },
            {
                sequence: "Super+Shift+Slash",
                title: "Shortcuts: afloat",
                target: "island",
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

    function _blurConfigText() {
        const s = Services.SettingsService.appearance
        if (!s.enableBlur)
            return ""
        return "// Generated by afloat. Edit via Settings > Appearance.\n"
            + "blur {\n"
            + "    passes " + s.blurPasses + "\n"
            + "    offset " + s.blurOffset + "\n"
            + "    noise " + s.blurNoise + "\n"
            + "    saturation " + s.blurSaturation + "\n"
            + "}\n"
    }

    function syncBlurConfig() {
        _blurWriter.command = [
            "sh", "-c",
            "mkdir -p \"$1\"; tmp=$(mktemp \"$2.XXXXXX\") || exit 1; printf '%s' \"$3\" > \"$tmp\" && mv \"$tmp\" \"$2\"",
            "sh",
            root._configDir,
            root._blurConfigFile,
            root._blurConfigText()
        ]
        _blurWriter.running = false
        _blurWriter.running = true
    }

    function updateWindows(windowListArray) {
        if (windowListArray && !Array.isArray(windowListArray)
                && windowListArray.WindowsChanged)
            windowListArray = windowListArray.WindowsChanged.windows
        if (!windowListArray) return
        windows.clear()
        for (let i = 0; i < windowListArray.length; i++) {
            let win = windowListArray[i]
            const rawPos = win.layout ? win.layout.pos_in_scrolling_layout : null
            const pos = (Array.isArray(rawPos) && rawPos.length >= 2) ? rawPos : null
            const rawTile = win.layout ? win.layout.tile_size : null
            const tile = (Array.isArray(rawTile) && rawTile.length >= 2) ? rawTile : null
            windows.append({
                winId: String(win.id),
                title: win.title || "",
                appId: win.app_id || "",
                isFocused: win.is_focused || false,
                workspaceId: win.workspace_id != null ? String(win.workspace_id) : "",
                colIdx: pos ? pos[0] : 9999,
                rowIdx: pos ? pos[1] : 9999,
                // Tile geometry drives fullscreen detection: niri reports no
                // is_fullscreen flag, but a fullscreen tile is the whole output.
                tileWidth: tile ? Number(tile[0]) : 0,
                tileHeight: tile ? Number(tile[1]) : 0
            })
        }
        root._windowsRevision++
        root.recomputeFullscreenOutputs()
        windowsUpdated()
    }

    // Record each output's logical extents. niri reports these through
    // OutputsChanged (and once at startup); a disconnect drops the entry so a
    // stale size can never keep a bar collapsed.
    function updateOutputs(outputMap) {
        const source = (outputMap && outputMap.OutputsChanged)
            ? outputMap.OutputsChanged.outputs
            : outputMap
        if (!source)
            return
        const sizes = ({})
        for (let i = 0; i < source.length; i++) {
            const out = source[i]
            if (!out || !out.name)
                continue
            const logical = out.logical || {}
            const width = Number(logical.width)
            const height = Number(logical.height)
            if (!isFinite(width) || !isFinite(height) || width <= 0 || height <= 0)
                continue
            sizes[String(out.name)] = { width: width, height: height }
        }
        root.outputSizes = sizes
        root.recomputeFullscreenOutputs()
    }

    // Recompute the per-output fullscreen verdicts. Called imperatively after
    // every windows/workspaces/outputs change so no consumer has to bind
    // through ListModel rows, which do not reliably invalidate bindings.
    function recomputeFullscreenOutputs() {
        const active = ({})
        for (let i = 0; i < workspaces.count; i++) {
            const item = workspaces.get(i)
            if (item.isActive && item.output)
                active[String(item.output)] = String(item.wsId)
        }

        const rows = []
        for (let k = 0; k < windows.count; k++) {
            const win = windows.get(k)
            rows.push({
                workspaceId: win.workspaceId,
                tileWidth: win.tileWidth,
                tileHeight: win.tileHeight
            })
        }
        root._fullscreenOutputs = FullscreenDetect
            .fullscreenOutputs(root.outputSizes, active, rows)
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
                    name: ws.name || "",
                    output: ws.output ? String(ws.output) : ""
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
            if (currentItem.output !== (ws.output ? String(ws.output) : ""))
                workspaces.setProperty(targetIndex, "output", ws.output ? String(ws.output) : "")
        }

        for (let index = workspaces.count - 1; index >= 0; index--) {
            if (activeWorkspaceIds[workspaces.get(index).wsId])
                continue
            workspaces.remove(index, 1)
        }

        root.recomputeFullscreenOutputs()
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
        // The active workspace decides which windows count for fullscreen, so
        // re-derive before the async window re-pull lands.
        root.recomputeFullscreenOutputs()
        workspaceActivated()
        root.reloadWindows()
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

    // Initial output fetch. Output logical extents are the fullscreen yardstick:
    // a fullscreen tile in niri is sized to the whole output, never the working
    // area, so the bar can tell fullscreen from maximized without a flag the
    // compositor does not publish.
    property Process _outputFetcher: Process {
        running: true
        command: ["niri", "msg", "-j", "outputs"]
        stdout: SplitParser {
            onRead: data => {
                try { root.updateOutputs(_flattenOutputs(JSON.parse(data.trim()))) } catch (e) {}
            }
        }
    }

    // `niri msg -j outputs` answers with a map keyed by connector (a mirror's
    // entry is a list); the event stream's OutputsChanged carries a plain list.
    function _flattenOutputs(parsed) {
        if (Array.isArray(parsed))
            return parsed
        const list = []
        for (let name in parsed || {}) {
            if (!Object.prototype.hasOwnProperty.call(parsed, name))
                continue
            let entry = parsed[name]
            if (Array.isArray(entry))
                entry = entry.length ? entry[0] : null
            if (!entry)
                continue
            list.push({
                name: entry.name ? String(entry.name) : String(name),
                logical: entry.logical || {}
            })
        }
        return list
    }

    function reloadWindows() { fetcher.running = true }

    // Sync isFocused from the WindowFocusChanged event's own id, avoiding an
    // async windows re-pull so the hint indicator tracks focus without lag.
    function setFocusedWindow(focusedId) {
        const target = focusedId != null ? String(focusedId) : ""
        for (let i = 0; i < windows.count; i++) {
            const isNow = (windows.get(i).winId === target)
            if (windows.get(i).isFocused !== isNow)
                windows.setProperty(i, "isFocused", isNow)
        }
        root._windowsRevision++
        windowsUpdated()
    }

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
                    else if (event.WindowFocusChanged)
                        root.setFocusedWindow(event.WindowFocusChanged.id)
                    else if (event.WindowsChanged)
                        root.updateWindows(event.WindowsChanged.windows)
                    else if (event.OutputsChanged)
                        root.updateOutputs(event.OutputsChanged)
                    else if (event.WindowOpenedOrChanged || event.WindowClosed)
                        root.reloadWindows()
                } catch (e) {}
            }
        }
    }

    function reloadConfig() {
        _configReloader.running = true
    }

    // Watch for blur settings changes and sync to niri config.
    readonly property string _blurSettingsWatch: Services.SettingsService.appearance.blurPasses
        + "|" + Services.SettingsService.appearance.blurOffset
        + "|" + Services.SettingsService.appearance.blurNoise
        + "|" + Services.SettingsService.appearance.blurSaturation
        + "|" + Services.SettingsService.appearance.enableBlur
        + "|" + Services.SettingsService.appearance.blurSurfaceOpacity

    on_BlurSettingsWatchChanged: {
        root.syncBlurConfig()
    }

    Component.onCompleted: {
        root.syncManagedHotkeys()
        root.syncBlurConfig()
    }

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

    // Write blur.kdl from SettingsService values and reload niri config.
    property Process _blurWriter: Process {
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("NiriService: failed to write blur.kdl, exitCode =", exitCode)
                return
            }

            root.reloadConfig()
        }
    }
}
