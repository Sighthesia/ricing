pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Niri window manager IPC: tracks workspaces and windows via event stream.
Singleton {
    id: root

    property ListModel windows: ListModel {}
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
            windows.append({
                winId: String(win.id),
                title: win.title || "",
                appId: win.app_id || "",
                isFocused: win.is_focused || false
            })
        }
        windowsUpdated()
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
                    if (event.WindowOpenedOrChanged || event.WindowClosed || event.WindowFocusChanged)
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
