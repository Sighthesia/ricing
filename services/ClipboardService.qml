pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history backed by cliphist; polled on a timer so the UI stays fresh.
Singleton {
    id: root

    property bool available: false
    property var items: []
    property int revision: 0

    signal listCompleted

    // Probe for cliphist at startup so we never attempt commands on missing tools.
    property Process _checkProc: Process {
        command: ["sh", "-c", "command -v cliphist"]
        running: false

        stdout: StdioCollector {}

        onExited: code => {
            root.available = (code === 0)
        }
    }

    // Fetches the full history; output is line-separated "<id>\t<preview>" entries.
    property Process _listProc: Process {
        id: listProc
        command: ["cliphist", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                let result = []
                for (let line of lines) {
                    if (!line) continue
                    // cliphist separates id and preview with a tab
                    let tab = line.indexOf("\t")
                    let id = tab >= 0 ? line.slice(0, tab) : line.split(" ")[0]
                    let preview = tab >= 0 ? line.slice(tab + 1) : line.slice(id.length + 1)
                    // cliphist marks binary/image entries with a bracketed mime hint
                    let isImage = preview.startsWith("[") && /image/.test(preview)
                    let mime = isImage ? preview.replace(/^\[|\]$/g, "") : "text/plain"
                    result.push({ id, preview, isImage, mime })
                }
                root.items = result
                root.revision++
                root.listCompleted()
            }
        }
    }

    // Fire-and-forget action processes; no output needed, errors are silently ignored
    // because clipboard ops are best-effort from the shell's perspective.
    property Process _actionProc: Process {
        id: actionProc
        command: []
        running: false
    }

    property Timer _pollTimer: Timer {
        interval: 5000
        repeat: true
        running: root.available
        onTriggered: root.list()
    }

    function list() {
        if (!root.available || listProc.running) return
        listProc.running = true
    }

    function copyItem(id: string) {
        if (!root.available) return
        actionProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"]
        actionProc.running = true
    }

    function pasteItem(id: string) {
        if (!root.available) return
        // Decode into clipboard then synthesise the paste shortcut via wtype
        actionProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy && wtype -M ctrl -M shift v"]
        actionProc.running = true
    }

    // Separate process for delete so we can reliably refresh after exit.
    property Process _deleteProc: Process {
        id: deleteProc
        command: []
        running: false
        stdout: StdioCollector {}
        onExited: root.list()
    }

    function deleteItem(id: string) {
        if (!root.available) return
        deleteProc.command = ["sh", "-c", "echo " + id + " | cliphist delete"]
        deleteProc.running = true
    }

    function wipeAll() {
        if (!root.available) return
        Quickshell.execDetached(["cliphist", "wipe"])
        root.items = []
        root.revision++
    }

    Component.onCompleted: _checkProc.running = true
}
