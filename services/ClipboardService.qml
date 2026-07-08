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
    property var _firstSeenById: ({})
    // Tracks whether new first-seen timestamps were recorded in the current list run.
    property bool _firstSeenDirty: false

    // Persistence for first-seen timestamps across shell restarts.
    // Debounced write follows LaunchCountService.qml pattern.
    Timer {
        id: firstSeenSaveTimer
        interval: 500
        repeat: false
        onTriggered: firstSeenFile.writeAdapter()
    }

    FileView {
        id: firstSeenFile
        path: Quickshell.cacheDir + "/clipboard-first-seen.json"
        blockLoading: true
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                firstSeenFile.writeAdapter()
        }

        JsonAdapter {
            id: firstSeenAdapter
            property var firstSeenMap: ({})
        }
    }

    signal listCompleted

    // Probe for cliphist at startup so we never attempt commands on missing tools.
    property Process _checkProc: Process {
        command: ["sh", "-c", "command -v cliphist"]
        running: false

        stdout: StdioCollector {}

        onExited: code => {
            root.available = (code === 0)
            // Pre-fetch history immediately so the first panel open is not blank.
            if (root.available) root.list()
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
                    let lowerPreview = preview.toLowerCase()
                    if (!root._firstSeenById[id]) {
                        root._firstSeenById[id] = Date.now()
                        root._firstSeenDirty = true
                    }
                    // cliphist image previews vary by version: bracketed mime,
                    // binary-data text, or an HTML img snippet.
                    let isImage = (preview.startsWith("[") && /image/.test(preview))
                        || lowerPreview.startsWith("[image]")
                        || lowerPreview.includes(" binary data ")
                        || lowerPreview.includes("<img")
                    let mime = "text/plain"
                    if (isImage) {
                        if (lowerPreview.includes("png"))
                            mime = "image/png"
                        else if (lowerPreview.includes("jpg") || lowerPreview.includes("jpeg"))
                            mime = "image/jpeg"
                        else if (lowerPreview.includes("webp"))
                            mime = "image/webp"
                        else if (lowerPreview.includes("gif"))
                            mime = "image/gif"
                        else
                            mime = "image/*"
                    }
                    result.push({ id, preview, isImage, mime, firstSeenMs: root._firstSeenById[id] })
                }
                // Persist any newly-recorded first-seen timestamps.
                if (root._firstSeenDirty) {
                    root._firstSeenDirty = false
                    firstSeenAdapter.firstSeenMap = root._firstSeenById
                    firstSeenSaveTimer.restart()
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

    // ---- Preview support: decode an item for inline preview. ----
    // Tracks the most recent request id so stale completions are ignored.
    property string _previewRequestId: ""
    // Tracks which id the currently running process belongs to.
    property string _runningDecodeId: ""
    property string _runningDecodePath: ""
    property int _previewRevision: 0
    signal previewDecoded(string id, string contentOrPath)

    property Process _previewDecodeProc: Process {
        id: previewDecodeProc
        command: []
        running: false
        stdout: StdioCollector {}
        onExited: (code) => {
            var runningId = root._runningDecodeId
            var runningPath = root._runningDecodePath
            root._runningDecodeId = ""
            root._runningDecodePath = ""
            if (!runningId || code !== 0) return
            // Ignore if a newer request has superseded this one.
            if (runningId !== root._previewRequestId) return
            if (root._previewDecodeIsImage) {
                // Image was piped to a temp file by the shell command.
                root._previewRevision++
                root.previewDecoded(runningId, "file://" + runningPath + "?rev=" + root._previewRevision)
            } else {
                root.previewDecoded(runningId, stdout.text)
            }
        }
    }
    property bool _previewDecodeIsImage: false

    // Initiate async decoding of an item for preview.
    // For images the result is a file:// URL; for text the raw content string.
    function requestPreview(id, isImage) {
        if (!root.available || !id) return
        root._previewRequestId = id
        root._previewDecodeIsImage = isImage
        if (isImage) {
            var safeName = encodeURIComponent(id).replace(/%/g, "_")
            var path = "/tmp/afloat-clip-preview-" + safeName + ".img"
            previewDecodeProc.command = [
                "sh", "-c",
                "cliphist decode \"$1\" > \"$2\"",
                "afloat-clip-preview",
                id,
                path
            ]
            root._runningDecodePath = path
        } else {
            previewDecodeProc.command = ["cliphist", "decode", id]
            root._runningDecodePath = ""
        }
        root._runningDecodeId = id
        previewDecodeProc.running = true
    }

    // Clean up temp preview files for the given id (called when preview changes).
    function discardPreview(id) {
        if (!id) return
        if (root._previewRequestId === id) {
            root._previewRequestId = ""
        }
        var safeName = encodeURIComponent(id).replace(/%/g, "_")
        Quickshell.execDetached(["rm", "-f", "/tmp/afloat-clip-preview-" + safeName + ".img"])
    }

    Component.onCompleted: {
        _checkProc.running = true
        // Restore persisted first-seen timestamps across restarts.
        if (firstSeenAdapter.firstSeenMap)
            root._firstSeenById = firstSeenAdapter.firstSeenMap
    }
}
