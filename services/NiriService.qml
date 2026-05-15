pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Niri window manager IPC: tracks workspaces and windows via event stream.
Singleton {
    id: root

    property ListModel windows: ListModel {}
    signal windowsUpdated()

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
}
