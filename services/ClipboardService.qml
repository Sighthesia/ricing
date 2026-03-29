pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Wraps cliphist clipboard manager.
// Consumers call list() then read items; call copyToClipboard(id) to restore.
Singleton {
    id: root

    // Parsed items from last list() call. Each: { id: string, preview: string, isImage: bool }
    property var items: []

    // Increments each time items is refreshed — lets providers react reactively.
    property int revision: 0

    // True after the session clipboard watcher has been launched.
    property bool watcherStarted: false

    // --- Private state ---

    // id → callback(text) waiting for a decode result
    property var _decodeCallbacks: ({})

    // --- Public API ---

    // Fetch clipboard history entries. Clears items first, then refills from cliphist.
    function list(limit: int): void {
        _listProc.running = true;
    }

    // Copy the entry identified by `id` back to the clipboard (makes it the active clip).
    function copyToClipboard(id: string): void {
        _copyProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"];
        _copyProc.running = true;
    }

    // Decode entry `id` to plain text and call callback(text) asynchronously.
    function decode(id: string, callback: var): void {
        _decodeCallbacks[id] = callback;
        _decodeProc.command = ["sh", "-c", "cliphist decode " + id];
        _decodeProc.running = true;
    }

    function _startWatcher(): void {
        if (root.watcherStarted) return
        Quickshell.execDetached(["sh", "-c", "wl-paste --watch cliphist store"])
        root.watcherStarted = true
    }

    // --- Processes ---

    Process {
        id: _listProc
        command: ["sh", "-c", "cliphist list"]

        // Clear stale items when a new fetch begins so consumers never see a mix
        // of old and new entries during the async fill.
        onRunningChanged: {
            if (running) root.items = [];
        }

        stdout: SplitParser {
            onRead: (line) => root._appendItem(line)
        }

        onExited: (code, status) => {
            root.revision++;
        }
    }

    Process {
        id: _copyProc
        // command set dynamically in copyToClipboard()
    }

    Process {
        id: _decodeProc
        // command set dynamically in decode()
        property string _buf: ""

        stdout: SplitParser {
            onRead: (line) => _decodeProc._buf += (line + "\n")
        }

        onExited: (code, status) => {
            let cmdStr = _decodeProc.command.join(" ");
            let match = cmdStr.match(/cliphist decode (\d+)/);
            if (match) {
                let id = match[1];
                let cb = root._decodeCallbacks[id];
                if (cb) {
                    cb(_decodeProc._buf.trimEnd());
                    delete root._decodeCallbacks[id];
                }
            }
            _decodeProc._buf = "";
        }
    }

    // --- Private helpers ---

    function _appendItem(line: string): void {
        if (!line) return;
        let tab = line.indexOf("\t");
        if (tab < 0) return;
        let id      = line.substring(0, tab);
        let preview = line.substring(tab + 1);
        // Binary/image entries produced by cliphist start with "[[" or carry a MIME type.
        let isImage = preview.startsWith("[[") || preview.includes("image/");
        let current = root.items.slice();
        current.push({ id: id, preview: preview, isImage: isImage });
        root.items = current;
    }

    Component.onCompleted: {
        root.items = [];
        root._startWatcher()
    }
}
