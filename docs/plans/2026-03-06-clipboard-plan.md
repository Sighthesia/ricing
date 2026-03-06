# Clipboard Service Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a `ClipboardService` singleton wrapping `cliphist` and a `ClipboardProvider` that feeds clipboard history results into the launcher panel via the `>clip ` prefix.

**Architecture:** `ClipboardService` (Singleton) runs `cliphist list` / `cliphist decode` via `Quickshell.Io.Process`. `ClipboardProvider` implements the provider interface and exposes the results. Integration into LauncherCore happens after this branch is merged into `feat/launcher-core`.

**Tech Stack:** Quickshell QML, `Quickshell.Io.Process`, `cliphist`, `wl-copy`

---

## Context for Implementer

- **Quickshell Process**: use `Quickshell.Io.Process { command: [...]; running: false; onExited: ... }` — `stdout` gives output after exit. Set `running = true` to start.
- **cliphist output format** (per line): `<id>\t<preview text>`, where `<id>` is a number.
- **Image detection**: `preview` will contain `[[ binary data ... ]]` or mime like `image/png` — check `isImage` by testing if preview starts with `[[` or contains `image/`.
- **Singleton pattern**: copy structure from `services/NotificationService.qml`.
- **QML file order**: imports → root id → required property → property → readonly property → `property _xxx` → signal → children → functions → `Component.onCompleted`.
- **Provider interface** (same as ApplicationsProvider):
  - `property bool handleSearch: true`
  - `function onOpened(): void`
  - `function getResults(text: string): var`

---

### Task 1: Create ClipboardService singleton

**Files:**
- Create: `services/ClipboardService.qml`

**Step 1: Write the file**

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Wraps cliphist clipboard manager.
// Consumers call list() then read items; call copyToClipboard(id) to restore.
Singleton {
    id: root

    // Parsed items from last list() call. Each: {id: string, preview: string, isImage: bool}
    property var items: []

    // Increments each time items is refreshed — lets providers react reactively.
    property int revision: 0

    // Fetch up to `limit` history entries. Updates `items` and `revision` when done.
    function list(limit: int): void {
        _listProc.running = true;
    }

    // Copy the entry with `id` back to the clipboard (makes it the active clip).
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

    // --- Private state ---
    property var _decodeCallbacks: ({})

    Process {
        id: _listProc
        command: ["sh", "-c", "cliphist list"]

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
            // Extract id from the last set command
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

    function _appendItem(line: string): void {
        if (!line) return;
        let tab = line.indexOf("\t");
        if (tab < 0) return;
        let id      = line.substring(0, tab);
        let preview = line.substring(tab + 1);
        // Detect binary/image entries
        let isImage = preview.startsWith("[[") || preview.includes("image/");
        let current = root.items.slice();
        current.push({ id: id, preview: preview, isImage: isImage });
        root.items = current;
    }

    Component.onCompleted: {
        root.items = [];
    }
}
```

**Step 2: Verify it loads**

```bash
qs --path . 2>&1 | grep -i "error\|ClipboardService" | head -10
# Expected: no errors
```

**Step 3: Commit**

```bash
git add services/ClipboardService.qml
git commit -m "feat(clipboard): add ClipboardService wrapping cliphist"
```

---

### Task 2: Fix list() to clear items before refetching

**Files:**
- Modify: `services/ClipboardService.qml`

**Step 1: Update `list()` to reset items first**

The current `_appendItem` pushes onto an ever-growing array. Refetches should replace, not accumulate.

In `ClipboardService.qml`, update `_listProc` to clear `items` at start:

```qml
Process {
    id: _listProc
    command: ["sh", "-c", "cliphist list"]

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
```

**Step 2: Commit**

```bash
git add services/ClipboardService.qml
git commit -m "fix(clipboard): clear items before each cliphist list refresh"
```

---

### Task 3: Create ClipboardProvider

**Files:**
- Create: `modules/launcher/providers/ClipboardProvider.qml`

**Step 1: Write the file**

```qml
import Quickshell
import QtQuick
import qs.services

// Provides clipboard history results from ClipboardService.
// Activated when LauncherCore.searchText starts with ">clip ".
Item {
    id: root

    // Provider interface
    property bool handleSearch: false  // only active when explicitly selected

    function onOpened(): void {
        ClipboardService.list(100);
    }

    // Returns clipboard items filtered by text (matched against preview).
    function getResults(text: string): var {
        let results = [];
        let query = text.trim().toLowerCase();
        let items = ClipboardService.items;

        for (let i = 0; i < items.length; i++) {
            let item = items[i];
            let preview = item.preview || "";

            if (query !== "" && !preview.toLowerCase().includes(query)) continue;

            let displayName = preview.length > 60
                ? preview.substring(0, 60) + "…"
                : preview;

            results.push({
                name:        item.isImage ? "[图片]" : displayName,
                description: item.isImage ? preview : "",
                icon:        item.isImage ? "image-x-generic" : "edit-paste",
                onActivate: (function(id) {
                    return function() { ClipboardService.copyToClipboard(id); };
                })(item.id)
            });
        }

        return results.slice(0, 50);
    }
}
```

**Step 2: Commit**

```bash
git add modules/launcher/providers/ClipboardProvider.qml
git commit -m "feat(clipboard): add ClipboardProvider for launcher integration"
```

---

### Task 4: Manual smoke test

**Step 1: Verify cliphist is available**

```bash
which cliphist && cliphist list | head -5
# Expected: shows recent clipboard entries as `<id>\t<preview>`
```

**Step 2: Verify service responds to IPC (after merging into launcher-core)**

Once merged, test via:
```bash
qs ipc call launcher.openClipboard
# Expected: launcher opens with ">clip " prefilled, clipboard items listed
```

**Step 3: Commit**

```bash
git add -A
git commit -m "feat(clipboard): clipboard service + provider complete"
```

---

## Integration (after merge into feat/launcher-core)

In `modules/launcher/LauncherCore.qml`:

1. Add `ClipboardProvider { id: clipProvider }` as a child.
2. Update `_providers` to `[appProvider, clipProvider]`.
3. Update `_activeProvider()`:

```js
function _activeProvider(): var {
    let text = searchField.text;
    if (text.startsWith(">clip")) return clipProvider;
    return appProvider;
}
```

4. Strip the `>clip ` prefix before passing to `getResults`:

```js
function _refreshResults(): void {
    _results.clear();
    let provider = _activeProvider();
    if (!provider) return;

    let q = searchField.text;
    if (q.startsWith(">clip ")) q = q.substring(6);
    else if (q === ">clip") q = "";

    let items = provider.getResults(q);
    for (let i = 0; i < items.length; i++) {
        _results.append(items[i]);
    }
    _selectedIndex = items.length > 0 ? 0 : -1;
}
```

5. Commit:

```bash
git add -A
git commit -m "feat(launcher): integrate ClipboardProvider into LauncherCore"
```

---

## Notes

- `cliphist list` output uses tabs as separators; do not split on spaces.
- `Process` in Quickshell re-reads `command` each time `running` is set to `true`.
- `SplitParser` fires `onRead` per line (newline-delimited by default).
- XDG icon `edit-paste` renders as a clipboard icon in most icon themes.
